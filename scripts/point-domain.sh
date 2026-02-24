#!/bin/bash
# Set a domain's A record to TARGET_IP. Usage: ./scripts/point-domain.sh <DOMAIN> <TARGET_IP> [-y|--yes]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$DEPLOYMENT_DIR/.env" ]; then
    set -a
    source "$DEPLOYMENT_DIR/.env"
    set +a
fi

DOMAIN="${1:-}"
TARGET_IP="${2:-}"
AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_YES=true ;;
    esac
done

if [ -z "$DOMAIN" ] || [ -z "$TARGET_IP" ] || [ "$DOMAIN" = "-y" ] || [ "$DOMAIN" = "--yes" ] || [ "$TARGET_IP" = "-y" ] || [ "$TARGET_IP" = "--yes" ]; then
    echo "Usage: $0 <DOMAIN> <TARGET_IP> [-y|--yes]" >&2
    exit 1
fi

if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo "Error: CLOUDFLARE_TOKEN not set. Set it in .env." >&2
    exit 1
fi

if [[ "$DOMAIN" == *.*.* ]]; then
    ZONE_NAME=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
else
    ZONE_NAME="$DOMAIN"
fi

ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
    -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
    -H "Content-Type: application/json")
ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
if [ -z "$ZONE_ID" ]; then
    echo "Error: Could not find zone for $ZONE_NAME" >&2
    exit 1
fi

RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN&type=A" \
    -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
    -H "Content-Type: application/json")
RECORD_ID=$(echo "$RECORDS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
CURRENT_IP=$(echo "$RECORDS_RESPONSE" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)

echo ""
echo ">>> Point domain: $DOMAIN <<<"
echo "  Current A:   ${CURRENT_IP:-<no record>}"
echo "  Switching to: $TARGET_IP"
echo ""

if [ -z "$RECORD_ID" ]; then
    echo "Error: No A record found for $DOMAIN. Create it first with setup.sh." >&2
    exit 1
fi

if [ "$CURRENT_IP" = "$TARGET_IP" ]; then
    echo "Already pointing to $TARGET_IP. No change."
    exit 0
fi

if [ "$AUTO_YES" != "true" ]; then
    echo -n "Proceed? (y/N) "
    read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$TARGET_IP\",\"ttl\":60,\"proxied\":false}")

SUCCESS=$(echo "$UPDATE_RESPONSE" | grep -o '"success":[^,]*' | cut -d':' -f2)
if [ "$SUCCESS" = "true" ]; then
    echo "Done. $DOMAIN now points to $TARGET_IP (TTL 60s)."
else
    echo "Error: Failed to update DNS record." >&2
    echo "$UPDATE_RESPONSE" >&2
    exit 1
fi

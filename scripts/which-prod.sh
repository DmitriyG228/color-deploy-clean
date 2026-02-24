#!/bin/bash
# Show which color is currently serving production (LIVE_DOMAIN).
# Usage: ./scripts/which-prod.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$DEPLOYMENT_DIR/.env" ]; then
    set -a
    source "$DEPLOYMENT_DIR/.env"
    set +a
fi

if [ -z "$LIVE_DOMAIN" ]; then
    echo "Error: LIVE_DOMAIN not set in .env." >&2
    exit 1
fi
if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo "Error: CLOUDFLARE_TOKEN not set in .env." >&2
    exit 1
fi

# Resolve LIVE_DOMAIN via Cloudflare API
if [[ "$LIVE_DOMAIN" == *.*.* ]]; then
    ZONE_NAME=$(echo "$LIVE_DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
else
    ZONE_NAME="$LIVE_DOMAIN"
fi

ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
    -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
    -H "Content-Type: application/json")
ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
if [ -z "$ZONE_ID" ]; then
    echo "Error: Could not find zone for $ZONE_NAME" >&2
    exit 1
fi

RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$LIVE_DOMAIN&type=A" \
    -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
    -H "Content-Type: application/json")
PROD_IP=$(echo "$RECORDS_RESPONSE" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$PROD_IP" ]; then
    echo "No A record found for $LIVE_DOMAIN"
    exit 1
fi

# Match against each color
COLORS="blue green yellow"
MATCHED=""
for c in $COLORS; do
    IP=$("$SCRIPT_DIR/get-deployment-ip.sh" "$c" 2>/dev/null) || continue
    if [ "$IP" = "$PROD_IP" ]; then
        MATCHED="$c"
        break
    fi
done

echo "$LIVE_DOMAIN -> $PROD_IP"
if [ -n "$MATCHED" ]; then
    echo "Production is: $MATCHED"
else
    echo "Production IP does not match any deployed color"
fi

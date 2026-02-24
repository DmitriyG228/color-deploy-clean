#!/bin/bash
# Refuse if prod DNS points at this deployment (so destroy is safe). LIVE_DOMAIN from .env.
# Usage: ./scripts/check-prod-not-pointing-to.sh <color>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COLOR="${1:-}"

if [ -z "$COLOR" ] || ! [[ "$COLOR" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Usage: $0 <color>" >&2
    exit 1
fi

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
    echo "Error: CLOUDFLARE_TOKEN not set. Set it in .env." >&2
    exit 1
fi

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

DEPLOYMENT_IP=$("$SCRIPT_DIR/get-deployment-ip.sh" "$COLOR")

if [ -n "$PROD_IP" ] && [ "$PROD_IP" = "$DEPLOYMENT_IP" ]; then
    echo "" >&2
    echo "ERROR: You are destroying the PROD environment. Not allowed." >&2
    echo "" >&2
    echo "  LIVE_DOMAIN ($LIVE_DOMAIN) currently points to this deployment: $COLOR at $DEPLOYMENT_IP" >&2
    echo "" >&2
    echo "  You must remove prod from this deployment first: point prod to another color," >&2
    echo "  e.g.  make prod-point-<other-color>   then run  make destroy-$COLOR  again." >&2
    echo "" >&2
    exit 1
fi
exit 0

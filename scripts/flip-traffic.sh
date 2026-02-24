#!/bin/bash
# Flip live DNS (LIVE_DOMAIN from .env) to TARGET_IP. Usage: ./scripts/flip-traffic.sh <TARGET_IP> [-y|--yes]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$DEPLOYMENT_DIR/.env" ]; then
    set -a
    source "$DEPLOYMENT_DIR/.env"
    set +a
fi

TARGET_IP="${1:-}"

if [ -z "$TARGET_IP" ] || [ "$TARGET_IP" = "-y" ] || [ "$TARGET_IP" = "--yes" ]; then
    echo "Usage: $0 <TARGET_IP> [-y|--yes]"
    exit 1
fi

if [ -z "$LIVE_DOMAIN" ]; then
    echo "Error: LIVE_DOMAIN not set in .env." >&2
    exit 1
fi

exec "$SCRIPT_DIR/point-domain.sh" "$LIVE_DOMAIN" "$@"

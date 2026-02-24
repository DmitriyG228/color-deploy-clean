#!/bin/bash
# Update ~/.ssh/config so "ssh <PROJECT_SLUG>-<color>" works. PROJECT_SLUG from .env.
# Usage: ./scripts/update-ssh-config.sh <color>

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

IP=$("$DEPLOYMENT_DIR/scripts/get-deployment-ip.sh" "$COLOR")
HOST="${PROJECT_SLUG:-app}-$COLOR"
CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

mkdir -p "$(dirname "$CONFIG")"
NEW_BLOCK="Host $HOST
  HostName $IP
  User root
"

if [ -f "$CONFIG" ]; then
    awk -v host="$HOST" '
        $1 == "Host" && $2 == host { skip=1; next }
        skip && $1 == "Host" { skip=0 }
        skip { next }
        { print }
    ' "$CONFIG" > "$CONFIG.tmp"
    mv "$CONFIG.tmp" "$CONFIG"
fi
echo "$NEW_BLOCK" >> "$CONFIG"
echo "Updated $CONFIG: ssh $HOST"

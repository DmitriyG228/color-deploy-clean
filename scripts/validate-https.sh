#!/bin/bash
# Validate HTTPS and run diagnose for a deployment color.
# Usage: ./scripts/validate-https.sh <color> [staging|live]
# Writes summary to validate-result.txt in repo root.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COLOR="${1:?Usage: $0 <color> [staging|live]}"
TARGET="${2:-staging}"
RESULT_FILE="$REPO_DIR/validate-result.txt"

if [ ! -f "$SCRIPT_DIR/../.env" ]; then echo "ERROR: .env not found"; exit 1; fi
set -a; source "$SCRIPT_DIR/../.env"; set +a

if [ "$TARGET" = "live" ]; then
    DOMAIN="${LIVE_DOMAIN:?LIVE_DOMAIN not set}"
else
    DOMAIN="${STAGING_DOMAIN:?STAGING_DOMAIN not set}"
fi

VM_IP=$("$SCRIPT_DIR/get-deployment-ip.sh" "$COLOR") || { echo "ERROR: no VM IP for $COLOR"; exit 1; }

echo "VM_IP=$VM_IP"
echo "DOMAIN=$DOMAIN"
echo ""

echo "--- HTTPS /health ---"
BODY_FILE=$(mktemp 2>/dev/null || echo "$REPO_DIR/.validate-body")
CODE=$(curl -s -o "$BODY_FILE" -w "%{http_code}" --connect-timeout 15 "https://$DOMAIN/health" 2>/dev/null || echo "000")
echo "HTTP code: $CODE"
[ "$CODE" = "200" ] && echo "Body: $(cat "$BODY_FILE" 2>/dev/null)"
if [ "$CODE" != "200" ]; then
    echo "Trying HTTP..."
    curl -sI --connect-timeout 5 "http://$DOMAIN/health" 2>/dev/null || true
fi
rm -f "$BODY_FILE" 2>/dev/null || true

# Summary for validate-result.txt
{
    echo "validate-https $COLOR @ $(date -Iseconds 2>/dev/null || date)"
    echo "HTTPS https://$DOMAIN/health -> $CODE"
    [ "$CODE" = "200" ] && echo "OK" || echo "FAIL"
} > "$RESULT_FILE"

echo ""
echo "--- Diagnose (Caddy on VM) ---"
"$SCRIPT_DIR/diagnose-caddy.sh" "$COLOR" || true

echo "Result written to $RESULT_FILE"
# Exit 1 if HTTPS failed so 'make validate-yellow' can be used in CI
[ "$CODE" = "200" ] || exit 1

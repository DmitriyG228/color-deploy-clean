#!/bin/bash
# Print Caddy status, logs, listening ports, and local HTTP(S) checks on the VM.
# Usage: ./scripts/diagnose-caddy.sh <color>

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COLOR="${1:?Usage: $0 <color>}"
if [ ! -f "$SCRIPT_DIR/../.env" ]; then echo ".env not found"; exit 1; fi
set -a; source "$SCRIPT_DIR/../.env"; set +a
VM_IP=$("$SCRIPT_DIR/get-deployment-ip.sh" "$COLOR") || { echo "Could not get VM IP for $COLOR"; exit 1; }

echo "=== Caddy diagnose: $COLOR ($VM_IP) ==="
echo ""

echo "--- systemctl status caddy ---"
ssh -o ConnectTimeout=10 "root@$VM_IP" "systemctl status caddy" 2>/dev/null || true
echo ""

echo "--- Listening ports (80, 443) ---"
ssh "root@$VM_IP" "ss -tlnp 2>/dev/null | grep -E ':80 |:443 ' || true"
echo ""

echo "--- Last 60 lines of Caddy journal ---"
ssh "root@$VM_IP" "journalctl -u caddy -n 60 --no-pager" 2>/dev/null || true
echo ""

echo "--- /etc/caddy/Caddyfile ---"
ssh "root@$VM_IP" "cat /etc/caddy/Caddyfile" 2>/dev/null || true
echo ""

echo "--- Local HTTP (port 80) /health ---"
ssh "root@$VM_IP" "curl -sI http://127.0.0.1/health 2>/dev/null || echo 'curl failed'" 2>/dev/null || true
echo ""

echo "--- Local HTTPS (port 443) /health (insecure) ---"
ssh "root@$VM_IP" "curl -skI https://127.0.0.1/health 2>/dev/null || echo 'curl failed'" 2>/dev/null || true
echo ""

echo "--- UFW status (if any) ---"
ssh "root@$VM_IP" "ufw status 2>/dev/null || true"
echo ""

echo "=== end diagnose ==="

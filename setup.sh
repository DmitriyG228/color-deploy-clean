#!/bin/bash
# DNS + Caddy/HTTPS for a deployment. VM IP from Terraform; domains from .env.
# Usage: ./setup.sh <color> [live|staging] [--yes]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
print_header() { echo ""; echo -e "${BLUE}========================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}========================================${NC}"; echo ""; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

COLOR=""; TARGET="staging"; CONFIRM_LIVE=""
for arg in "$@"; do
    case "$arg" in
        live) TARGET="live" ;;
        staging) TARGET="staging" ;;
        --yes|-y) CONFIRM_LIVE=1 ;;
        *) [ -z "$COLOR" ] && [[ "$arg" =~ ^[a-z0-9][a-z0-9-]*$ ]] && COLOR="$arg" ;;
    esac
done

if [ -z "$COLOR" ]; then
    print_error "Missing color."
    echo "Usage: $0 <color> [live|staging] [--yes]"; exit 1
fi

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    print_error ".env not found. cp .env.example .env and set CLOUDFLARE_TOKEN, LIVE_DOMAIN, STAGING_DOMAIN"; exit 1
fi
set -a; source "$SCRIPT_DIR/.env"; set +a

if [ -z "$LIVE_DOMAIN" ] || [ -z "$STAGING_DOMAIN" ]; then
    print_error "LIVE_DOMAIN and STAGING_DOMAIN must be set in .env"; exit 1
fi
if [ -z "$CLOUDFLARE_TOKEN" ]; then
    print_error "CLOUDFLARE_TOKEN not set in .env"; exit 1
fi

if [ "$TARGET" = "live" ]; then
    DOMAIN="$LIVE_DOMAIN"
    DEPLOYMENT_ROLE="LIVE (production)"
else
    DOMAIN="$STAGING_DOMAIN"
    DEPLOYMENT_ROLE="staging"
fi

VM_IP=$("$SCRIPT_DIR/scripts/get-deployment-ip.sh" "$COLOR") || {
    print_error "Could not get VM IP for $COLOR (run: make deploy-$COLOR first)"; exit 1
}
API_PORT="${API_PORT:-8000}"

echo ""
echo ">>> DOMAIN=$DOMAIN -> VM_IP=$VM_IP ($DEPLOYMENT_ROLE) <<<"
echo ""

if [ "$TARGET" = "live" ] && [ "$CONFIRM_LIVE" != "1" ]; then
    echo -n "Configure LIVE (production)? (y/N) "
    read -r reply
    case "$reply" in [yY]|[yY][eE][sS]) ;; *) echo "Aborted."; exit 0 ;; esac
fi

print_header "Step 1/3: Cloudflare DNS"
if [[ "$DOMAIN" == *.*.* ]]; then
    ZONE_NAME=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
else
    ZONE_NAME="$DOMAIN"
fi
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
    -H "Authorization: Bearer $CLOUDFLARE_TOKEN" -H "Content-Type: application/json")
ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
[ -z "$ZONE_ID" ] && { print_error "Could not find zone for $ZONE_NAME"; exit 1; }

RECORDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN&type=A" \
    -H "Authorization: Bearer $CLOUDFLARE_TOKEN" -H "Content-Type: application/json")
RECORD_ID=$(echo "$RECORDS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
CURRENT_IP=$(echo "$RECORDS_RESPONSE" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -n "$RECORD_ID" ]; then
    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$VM_IP\",\"ttl\":60,\"proxied\":false}")
else
    UPDATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$VM_IP\",\"ttl\":60,\"proxied\":false}")
fi
SUCCESS=$(echo "$UPDATE_RESPONSE" | grep -o '"success":[^,]*' | cut -d':' -f2)
[ "$SUCCESS" != "true" ] && { print_error "DNS update failed"; exit 1; }
print_success "DNS: $DOMAIN -> $VM_IP"

print_info "Waiting 30s for DNS..."
sleep 30

print_header "Step 2/3: Install Caddy on VM"
INSTALL_SCRIPT='set -e
if command -v caddy &>/dev/null; then echo "Caddy already installed"; else
  # Wait for dpkg lock (Ubuntu automatic updates on first boot)
  for i in $(seq 1 24); do
    if apt-get update -qq 2>/dev/null; then break; fi
    echo "Waiting for apt/dpkg (attempt $i/24)..."; sleep 15
  done
  apt-get update -qq && apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf "https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt" | tee /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq caddy
fi
# Allow Caddy (running as caddy user) to bind to 80/443
setcap cap_net_bind_service=+ep /usr/bin/caddy 2>/dev/null || true
# If ufw is enabled, ensure 80/443 (and 22) are allowed for ACME and HTTPS
if command -v ufw &>/dev/null; then ufw allow 22 2>/dev/null; ufw allow 80 2>/dev/null; ufw allow 443 2>/dev/null; fi
echo "Caddy installed"'
ssh -o StrictHostKeyChecking=accept-new "root@$VM_IP" "bash -s" <<< "$INSTALL_SCRIPT"
print_success "Caddy installed"

print_header "Step 3/3: SSL/HTTPS"
# Caddy requires newline after '{' in block directives (e.g. log { ... })
# /health works without backend; / is reverse_proxy to API_PORT (502 if nothing on 8000)
CADDYFILE="$DOMAIN {
    encode gzip
    log {
        output file /var/log/caddy/access.log
    }
    handle /health {
        respond \"OK\" 200
    }
    handle {
        reverse_proxy localhost:$API_PORT
    }
}"
ssh "root@$VM_IP" "mkdir -p /var/log/caddy && chown caddy:caddy /var/log/caddy"
ssh "root@$VM_IP" "cat > /etc/caddy/Caddyfile" <<< "$CADDYFILE"
ssh "root@$VM_IP" "systemctl restart caddy" || true
sleep 3
if ! ssh "root@$VM_IP" "systemctl is-active --quiet caddy"; then
    print_error "Caddy failed to start. Last 50 lines of journal:"
    ssh "root@$VM_IP" "journalctl -u caddy -n 50 --no-pager" 2>/dev/null || true
    exit 1
fi
# Trigger ACME: first HTTPS request from this host can take 20-40s while Let's Encrypt validates
print_info "Triggering TLS certificate issuance (may take 20-40s)..."
CODE=""; for i in 1 2 3 4 5; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 20 "https://$DOMAIN/health" 2>/dev/null || true)
    [ "$CODE" = "200" ] && break
    [ "$i" -lt 5 ] && sleep 10
done
if [ "$CODE" = "200" ]; then
    print_success "HTTPS /health returned 200 (cert obtained)."
else
    print_warning "HTTPS /health returned: ${CODE:-connection failed}. Run: make diagnose-$COLOR"
fi
CERTS=$(ssh "root@$VM_IP" "journalctl -u caddy -n 40 --no-pager" 2>/dev/null | grep -iE "certificate|acme|error|failed|obtained" || true)
if [ -n "$CERTS" ]; then
    print_warning "Caddy log (cert/ACME):"
    echo "$CERTS"
fi
print_success "Caddyfile configured"
print_success "Setup complete. https://$DOMAIN (ssh root@$VM_IP)"
print_info "Tip: https://$DOMAIN/health works without an app on port $API_PORT; / proxies to localhost:$API_PORT (502 if nothing is running)."
print_info "If HTTPS fails with ERR_SSL_PROTOCOL_ERROR, run: make diagnose-$COLOR"
echo ""
echo ">>> Running diagnose (Caddy status + recent logs) <<<"
"$SCRIPT_DIR/scripts/diagnose-caddy.sh" "$COLOR" 2>/dev/null || true
echo ""

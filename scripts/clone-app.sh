#!/bin/bash
# Clone APP_REPO onto VM. Usage: ./scripts/clone-app.sh <color> [branch]
# Requires APP_REPO in .env; GITHUB_TOKEN for private GitHub repos.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COLOR="${1:-}"
BRANCH="${2:-}"

if [ -z "$COLOR" ] || ! [[ "$COLOR" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Usage: $0 <color> [branch]" >&2
    exit 1
fi

if [ -f "$DEPLOYMENT_DIR/.env" ]; then
    set -a
    source "$DEPLOYMENT_DIR/.env"
    set +a
fi

if [ -z "${APP_REPO:-}" ]; then
    echo "Error: APP_REPO not set in .env (e.g. https://github.com/owner/repo)." >&2
    exit 1
fi

APP_DIR="${APP_DIR:-/root/$(basename "$APP_REPO" .git)}"
VM_IP=$("$SCRIPT_DIR/get-deployment-ip.sh" "$COLOR") || { echo "Error: get VM IP first (make deploy-$COLOR)" >&2; exit 1; }

if [[ "$APP_REPO" =~ ^https://github\.com/ ]]; then
    [ -n "${GITHUB_TOKEN:-}" ] && CLONE_URL="https://x-access-token:${GITHUB_TOKEN}@${APP_REPO#https://}" || CLONE_URL="${APP_REPO%.git}.git"
else
    CLONE_URL="${APP_REPO%.git}.git"
fi

CLONE_URL_B64=$(echo -n "$CLONE_URL" | base64)
echo ">>> Clone app to $COLOR ($VM_IP) <<<"

ssh -o StrictHostKeyChecking=accept-new "root@$VM_IP" "bash -s" "$APP_DIR" "$BRANCH" <<ENDSSH
set -e
APP_DIR="$APP_DIR"
BRANCH="$BRANCH"
CLONE_URL_B64='$CLONE_URL_B64'
CLONE_URL=\$(echo -n "\$CLONE_URL_B64" | base64 -d)
apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git >/dev/null
if [ -d "\$APP_DIR/.git" ]; then
  cd "\$APP_DIR" && git fetch origin
  [ -n "\$BRANCH" ] && { git checkout "\$BRANCH" 2>/dev/null || git checkout -b "\$BRANCH" origin/"\$BRANCH"; git pull origin "\$BRANCH"; } || git pull origin "\$(git symbolic-ref -q HEAD | sed 's|refs/heads/||' || echo main)"
else
  rm -rf "\$APP_DIR"
  [ -n "\$BRANCH" ] && git clone -b "\$BRANCH" "\$CLONE_URL" "\$APP_DIR" || git clone "\$CLONE_URL" "\$APP_DIR"
fi
echo "Done. App at \$APP_DIR"
ENDSSH
echo "App at $APP_DIR on $COLOR"

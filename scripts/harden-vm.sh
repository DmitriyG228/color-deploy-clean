#!/bin/bash
# Harden a VM: UFW, SSH key-only, unattended upgrades.
# Usage: ./scripts/harden-vm.sh <color>
# Idempotent — safe to run multiple times.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COLOR="${1:?Usage: $0 <color>}"

if [ -f "$DEPLOYMENT_DIR/.env" ]; then set -a; source "$DEPLOYMENT_DIR/.env"; set +a; fi

VM_IP=$("$SCRIPT_DIR/get-deployment-ip.sh" "$COLOR") || { echo "Error: get VM IP first (make deploy-$COLOR)" >&2; exit 1; }

echo ">>> Hardening $COLOR ($VM_IP) <<<"

ssh -o StrictHostKeyChecking=accept-new "root@$VM_IP" "bash -s" <<'ENDSSH'
set -e

# --- UFW: default deny incoming, allow SSH + HTTP + HTTPS ---
if ! command -v ufw &>/dev/null; then
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw >/dev/null
fi

ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1

if ! ufw status | grep -q "Status: active"; then
    echo "y" | ufw enable >/dev/null 2>&1
fi
echo "  UFW: active (deny incoming, allow 22/80/443)"

# --- SSH: key-only auth, no password login ---
SSHD_CHANGED=0

if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    SSHD_CHANGED=1
fi
# Handle commented-out PasswordAuthentication (Ubuntu default)
if ! grep -q "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null; then
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    SSHD_CHANGED=1
fi

if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
    sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    SSHD_CHANGED=1
fi

if [ "$SSHD_CHANGED" = "1" ]; then
    systemctl restart ssh
    echo "  SSH: hardened (key-only, no password auth)"
else
    echo "  SSH: already hardened"
fi

# --- Unattended security upgrades ---
if ! dpkg -l unattended-upgrades >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades >/dev/null
fi
echo "  Upgrades: unattended-upgrades installed"

echo "  Hardening complete."
ENDSSH

echo "  $COLOR ($VM_IP) hardened."

#!/bin/bash
# Print vm_public_ip for the given color (Terraform workspace).
# Usage: ./scripts/get-deployment-ip.sh <color>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$DEPLOYMENT_DIR/terraform"
COLOR="${1:-}"

if [ -z "$COLOR" ] || ! [[ "$COLOR" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Usage: $0 <color>" >&2
    exit 1
fi

cd "$TERRAFORM_DIR"
terraform workspace select "$COLOR" >/dev/null 2>&1 || {
    echo "Error: workspace $COLOR not found" >&2
    exit 1
}
IP=$(terraform output -raw vm_public_ip 2>/dev/null || true)
if [ -z "$IP" ]; then
    echo "Error: no vm_public_ip for deployment $COLOR (run deploy first)" >&2
    exit 1
fi
echo "$IP"

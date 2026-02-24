#!/bin/bash
# Download Terraform into .bin so make deploy works without system terraform.
# Usage: ./scripts/install-terraform.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$DEPLOYMENT_DIR/.bin"
TF_VERSION="${TERRAFORM_VERSION:-1.9.8}"
# https://releases.hashicorp.com/terraform/
BASE_URL="https://releases.hashicorp.com/terraform/${TF_VERSION}"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

ZIP="terraform_${TF_VERSION}_${OS}_${ARCH}.zip"
URL="${BASE_URL}/${ZIP}"

mkdir -p "$BIN_DIR"
if [ -x "$BIN_DIR/terraform" ]; then
    echo "Terraform already in $BIN_DIR"
    "$BIN_DIR/terraform" version
    exit 0
fi

echo "Downloading Terraform ${TF_VERSION} to $BIN_DIR ..."
curl -sSLo "$BIN_DIR/$ZIP" "$URL"
unzip -o -q "$BIN_DIR/$ZIP" -d "$BIN_DIR"
rm -f "$BIN_DIR/$ZIP"
chmod +x "$BIN_DIR/terraform"
echo "Done. $( "$BIN_DIR/terraform" version )"

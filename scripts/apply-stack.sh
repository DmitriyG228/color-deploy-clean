#!/bin/bash
# Terraform stack wrapper: targets one deployment (color). Pass project_slug from .env.
# Usage: ./scripts/apply-stack.sh <color> [plan|apply|destroy]
# Color: lowercase alphanumeric + hyphens (e.g. blue, green, canary).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOYMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$DEPLOYMENT_DIR/terraform"
cd "$TERRAFORM_DIR"

if [ -f "$DEPLOYMENT_DIR/.env" ]; then
    set -a
    source "$DEPLOYMENT_DIR/.env"
    set +a
fi

COLOR="${1:-}"
ACTION="${2:-plan}"
PROJECT_SLUG="${PROJECT_SLUG:-app}"

if [ -z "$COLOR" ] || ! [[ "$COLOR" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Usage: $0 <color> [plan|apply|destroy]"
    echo "Example: $0 blue plan"
    echo "         $0 green apply"
    echo "Color: lowercase alphanumeric + hyphens (e.g. blue, green, canary)."
    exit 1
fi

UPPER="$(echo "$COLOR" | tr '[:lower:]' '[:upper:]')"
echo ""
echo ">>> Targeting deployment: $UPPER (workspace: $COLOR, project: $PROJECT_SLUG) <<<"
echo ""

if ! terraform workspace list | grep -q "^\* *${COLOR}$" && ! terraform workspace list | grep -q " *${COLOR}$"; then
    terraform workspace new "$COLOR"
fi
terraform workspace select "$COLOR"

TFVARS=""
[ -f "$DEPLOYMENT_DIR/terraform/terraform.tfvars" ] && TFVARS="-var-file=$DEPLOYMENT_DIR/terraform/terraform.tfvars"

case "$ACTION" in
    plan|apply) terraform "$ACTION" -var "color=$COLOR" -var "project_slug=$PROJECT_SLUG" $TFVARS "${@:3}" ;;
    *)         terraform "$ACTION" $TFVARS "${@:3}" ;;
esac

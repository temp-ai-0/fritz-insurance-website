#!/usr/bin/env bash
# deploy-azure.sh — provision infrastructure and upload site files to Azure
# Usage: ./scripts/deploy-azure.sh [--destroy]
#
# Required env vars (or passed as args):
#   AZURE_RESOURCE_GROUP   e.g. fritz-insurance-prod-rg
#   AZURE_LOCATION         e.g. eastus  (only needed on first run)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARAMS_FILE="$REPO_ROOT/infra/azure/main.parameters.json"
TEMPLATE_FILE="$REPO_ROOT/infra/azure/main.bicep"

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-fritz-insurance-prod-rg}"
LOCATION="${AZURE_LOCATION:-eastus}"
CDN_ENDPOINT_NAME="fritz-insurance-prod"

# ── Prerequisites check ───────────────────────────────────────────────────────
for cmd in az; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌  Azure CLI ('az') is not installed. See DEPLOY.md for prerequisites." >&2
    exit 1
  fi
done

if ! az account show &>/dev/null; then
  echo "❌  Not logged in. Run: az login" >&2
  exit 1
fi

# ── Destroy path ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--destroy" ]]; then
  echo "→ Deleting resource group '$RESOURCE_GROUP'..."
  az group delete --name "$RESOURCE_GROUP" --yes --no-wait
  echo "✅  Resource group deletion initiated."
  exit 0
fi

# ── Resource group ────────────────────────────────────────────────────────────
echo "→ Ensuring resource group '$RESOURCE_GROUP' exists..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

# ── Bicep deployment ──────────────────────────────────────────────────────────
echo "→ Deploying Bicep template..."
DEPLOY_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "@$PARAMS_FILE" \
  --query "properties.outputs" \
  --output json)

STORAGE_ACCOUNT=$(echo "$DEPLOY_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['storageAccountName']['value'])")
CDN_PROFILE=$(echo "$DEPLOY_OUTPUT"     | python3 -c "import sys,json; print(json.load(sys.stdin)['cdnProfileName']['value'])")

echo "   Storage account : $STORAGE_ACCOUNT"
echo "   CDN profile     : $CDN_PROFILE"

# ── Enable static website hosting ────────────────────────────────────────────
echo "→ Enabling static website on storage account..."
az storage blob service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --static-website \
  --index-document "index.html" \
  --404-document "index.html" \
  --auth-mode login \
  --output none

# Retrieve the static website hostname for the CDN origin
STATIC_WEB_URL=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query "primaryEndpoints.web" \
  --output tsv)
# Strip protocol and trailing slash for CDN origin hostname
ORIGIN_HOSTNAME=$(echo "$STATIC_WEB_URL" | sed 's|https://||' | sed 's|/||g')

# ── Create or update CDN endpoint ────────────────────────────────────────────
echo "→ Configuring CDN endpoint '$CDN_ENDPOINT_NAME' → $ORIGIN_HOSTNAME ..."
if az cdn endpoint show --name "$CDN_ENDPOINT_NAME" --profile-name "$CDN_PROFILE" \
     --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  # Endpoint exists — purge cache
  az cdn endpoint purge \
    --name "$CDN_ENDPOINT_NAME" \
    --profile-name "$CDN_PROFILE" \
    --resource-group "$RESOURCE_GROUP" \
    --content-paths "/*" \
    --output none
else
  # Create endpoint pointing at the static website origin
  az cdn endpoint create \
    --name "$CDN_ENDPOINT_NAME" \
    --profile-name "$CDN_PROFILE" \
    --resource-group "$RESOURCE_GROUP" \
    --origin "$ORIGIN_HOSTNAME" \
    --origin-host-header "$ORIGIN_HOSTNAME" \
    --enable-compression true \
    --output none
fi

CDN_HOSTNAME=$(az cdn endpoint show \
  --name "$CDN_ENDPOINT_NAME" \
  --profile-name "$CDN_PROFILE" \
  --resource-group "$RESOURCE_GROUP" \
  --query "hostName" --output tsv)

# ── Upload site files ─────────────────────────────────────────────────────────
echo "→ Uploading site files to \$web container..."
az storage blob upload-batch \
  --account-name "$STORAGE_ACCOUNT" \
  --source "$REPO_ROOT" \
  --destination "\$web" \
  --auth-mode login \
  --overwrite \
  --pattern "!infra/*" \
  --output none

# Remove non-site files that may have been uploaded
for f in ".gitignore" "DEPLOY.md" "README.md"; do
  az storage blob delete \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "\$web" \
    --name "$f" \
    --auth-mode login \
    --output none 2>/dev/null || true
done

echo ""
echo "✅  Deployment complete."
echo "   🌐  https://$CDN_HOSTNAME"
echo "   (CDN propagation may take a few minutes on first deploy)"

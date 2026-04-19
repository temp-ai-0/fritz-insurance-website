#!/usr/bin/env bash
# deploy-aws.sh — provision infrastructure and sync site files to S3
# Usage: ./scripts/deploy-aws.sh [--destroy]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infra/aws"

# ── Prerequisites check ───────────────────────────────────────────────────────
for cmd in terraform aws; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌  '$cmd' is not installed. See DEPLOY.md for prerequisites." >&2
    exit 1
  fi
done

# ── Terraform ─────────────────────────────────────────────────────────────────
echo "→ Initializing Terraform..."
terraform -chdir="$INFRA_DIR" init -input=false

if [[ "${1:-}" == "--destroy" ]]; then
  echo "→ Destroying infrastructure..."
  terraform -chdir="$INFRA_DIR" destroy -auto-approve
  echo "✅  Infrastructure destroyed."
  exit 0
fi

echo "→ Applying Terraform..."
terraform -chdir="$INFRA_DIR" apply -auto-approve -input=false

# ── Read outputs ──────────────────────────────────────────────────────────────
BUCKET_NAME=$(terraform -chdir="$INFRA_DIR" output -raw s3_bucket_name)
CF_DIST_ID=$(terraform -chdir="$INFRA_DIR" output -raw cloudfront_distribution_id)
CF_URL=$(terraform -chdir="$INFRA_DIR" output -raw cloudfront_url)

# ── Sync site files ───────────────────────────────────────────────────────────
echo "→ Syncing site files to s3://$BUCKET_NAME ..."
aws s3 sync "$REPO_ROOT" "s3://$BUCKET_NAME" \
  --exclude ".git/*" \
  --exclude ".gitignore" \
  --exclude "infra/*" \
  --exclude "scripts/*" \
  --exclude "DEPLOY.md" \
  --exclude "README.md" \
  --delete

# ── CloudFront cache invalidation ─────────────────────────────────────────────
echo "→ Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id "$CF_DIST_ID" \
  --paths "/*" \
  --output text --query 'Invalidation.Id'

echo ""
echo "✅  Deployment complete."
echo "   🌐  $CF_URL"

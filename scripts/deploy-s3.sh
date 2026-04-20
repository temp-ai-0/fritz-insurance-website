#!/usr/bin/env bash
# deploy-s3.sh — publish the Fritz Insurance static site to S3
#
# Works for both first-time setup and subsequent re-deploys (fully idempotent).
#
# Usage:
#   ./scripts/deploy-s3.sh              # deploy / re-deploy
#   ./scripts/deploy-s3.sh --teardown   # delete all bucket contents and remove bucket
#
# Config — edit these two variables if you ever rename the bucket or switch regions:
BUCKET_NAME="fritz-insurance-site"
REGION="us-east-2"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_URL="http://${BUCKET_NAME}.s3-website.${REGION}.amazonaws.com"

# ── Prerequisites ──────────────────────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
  echo "❌  AWS CLI not found. Install it: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html" >&2
  exit 1
fi

if ! aws sts get-caller-identity --no-cli-pager &>/dev/null; then
  echo "❌  AWS credentials not configured. Run: aws configure" >&2
  exit 1
fi

# ── Teardown ───────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--teardown" ]]; then
  echo "→ Emptying s3://$BUCKET_NAME ..."
  aws s3 rm "s3://$BUCKET_NAME" --recursive --no-cli-pager
  echo "→ Deleting bucket..."
  aws s3 rb "s3://$BUCKET_NAME" --no-cli-pager
  echo "✅  Bucket deleted."
  exit 0
fi

# ── Bucket setup (idempotent) ──────────────────────────────────────────────────
if aws s3api head-bucket --bucket "$BUCKET_NAME" --no-cli-pager 2>/dev/null; then
  echo "→ Bucket s3://$BUCKET_NAME already exists, skipping creation."
else
  echo "→ Creating bucket s3://$BUCKET_NAME in $REGION ..."
  aws s3 mb "s3://$BUCKET_NAME" --region "$REGION" --no-cli-pager
fi

echo "→ Configuring public access..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
  --no-cli-pager

echo "→ Applying bucket policy (public read)..."
aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --no-cli-pager \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Sid\": \"PublicReadGetObject\",
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::${BUCKET_NAME}/*\"
    }]
  }"

echo "→ Enabling static website hosting..."
aws s3 website "s3://$BUCKET_NAME" \
  --index-document index.html \
  --error-document index.html \
  --no-cli-pager

# ── Sync site files ────────────────────────────────────────────────────────────
echo "→ Syncing site files..."
aws s3 sync "$REPO_ROOT" "s3://$BUCKET_NAME" \
  --region "$REGION" \
  --exclude ".git/*" \
  --exclude ".gitignore" \
  --exclude "infra/*" \
  --exclude "scripts/*" \
  --exclude "*.md" \
  --delete \
  --no-cli-pager

echo ""
echo "✅  Deployment complete."
echo "   🌐  $SITE_URL"

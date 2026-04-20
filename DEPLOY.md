# Deployment Guide

---

## Simple S3 Static Hosting ← start here

The fastest way to get the site live. No Terraform required — just the AWS CLI.

**Prerequisites:** AWS CLI installed and configured (`aws configure`).

### Deploy / re-deploy

```bash
chmod +x scripts/deploy-s3.sh
./scripts/deploy-s3.sh
```

The script is fully **idempotent** — safe to run on every publish. It will:

1. Create the bucket if it doesn't exist (skips silently if it does)
2. Configure public-read access and static website hosting
3. Sync all site files, removing anything deleted locally (`--delete`)
4. Print the live URL when done

**Live URL:** `http://fritz-insurance-site.s3-website.us-east-2.amazonaws.com`

### Teardown

```bash
./scripts/deploy-s3.sh --teardown
```

Empties and deletes the bucket entirely.

### Changing the bucket name or region

Edit the two variables at the top of `scripts/deploy-s3.sh`:

```bash
BUCKET_NAME="fritz-insurance-site"
REGION="us-east-2"
```

### Upgrading to HTTPS / custom domain

S3 static hosting is HTTP only. When you're ready for a custom domain + HTTPS,
add CloudFront in front of it — the Terraform IaC in `infra/aws/` already handles this.
See the **AWS — S3 + CloudFront** section below.

---

## Prerequisites

### AWS
- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured (`aws configure`)
- IAM permissions: S3 full access, CloudFront full access

### Azure
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az login`)
- Contributor role on the target subscription
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (bundled with Azure CLI ≥ 2.20)

---

## AWS — S3 + CloudFront

### First deploy

```bash
chmod +x scripts/deploy-aws.sh
./scripts/deploy-aws.sh
```

This will:
1. Run `terraform init` + `terraform apply` — creates the S3 bucket and CloudFront distribution
2. Sync all site files to the bucket
3. Invalidate the CloudFront cache

The live URL is printed at the end (`https://<id>.cloudfront.net`).

### Subsequent deploys (site changes only)

```bash
./scripts/deploy-aws.sh
```

Terraform detects no infrastructure changes and skips them; only the file sync and cache invalidation run.

### Teardown

```bash
./scripts/deploy-aws.sh --destroy
```

### Custom domain (optional)

1. Request an ACM certificate in **us-east-1** for your domain
2. Add the `aliases` block and `viewer_certificate` to `infra/aws/main.tf`
3. Point your DNS CNAME to the CloudFront domain

---

## Azure — Blob Storage + CDN

### First deploy

```bash
chmod +x scripts/deploy-azure.sh
export AZURE_RESOURCE_GROUP="fritz-insurance-prod-rg"
export AZURE_LOCATION="eastus"
./scripts/deploy-azure.sh
```

This will:
1. Create the resource group (if it doesn't exist)
2. Deploy the Bicep template — creates the Storage Account and CDN profile
3. Enable static website hosting on the storage account
4. Create the CDN endpoint pointed at the static website origin
5. Upload all site files to the `$web` container

The live URL is printed at the end (`https://<name>.azureedge.net`).

### Subsequent deploys (site changes only)

```bash
./scripts/deploy-azure.sh
```

Bicep is idempotent; only changed resources are updated. Files are re-uploaded and the CDN cache is purged.

### Teardown

```bash
./scripts/deploy-azure.sh --destroy
```

### Custom domain (optional)

1. Add a CNAME record in your DNS pointing to the CDN endpoint hostname
2. Run: `az cdn custom-domain create --endpoint-name <endpoint> --profile-name <profile> --resource-group <rg> --name <name> --hostname <your-domain>`
3. Enable HTTPS: `az cdn custom-domain enable-https ...`

---

## Environment-specific overrides

To deploy to a different environment without editing `main.parameters.json`, create a local override file (gitignored):

```bash
cp infra/azure/main.parameters.json infra/azure/main.local.parameters.json
# edit as needed, then:
./scripts/deploy-azure.sh  # update the PARAMS_FILE variable in the script
```

For AWS, use a `terraform.tfvars` file (also gitignored):

```hcl
# infra/aws/terraform.tfvars
project_name = "fritz-insurance"
environment  = "staging"
aws_region   = "us-west-2"
```

# Fritz Insurance Website

Static marketing site for Fritz Insurance — an independent insurance agency.

Built as a single-page HTML site with Tailwind CSS (CDN), hosted on either **AWS S3 + CloudFront** or **Azure Blob Storage + Azure CDN**.

## Project Structure

```
fritz-insurance-website/
├── index.html              # Site (single file)
├── infra/
│   ├── aws/                # Terraform — S3 + CloudFront (OAC)
│   └── azure/              # Bicep — Storage Account + Azure CDN
├── scripts/
│   ├── deploy-aws.sh       # Provision + sync to AWS
│   └── deploy-azure.sh     # Provision + upload to Azure
└── DEPLOY.md               # Deployment instructions
```

## Local Preview

No build step required — open `index.html` directly in a browser, or use any static server:

```bash
npx serve .
# or
python3 -m http.server 8080
```

## Deployment

See [DEPLOY.md](./DEPLOY.md) for full AWS and Azure instructions.

## Assets

> **Note:** The logo file (`image_9bc9c0.png`) is not tracked in this repository. Add it to the repo root before deploying.

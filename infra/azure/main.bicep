@description('Location for all resources')
param location string = resourceGroup().location

@description('Project name — used for resource naming (lowercase, hyphens ok)')
param projectName string = 'fritz-insurance'

@description('Deployment environment')
param environment string = 'prod'

// ── Locals ────────────────────────────────────────────────────────────────────

var namePrefix = '${projectName}-${environment}'
// Storage account names: max 24 chars, lowercase alphanumeric only
var storageAccountName = take(toLower(replace('${replace(projectName, '-', '')}${environment}${uniqueString(resourceGroup().id)}', '-', '')), 24)
var cdnProfileName = '${namePrefix}-cdn'

// ── Storage Account ───────────────────────────────────────────────────────────
// Static website hosting is enabled by the deploy script after provisioning.
// The $web container and index.html are uploaded by the deploy script as well.

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: true      // Required for static website serving
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    accessTier: 'Hot'
  }

  tags: {
    project: projectName
    environment: environment
  }
}

// ── Azure CDN Profile ─────────────────────────────────────────────────────────
// The CDN endpoint is created by the deploy script after static website is
// enabled, so the origin hostname (*.web.core.windows.net) is known at that point.

resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: cdnProfileName
  location: 'Global'
  sku: {
    name: 'Standard_Microsoft'
  }

  tags: {
    project: projectName
    environment: environment
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

output storageAccountName string = storageAccount.name
output cdnProfileName string = cdnProfile.name
output resourceGroupName string = resourceGroup().name

// ============================================================
// RPI v7.7 — Agentic AKS Deployment
// ============================================================
// Provisions the full Azure infrastructure for RPI:
//   AKS Automatic, Azure SQL, Key Vault, Service Bus,
//   Application Gateway for Containers, Storage Account,
//   Managed Identity with Workload Identity federation,
//   and Private Endpoints.
//
// Usage:
//   az deployment sub create \
//     --location eastus2 \
//     --template-file main.bicep \
//     --parameters parameters.json
// ============================================================

targetScope = 'subscription'

// ── Core Parameters ────────────────────────────────────────

@description('Azure region for deployment')
param location string = deployment().location

@description('Unique environment name (e.g., prod, staging, dev). Drives deterministic resource naming.')
param environmentName string

@description('Database admin username')
param databaseUsername string

@description('Database admin password')
@secure()
param databasePassword string

// ── Networking ─────────────────────────────────────────────

@description('Use an existing VNet instead of creating one')
param useExistingVnet bool = false

@description('Resource ID of existing subnet for AKS nodes (required when useExistingVnet=true). Min /16.')
param existingAksSubnetId string = ''

@description('Resource ID of existing subnet for Application Gateway for Containers (required when useExistingVnet=true). Min /24. Must be delegated to Microsoft.ServiceNetworking/trafficControllers.')
param existingAgcSubnetId string = ''

@description('Resource ID of existing subnet for private endpoints (required when useExistingVnet=true). Min /24.')
param existingPeSubnetId string = ''

// ── Private Endpoints ──────────────────────────────────────

@description('Enable private endpoints for SQL, Key Vault, Service Bus, and Storage')
param enablePrivateEndpoints bool = true

@description('Use existing private DNS zones instead of creating new ones')
param useExistingDnsZones bool = false

@description('Resource group containing existing private DNS zones')
param existingDnsZoneResourceGroup string = ''

@description('Subscription ID containing existing private DNS zones (defaults to deployment subscription)')
param existingDnsZoneSubscriptionId string = subscription().subscriptionId

// ── Service Bus ────────────────────────────────────────────

@description('Service Bus SKU')
@allowed(['Standard', 'Premium'])
param serviceBusSku string = 'Standard'

// ── Variables ──────────────────────────────────────────────

var uniqueSuffix = substring(uniqueString(subscription().subscriptionId, location, environmentName), 0, 6)
var prefix = 'rpi-${uniqueSuffix}'
var tags = {
  'redpoint-rpi': 'agentic'
  'rpi-environment-id': uniqueSuffix
  environment: environmentName
  'managed-by': 'bicep'
}

// ── Resource Group ─────────────────────────────────────────

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${prefix}'
  location: location
  tags: tags
}

// ── Managed Identity (created first for cross-resource role assignments) ──

module identity 'identity.bicep' = {
  name: 'rpi-identity-${uniqueSuffix}'
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
  }
}

// ── All Resources ──────────────────────────────────────────

module resources 'resources.bicep' = {
  name: 'rpi-resources-${uniqueSuffix}'
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
    managedIdentityId: identity.outputs.id
    managedIdentityClientId: identity.outputs.clientId
    managedIdentityPrincipalId: identity.outputs.principalId
    databaseUsername: databaseUsername
    databasePassword: databasePassword
    serviceBusSku: serviceBusSku
    useExistingVnet: useExistingVnet
    existingAksSubnetId: existingAksSubnetId
    existingAgcSubnetId: existingAgcSubnetId
    existingPeSubnetId: existingPeSubnetId
  }
}

// ── Private Endpoints ──────────────────────────────────────

module privateEndpoints 'private-endpoints.bicep' = if (enablePrivateEndpoints) {
  name: 'rpi-pe-${uniqueSuffix}'
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
    peSubnetId: useExistingVnet ? existingPeSubnetId : resources.outputs.peSubnetId
    sqlServerId: resources.outputs.sqlServerId
    keyVaultId: resources.outputs.keyVaultId
    serviceBusId: resources.outputs.serviceBusId
    storageAccountId: resources.outputs.storageAccountId
    useExistingDnsZones: useExistingDnsZones
    existingDnsZoneResourceGroup: existingDnsZoneResourceGroup
    existingDnsZoneSubscriptionId: existingDnsZoneSubscriptionId
    subscriptionId: subscription().subscriptionId
  }
}

// ── Outputs ────────────────────────────────────────────────

output resourceGroupName string = rg.name
output environmentId string = uniqueSuffix
output aksClusterName string = resources.outputs.aksClusterName
output sqlServerFqdn string = resources.outputs.sqlServerFqdn
output keyVaultName string = resources.outputs.keyVaultName
output keyVaultUri string = resources.outputs.keyVaultUri
output serviceBusNamespace string = resources.outputs.serviceBusNamespace
output managedIdentityClientId string = identity.outputs.clientId
output managedIdentityPrincipalId string = identity.outputs.principalId
output storageAccountName string = resources.outputs.storageAccountName
output agcName string = resources.outputs.agcName
output pulseDatabaseName string = 'Pulse_${uniqueSuffix}'
output pulseLoggingDatabaseName string = 'Pulse_${uniqueSuffix}_Logging'

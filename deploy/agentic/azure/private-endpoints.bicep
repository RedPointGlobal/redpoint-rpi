// ============================================================
// Private Endpoints + DNS Zone Groups
// Creates PEs for SQL, Key Vault, Service Bus, and Storage.
// Supports both new and existing private DNS zones.
// ============================================================

param prefix string
param location string
param tags object
param peSubnetId string
param sqlServerId string
param postgresServerId string = ''
param keyVaultId string
param serviceBusId string
param storageAccountId string
param skipSqlPe bool = false
param skipPostgresPe bool = false
param skipServiceBusPe bool = false
param useExistingDnsZones bool
param existingDnsZoneResourceGroup string
param existingDnsZoneSubscriptionId string
param subscriptionId string

// ── DNS Zone ID resolution ─────────────────────────────────

var existingDnsRg = existingDnsZoneResourceGroup
var dnsZoneIdSql = useExistingDnsZones ? resourceId(existingDnsZoneSubscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.database.windows.net') : ''
var dnsZoneIdPg = useExistingDnsZones ? resourceId(existingDnsZoneSubscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.postgres.database.azure.com') : ''
var dnsZoneIdKv = useExistingDnsZones ? resourceId(existingDnsZoneSubscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net') : ''
var dnsZoneIdSb = useExistingDnsZones ? resourceId(existingDnsZoneSubscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.servicebus.windows.net') : ''
var dnsZoneIdStorage = useExistingDnsZones ? resourceId(existingDnsZoneSubscriptionId, existingDnsRg, 'Microsoft.Network/privateDnsZones', 'privatelink.file.${environment().suffixes.storage}') : ''

// ── New DNS Zones (only when NOT using existing) ───────────

resource dnsZoneSql 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!useExistingDnsZones) {
  name: 'privatelink.database.windows.net'
  location: 'global'
  tags: tags
}

resource dnsZoneKv 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!useExistingDnsZones) {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource dnsZoneSb 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!useExistingDnsZones) {
  name: 'privatelink.servicebus.windows.net'
  location: 'global'
  tags: tags
}

resource dnsZoneStorage 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!useExistingDnsZones) {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource dnsZonePg 'Microsoft.Network/privateDnsZones@2024-06-01' = if (!useExistingDnsZones && !skipPostgresPe) {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

// ── Private Endpoints ──────────────────────────────────────

// SQL Server
resource peSql 'Microsoft.Network/privateEndpoints@2024-01-01' = if (!skipSqlPe) {
  name: '${prefix}-pe-sql'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      { name: '${prefix}-pe-sql', properties: { privateLinkServiceId: sqlServerId, groupIds: ['sqlServer'] } }
    ]
  }
}

resource dnsGroupSql 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (!skipSqlPe) {
  parent: peSql
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config', properties: { privateDnsZoneId: useExistingDnsZones ? dnsZoneIdSql : dnsZoneSql.id } }
    ]
  }
}

// PostgreSQL
resource pePg 'Microsoft.Network/privateEndpoints@2024-01-01' = if (!skipPostgresPe) {
  name: '${prefix}-pe-pg'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      { name: '${prefix}-pe-pg', properties: { privateLinkServiceId: postgresServerId, groupIds: ['postgresqlServer'] } }
    ]
  }
}

resource dnsGroupPg 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (!skipPostgresPe) {
  parent: pePg
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config', properties: { privateDnsZoneId: useExistingDnsZones ? dnsZoneIdPg : dnsZonePg.id } }
    ]
  }
}

// Key Vault
resource peKv 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${prefix}-pe-kv'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      { name: '${prefix}-pe-kv', properties: { privateLinkServiceId: keyVaultId, groupIds: ['vault'] } }
    ]
  }
}

resource dnsGroupKv 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peKv
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config', properties: { privateDnsZoneId: useExistingDnsZones ? dnsZoneIdKv : dnsZoneKv.id } }
    ]
  }
}

// Service Bus
resource peSb 'Microsoft.Network/privateEndpoints@2024-01-01' = if (!skipServiceBusPe) {
  name: '${prefix}-pe-sb'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      { name: '${prefix}-pe-sb', properties: { privateLinkServiceId: serviceBusId, groupIds: ['namespace'] } }
    ]
  }
}

resource dnsGroupSb 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (!skipServiceBusPe) {
  parent: peSb
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config', properties: { privateDnsZoneId: useExistingDnsZones ? dnsZoneIdSb : dnsZoneSb.id } }
    ]
  }
}

// Storage Account (File)
resource peStorage 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${prefix}-pe-storage'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      { name: '${prefix}-pe-storage', properties: { privateLinkServiceId: storageAccountId, groupIds: ['file'] } }
    ]
  }
}

resource dnsGroupStorage 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: peStorage
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      { name: 'config', properties: { privateDnsZoneId: useExistingDnsZones ? dnsZoneIdStorage : dnsZoneStorage.id } }
    ]
  }
}

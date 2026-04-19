// ============================================================
// RPI v7.7 — Agentic AKS Resources
// ============================================================
// Creates: AKS Automatic, Azure SQL, Key Vault, Service Bus,
// Application Gateway for Containers, Storage Account, VNet (optional).
// ============================================================

param prefix string
param location string
param tags object
param managedIdentityId string
param managedIdentityClientId string
param managedIdentityPrincipalId string
@allowed(['sqlserver', 'postgresql'])
param databaseType string
param databaseUsername string
@secure()
param databasePassword string
param useExistingCluster bool
param existingClusterName string
param existingClusterResourceGroup string
param useExistingDatabase bool
param existingDatabaseServerFQDN string
param existingPulseDatabaseName string
param existingPulseLoggingDatabaseName string
param useExistingServiceBus bool
@secure()
param existingServiceBusConnectionString string
param serviceBusSku string
param useExistingVnet bool
param existingAksSubnetId string
param existingAgcSubnetId string
param existingPeSubnetId string

// ── Variables ──────────────────────────────────────────────

var createCluster = !useExistingCluster
var createDatabase = !useExistingDatabase
var createServiceBus = !useExistingServiceBus
var createSqlServer = createDatabase && databaseType == 'sqlserver'
var createPostgresServer = createDatabase && databaseType == 'postgresql'

var pulseDatabaseName = useExistingDatabase ? existingPulseDatabaseName : 'Pulse_${substring(prefix, 4, 6)}'
var pulseLoggingDatabaseName = useExistingDatabase ? existingPulseLoggingDatabaseName : '${pulseDatabaseName}_Logging'
var storageAccountName = replace('str${prefix}', '-', '')

// Placeholder value for existing infrastructure secrets the user must replace
var placeholderValue = '<replace-with-your-value-then-restart-pods>'

// ── VNet (created only when not using an existing one) ─────

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = if (!useExistingVnet) {
  name: 'vnet-${prefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/8'] }
    subnets: [
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: '10.0.0.0/16'
        }
      }
      {
        name: 'snet-agc'
        properties: {
          addressPrefix: '10.1.0.0/24'
          delegations: [
            { name: 'agc-delegation', properties: { serviceName: 'Microsoft.ServiceNetworking/trafficControllers' } }
          ]
        }
      }
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: '10.1.1.0/24'
        }
      }
    ]
  }
}

var aksSubnetId = useExistingVnet ? existingAksSubnetId : vnet.properties.subnets[0].id
var agcSubnetId = useExistingVnet ? existingAgcSubnetId : vnet.properties.subnets[1].id
var peSubnetIdResolved = useExistingVnet ? existingPeSubnetId : vnet.properties.subnets[2].id

// ── AKS Automatic ──────────────────────────────────────────

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' = if (createCluster) {
  name: 'aks-${prefix}'
  location: location
  tags: tags
  sku: {
    name: 'Automatic'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'systempool'
        mode: 'System'
        count: 3
        vnetSubnetID: aksSubnetId
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
    }
  }
}

// ── Key Vault ──────────────────────────────────────────────

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${prefix}'
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// Key Vault Secrets Officer role for the managed identity
resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityId, 'KeyVaultSecretsOfficer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Resolved database FQDN (handles SQL Server, PostgreSQL, and existing)
var dbServerFqdn = !createDatabase
  ? (empty(existingDatabaseServerFQDN) ? placeholderValue : existingDatabaseServerFQDN)
  : (createSqlServer ? sqlServer.properties.fullyQualifiedDomainName : postgresServer.properties.fullyQualifiedDomainName)

// Seed database secrets in Key Vault
// When using existing infrastructure, secrets are seeded with placeholder values.
// The user updates them in Key Vault post-deployment and restarts pods.
resource secretOpsConnStr 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ConnectionString-Operations-Database'
  properties: {
    value: !createDatabase ? placeholderValue : (databaseType == 'sqlserver'
      ? 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${pulseDatabaseName};User ID=${databaseUsername};Password=${databasePassword};Encrypt=True;TrustServerCertificate=True;'
      : 'Host=${postgresServer.properties.fullyQualifiedDomainName};Port=5432;Database=${pulseDatabaseName};Username=${databaseUsername};Password=${databasePassword};SSL Mode=Require;Trust Server Certificate=true;')
  }
}

resource secretLogConnStr 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ConnectionString-Logging-Database'
  properties: {
    value: !createDatabase ? placeholderValue : (databaseType == 'sqlserver'
      ? 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${pulseLoggingDatabaseName};User ID=${databaseUsername};Password=${databasePassword};Encrypt=True;TrustServerCertificate=True;'
      : 'Host=${postgresServer.properties.fullyQualifiedDomainName};Port=5432;Database=${pulseLoggingDatabaseName};Username=${databaseUsername};Password=${databasePassword};SSL Mode=Require;Trust Server Certificate=true;')
  }
}

resource secretDbPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'Operations-Database-Server-Password'
  properties: { value: createDatabase ? databasePassword : placeholderValue }
}

resource secretDbUsername 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'Operations-Database-Server-Username'
  properties: { value: createDatabase ? databaseUsername : placeholderValue }
}

resource secretDbHost 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'Operations-Database-ServerHost'
  properties: { value: dbServerFqdn }
}

resource secretPulseDb 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'Operations-Database-Pulse-Database-Name'
  properties: { value: pulseDatabaseName }
}

resource secretLoggingDb 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'Operations-Database-Pulse-Logging-Database-Name'
  properties: { value: pulseLoggingDatabaseName }
}

resource secretSmtpPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'SMTP-Password'
  properties: { value: '' }
}

// ── Azure SQL Server (conditional) ─────────────────────────

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = if (createSqlServer) {
  name: 'sql-${prefix}'
  location: location
  tags: tags
  properties: {
    administratorLogin: databaseUsername
    administratorLoginPassword: databasePassword
    version: '12.0'
    minimalTlsVersion: '1.2'
  }
}

// Elastic pool for Pulse databases (General Purpose: Gen5, 2 vCores)
resource sqlElasticPool 'Microsoft.Sql/servers/elasticPools@2023-08-01-preview' = if (createSqlServer) {
  parent: sqlServer
  name: 'ep-${prefix}'
  location: location
  tags: tags
  sku: {
    name: 'GP_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }
  properties: {
    perDatabaseSettings: {
      minCapacity: 0
      maxCapacity: 2
    }
  }
}

resource sqlDbPulse 'Microsoft.Sql/servers/databases@2023-08-01-preview' = if (createSqlServer) {
  parent: sqlServer
  name: pulseDatabaseName
  location: location
  tags: tags
  sku: { name: 'GP_Gen5', tier: 'GeneralPurpose', family: 'Gen5', capacity: 0 }
  properties: {
    elasticPoolId: sqlElasticPool.id
  }
}

resource sqlDbLogging 'Microsoft.Sql/servers/databases@2023-08-01-preview' = if (createSqlServer) {
  parent: sqlServer
  name: pulseLoggingDatabaseName
  location: location
  tags: tags
  sku: { name: 'GP_Gen5', tier: 'GeneralPurpose', family: 'Gen5', capacity: 0 }
  properties: {
    elasticPoolId: sqlElasticPool.id
  }
}

resource sqlFirewall 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (createSqlServer) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ── Azure PostgreSQL Flexible Server (conditional) ─────────

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = if (createPostgresServer) {
  name: 'pg-${prefix}'
  location: location
  tags: tags
  sku: { name: 'Standard_B2ms', tier: 'Burstable' }
  properties: {
    version: '16'
    administratorLogin: databaseUsername
    administratorLoginPassword: databasePassword
    storage: { storageSizeGB: 32 }
    backup: { backupRetentionDays: 7 }
  }
}

resource pgDbPulse 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = if (createPostgresServer) {
  parent: postgresServer
  name: pulseDatabaseName
}

resource pgDbLogging 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = if (createPostgresServer) {
  parent: postgresServer
  name: pulseLoggingDatabaseName
}

resource pgFirewall 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = if (createPostgresServer) {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ── Azure Service Bus (conditional) ────────────────────────

resource serviceBus 'Microsoft.ServiceBus/namespaces@2024-01-01' = if (createServiceBus) {
  name: 'sb-${prefix}'
  location: location
  tags: tags
  sku: { name: serviceBusSku, tier: serviceBusSku }
}

// RPI queues
var queueNames = [
  'RPIWebFormSubmission'
  'RPIWebEvents'
  'RPIWebCacheData'
  'RPIWebRecommendations'
  'RPIQueueListener'
  'RPICallbackApiQueue'
]

resource sbQueues 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = [for name in queueNames: if (createServiceBus) {
  parent: serviceBus
  name: name
  properties: { maxDeliveryCount: 10 }
}]

resource sbAuthRule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2024-01-01' = if (createServiceBus) {
  parent: serviceBus
  name: 'rpi-send-listen'
  properties: {
    rights: ['Send', 'Listen']
  }
}

// Store Service Bus connection string in Key Vault
resource secretServiceBus 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'RealtimeAPI-ServiceBus-ConnectionString'
  properties: {
    value: createServiceBus ? sbAuthRule.listKeys().primaryConnectionString : (empty(existingServiceBusConnectionString) ? placeholderValue : existingServiceBusConnectionString)
  }
}

// ── Storage Account (Azure Files for FileOutputDirectory) ──

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: 'rpifileoutput'
  properties: {
    shareQuota: 50
  }
}

// ── Application Gateway for Containers ─────────────────────

resource agc 'Microsoft.ServiceNetworking/trafficControllers@2023-11-01' = {
  name: 'agc-${prefix}'
  location: location
  tags: tags
}

resource agcFrontend 'Microsoft.ServiceNetworking/trafficControllers/frontends@2023-11-01' = {
  parent: agc
  name: 'fe-${prefix}'
  location: location
}

resource agcAssociation 'Microsoft.ServiceNetworking/trafficControllers/associations@2023-11-01' = {
  parent: agc
  name: 'assoc-${prefix}'
  location: location
  properties: {
    associationType: 'subnets'
    subnet: {
      id: agcSubnetId
    }
  }
}

// ── Outputs ────────────────────────────────────────────────

output aksClusterName string = createCluster ? aksCluster.name : existingClusterName
output sqlServerId string = createSqlServer ? sqlServer.id : ''
output postgresServerId string = createPostgresServer ? postgresServer.id : ''
output databaseServerFqdn string = !createDatabase ? existingDatabaseServerFQDN : (createSqlServer ? sqlServer.properties.fullyQualifiedDomainName : postgresServer.properties.fullyQualifiedDomainName)
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output serviceBusId string = createServiceBus ? serviceBus.id : ''
output serviceBusNamespace string = createServiceBus ? '${serviceBus.name}.servicebus.windows.net' : 'existing'
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output agcName string = agc.name
output peSubnetId string = peSubnetIdResolved
output pulseDatabaseName string = pulseDatabaseName
output pulseLoggingDatabaseName string = pulseLoggingDatabaseName

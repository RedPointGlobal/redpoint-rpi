// Parameters
param appSuffix string = 'rpi'
param location string = 'eastus2'
param appInsightsName string = 'appi-${appSuffix}-${location}'
param logAnalyticsName string = 'loga-${appSuffix}-${location}'
param caAppEnvironmentName string = 'cae-${appSuffix}-${location}'
param storageAccountName string = 'sa${appSuffix}fileassets'

@secure()
param rpiVersion string 

@secure()
param OperationalDatabaseType string

@secure()
param OperationalDatabaseName string

@secure()
param OperationalDatabasePassword string 

@secure()
param LoggingDatabaseName string 

@secure()
param OperationalDatabaseServer string

@secure()
param OperationalDatabaseUsername string 

param ContainerRegistryName string = 'rg1acrpub.azurecr.io'

@secure()
param ContainerRegistryUsername string 

@secure()
param containerRegistryPassword string 

@secure()
param connectionStringLoggingDatabase string 

@secure()
param connectionStringOperationalDatabase string 

@secure()
param virtualNetworkSubnetId string

// Create Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Application Insights 
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Container Apps Environment
resource env 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: caAppEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: { 
      internal: true 
      infrastructureSubnetId: virtualNetworkSubnetId
    }

    infrastructureResourceGroup: '${caAppEnvironmentName}-infra'
  }
}

// Step 1: Create a storage account
resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location 
  sku: {name: 'Standard_LRS'}
  kind: 'StorageV2'
}

// Container App | Deployment API
resource deploymentapi 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: '${appSuffix}-deploymentapi'
  location: location
  properties: {
    managedEnvironmentId: env.id 
    configuration: {
      ingress: {
        external: true
        targetPort: 8080 
        allowInsecure: false 
        traffic: [
          { 
            latestRevision: true 
            weight: 100
          }
        ]
      }
      registries: [
        { 
          server: ContainerRegistryName
          username: ContainerRegistryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        { 
          name: 'container-registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        { 
          name: '${appSuffix}-deploymentapi'
          image: '${ContainerRegistryName}/docker/redpointinteraction/prod/redpoint-interaction-configuration-editor:${rpiVersion}'
          resources: { 
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'ClusterEnvironment__OperationalDatabase__DatabaseType'
              value: OperationalDatabaseType
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__PulseDatabaseName'
              value: OperationalDatabaseName
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__LoggingDatabaseName'
              value: LoggingDatabaseName
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__ConnectionSettings__Server'
              value: OperationalDatabaseServer
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__ConnectionSettings__IsUsingCredentials'
              value: 'true'
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__ConnectionSettings__Username'
              value: OperationalDatabaseUsername
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__ConnectionSettings__Password'
              value: OperationalDatabasePassword
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__ConnectionSettings__DatabaseSchema'
              value: 'dbo'
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__ConnectionSettings__SQLServerSettings__Encrypt'
              value: 'true'
            }
            {
              name: 'ClusterEnvironment__OperationalDatabase__ConnectionSettings__SQLServerSettings__TrustServerCertificate'
              value: 'true'
            }
          ]
        }
      ]
      scale: { 
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Container Apps | InteractionAPI
resource interactionapi 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: '${appSuffix}-interactionapi'
  location: location
  properties: {
    managedEnvironmentId: env.id 
    configuration: {
      ingress: {
        external: true
        targetPort: 8080 
        allowInsecure: false 
        traffic: [
          { 
            latestRevision: true 
            weight: 100
          }
        ]
      }
      registries: [
        { 
          server: ContainerRegistryName
          username: ContainerRegistryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        { 
          name: 'container-registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        { 
          name: '${appSuffix}-interactionapi'
          image: '${ContainerRegistryName}/docker/redpointinteraction/prod/redpoint-interaction-api:${rpiVersion}'
          resources: { 
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'CONNECTIONSTRINGS__LOGGINGDATABASE'
              value: connectionStringLoggingDatabase
            }
            {
              name: 'CONNECTIONSTRINGS__OPERATIONALDATABASE'
              value: connectionStringOperationalDatabase
            }
            {
              name: 'RPI__FileOutput__Directory'
              value: '/rpifileoutputdir'
            }
            {
              name: 'Authentication__EnableRPIAuthentication'
              value: 'true'
            }
            {
              name: 'Authentication__RPIAuthentication__AuthMetaHttpHost'
              value: 'http://${appSuffix}-interactionapi'
            }
            {
              name: 'EnableSwagger'
              value: 'true'
            }
            {
              name: 'Logging__LogLevel__Default'
              value: 'Error'
            }
          ]
        }
      ]
      scale: { 
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = interactionapi.properties.configuration.ingress.fqdn

// Container Apps | IntegrationAPI
resource integrationapi 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: '${appSuffix}-integrationapi'
  location: location
  properties: {
    managedEnvironmentId: env.id 
    configuration: {
      ingress: {
        external: true
        targetPort: 8080 
        allowInsecure: false 
        traffic: [
          { 
            latestRevision: true 
            weight: 100
          }
        ]
      }
      registries: [
        { 
          server: ContainerRegistryName
          username: ContainerRegistryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        { 
          name: 'container-registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        { 
          name: '${appSuffix}-integrationapi'
          image: '${ContainerRegistryName}/docker/redpointinteraction/prod/redpoint-integration-api:${rpiVersion}'
          resources: { 
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'CONNECTIONSTRINGS__LOGGINGDATABASE'
              value: connectionStringLoggingDatabase
            }
            {
              name: 'CONNECTIONSTRINGS__OPERATIONALDATABASE'
              value: connectionStringOperationalDatabase
            }
            {
              name: 'Authentication__EnableRPIAuthentication'
              value: 'true'
            }
            {
              name: 'Authentication__RPIAuthentication__AuthMetaHttpHost'
              value: 'http://${appSuffix}-integrationapi'
            }
            {
              name: 'EnableSwagger'
              value: 'true'
            }
            {
              name: 'Logging__LogLevel__Default'
              value: 'Error'
            }
          ]
        }
      ]
      scale: { 
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Container Apps | Execution Service
resource executionservice 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: '${appSuffix}-executionservice'
  location: location
  properties: {
    managedEnvironmentId: env.id 
    configuration: {
      registries: [
        { 
          server: ContainerRegistryName
          username: ContainerRegistryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        { 
          name: 'container-registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        { 
          name: '${appSuffix}-executionservice'
          image: '${ContainerRegistryName}/docker/redpointinteraction/prod/redpoint-interaction-execution-service:${rpiVersion}'
          resources: { 
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'CONNECTIONSTRINGS__LOGGINGDATABASE'
              value: connectionStringLoggingDatabase
            }
            {
              name: 'CONNECTIONSTRINGS__OPERATIONALDATABASE'
              value: connectionStringOperationalDatabase
            }
            {
              name: 'RPIExecution__MaxThreadsPerExecutionService'
              value: '100'
            }
            {
              name: 'Authentication__EnableRPIAuthentication'
              value: 'true'
            }
          ]
        }
      ]
      scale: { 
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Container Apps | Node Manager
resource nodemanager 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: '${appSuffix}-nodemanager'
  location: location
  properties: {
    managedEnvironmentId: env.id 
    configuration: {
      registries: [
        { 
          server: ContainerRegistryName
          username: ContainerRegistryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        { 
          name: 'container-registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        { 
          name: '${appSuffix}-nodemanager'
          image: '${ContainerRegistryName}/docker/redpointinteraction/prod/redpoint-interaction-node-manager:${rpiVersion}'
          resources: { 
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'CONNECTIONSTRINGS__LOGGINGDATABASE'
              value: connectionStringLoggingDatabase
            }
            {
              name: 'CONNECTIONSTRINGS__OPERATIONALDATABASE'
              value: connectionStringOperationalDatabase
            }
            {
              name: 'Authentication__EnableRPIAuthentication'
              value: 'true'
            }
          ]
        }
      ]
      scale: { 
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Container Apps | RealtimeAPI
resource realtimeapi 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: '${appSuffix}-realtimeapi'
  location: location
  properties: {
    managedEnvironmentId: env.id 
    configuration: {
      ingress: {
        external: true
        targetPort: 8080 
        allowInsecure: false 
        traffic: [
          { 
            latestRevision: true 
            weight: 100
          }
        ]
      }
      registries: [
        { 
          server: ContainerRegistryName
          username: ContainerRegistryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      secrets: [
        { 
          name: 'container-registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        { 
          name: '${appSuffix}-realtimeapi'
          image: '${ContainerRegistryName}/docker/redpointinteraction/prod/redpoint-interaction-api:${rpiVersion}'
          resources: { 
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'CONNECTIONSTRINGS__LOGGINGDATABASE'
              value: connectionStringLoggingDatabase
            }
            {
              name: 'CONNECTIONSTRINGS__OPERATIONALDATABASE'
              value: connectionStringOperationalDatabase
            }
            {
              name: 'RPIClient__ApplicationSupportURL'
              value: 'https://support.redpointglobal.com'
            }
            {
              name: 'RPI__FileOutput__Directory'
              value: '/rpifileoutputdir'
            }
            {
              name: 'Authentication__EnableRPIAuthentication'
              value: 'true'
            }
            {
              name: 'Authentication__RPIAuthentication__EnableTransportSecurityRequirement'
              value: 'false'
            }
            {
              name: 'EnableSwagger'
              value: 'true'
            }
            {
              name: 'Logging__LogLevel__Default'
              value: 'Error'
            }
          ]
        }
      ]
      scale: { 
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

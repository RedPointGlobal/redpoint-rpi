![redpoint_logo](../chart/images/redpoint.png)
# Secrets Management

[< Back to main README](../README.md)

RPI supports three secrets management providers. The provider controls how sensitive values (database credentials, connection strings, internal service passwords) are stored and consumed by the chart.

---

## Providers

| Provider | How it works |
|:---------|:-------------|
| **kubernetes** (default) | The chart auto-generates a Kubernetes Secret (`redpoint-rpi-secrets`) containing all required keys. Internal service passwords (Redis, RabbitMQ) are randomly generated at install time. |
| **csi** | The CSI Secrets Store Driver syncs secrets from an external vault (Azure Key Vault, AWS Secrets Manager, GCP Secret Manager) into a Kubernetes Secret. You are responsible for storing ALL required keys in your vault. |
| **sdk** | Each service reads secrets directly from the vault at runtime using cloud identity. No Kubernetes Secret is created. |

---

## CSI Provider: Required Vault Keys

When `secretsManagement.provider: csi`, the chart expects a Kubernetes Secret (synced by CSI) containing specific keys. The required keys depend on which features are enabled in your overrides.

### Always Required

These keys must always be present in your vault and CSI SecretProviderClass:

| Key | Description |
|:----|:------------|
| `ConnectionString_Operations_Database` | Full connection string to the operational database |
| `ConnectionString_Logging_Database` | Full connection string to the logging database |
| `Operations_Database_ServerHost` | Database server hostname |
| `Operations_Database_Server_Username` | Database username |
| `Operations_Database_Server_Password` | Database password |
| `Operations_Database_Pulse_Database_Name` | Operational database name |
| `Operations_Database_Pulse_Logging_Database_Name` | Logging database name |

### Realtime API

Required when `realtimeapi.enabled: true`:

| Key | When required |
|:----|:--------------|
| `RealtimeAPI_Auth_Token` | Always (authentication token for API access) |
| `ConnectionString_RealtimeApi_OAuth` | When using OAuth authentication |

**Cache provider keys** (one set, depending on `realtimeapi.cacheProvider.provider`):

| Key | Provider |
|:----|:---------|
| `RealtimeAPI_MongoCache_ConnectionString` | mongodb |
| `RealtimeAPI_MongoCache_ConnectionKey` | mongodb |
| `RealtimeAPI_RedisCache_ConnectionString` | redis (external) |
| `RealtimeAPI_RedisCache_Password` | redis (internal, chart-managed) |

**Queue provider keys** (one set, depending on `realtimeapi.queueProvider.provider`):

| Key | Provider |
|:----|:---------|
| `RealtimeAPI_ServiceBus_ConnectionString` | azureservicebus |
| `RealtimeAPI_EventHub_ConnectionString` | azureeventhubs |
| `RealtimeAPI_AzureStorage_ConnectionString` | azurestorage |
| `RealtimeAPI_RabbitMQ_Password` | rabbitmq (internal, chart-managed) |

### Queue Reader (Distributed Processing)

Required when `queuereader.realtimeConfiguration.isDistributed: true`:

| Key | Description |
|:----|:------------|
| `QueueService_RedisCache_ConnectionString` | Redis connection string for the queue reader cache. Format: `rpi-queuereader-cache:6379,password=<password>,abortConnect=False` |
| `QueueService_RedisCache_Password` | Password for the queue reader Redis instance |
| `QueueService_RabbitMQ_Password` | Password for the queue reader RabbitMQ instance |

### SMTP

Required when `SMTPSettings.UseCredentials: true`:

| Key | Description |
|:----|:------------|
| `SMTP_Password` | SMTP server password |

### Redpoint AI

Required when `redpointAI.enabled: true`:

| Key | Description |
|:----|:------------|
| `RPI_NLP_SEARCH_KEY` | Azure Cognitive Search API key |
| `RPI_NLP_API_KEY` | OpenAI API key |
| `RPI_NLP_MODEL_CONNECTION_STRING` | Azure Blob Storage connection string for model artifacts |

### Diagnostics

| Key | When required |
|:----|:--------------|
| `CopyToAzureBlobAccessKey` | When `diagnosticsMode.copytoAzureBlob.enabled: true` |
| `CopyToSFTPSecureFTPPassword` | When `diagnosticsMode.copytoSftp.enabled: true` |

### Rebrandly

Required when `rebrandly.enabled: true`:

| Key | Description |
|:----|:------------|
| `Rebrandly_RedisPassword` | Password for the Rebrandly Redis instance |
| `Rebrandly_ApiKey` | Rebrandly API key |

### Smart Activation (CDP)

Required when `dataActivation.enabled: true`:

| Key | Description |
|:----|:------------|
| `CDP_Default_Password` | Default admin password |
| `CDP_Keycloak_Admin_Password` | Keycloak admin password |
| `CDP_Mongo_ConnectionString` | MongoDB connection string for CDP |
| `CDP_Integration_Password` | Integration API password |
| `CDP_RabbitMQ_Password` | CDP RabbitMQ password |
| `CDP_RabbitMQ_ErlangCookie` | Erlang cookie for RabbitMQ clustering |
| `CDP_Keycloak_Client_Secret` | Keycloak client secret |
| `CDP_SIGMA_Client_Secret` | Sigma reporting client secret (if reporting enabled) |

### AWS Cloud Identity

Required when `global.deployment.platform: amazon` with access key authentication:

| Key | Description |
|:----|:------------|
| `AWS_Access_Key_ID` | AWS IAM access key ID |
| `AWS_Secret_Access_Key` | AWS IAM secret access key |

---

## CSI SecretProviderClass Configuration

Your SecretProviderClass must include each required key in both `objects` (to fetch from vault) and `secretObjects` (to sync into the Kubernetes Secret).

### Example: Azure Key Vault

```yaml
secretsManagement:
  provider: csi
  csi:
    secretName: redpoint-rpi-secrets
    secretProviderClasses:
    - name: redpoint-rpi-secrets
      provider: azure
      parameters:
        clientID: <managed-identity-client-id>
        keyvaultName: <your-keyvault-name>
        resourceGroup: <your-resource-group>
        subscriptionId: <your-subscription-id>
        tenantId: <your-tenant-id>
        useVMManagedIdentity: "false"
        usePodIdentity: "false"
      objects:
      - objectName: ConnectionString-Operations-Database
        objectType: secret
        objectAlias: ConnectionString_Operations_Database
      - objectName: ConnectionString-Logging-Database
        objectType: secret
        objectAlias: ConnectionString_Logging_Database
      - objectName: Operations-Database-ServerHost
        objectType: secret
        objectAlias: Operations_Database_ServerHost
      - objectName: Operations-Database-Server-Username
        objectType: secret
        objectAlias: Operations_Database_Server_Username
      - objectName: Operations-Database-Server-Password
        objectType: secret
        objectAlias: Operations_Database_Server_Password
      - objectName: Operations-Database-Pulse-Database-Name
        objectType: secret
        objectAlias: Operations_Database_Pulse_Database_Name
      - objectName: Operations-Database-Pulse-Logging-Database-Name
        objectType: secret
        objectAlias: Operations_Database_Pulse_Logging_Database_Name
      # Add additional keys based on your enabled features (see tables above)
      secretObjects:
      - secretName: redpoint-rpi-secrets
        type: Opaque
        data:
        - objectName: ConnectionString_Operations_Database
          key: ConnectionString_Operations_Database
        - objectName: ConnectionString_Logging_Database
          key: ConnectionString_Logging_Database
        - objectName: Operations_Database_ServerHost
          key: Operations_Database_ServerHost
        - objectName: Operations_Database_Server_Username
          key: Operations_Database_Server_Username
        - objectName: Operations_Database_Server_Password
          key: Operations_Database_Server_Password
        - objectName: Operations_Database_Pulse_Database_Name
          key: Operations_Database_Pulse_Database_Name
        - objectName: Operations_Database_Pulse_Logging_Database_Name
          key: Operations_Database_Pulse_Logging_Database_Name
        # Add additional keys to match the objects list above
```

Note: Azure Key Vault secret names cannot contain underscores. Use hyphens in `objectName` and `objectAlias` to map to the underscore-based keys the chart expects.

---

## Internal Service Passwords (Redis, RabbitMQ)

When using the `kubernetes` provider, the chart auto-generates random passwords for internal Redis and RabbitMQ instances. When using the `csi` provider, you must generate these passwords yourself and store them in your vault.

For internal services, choose a strong random password and store it in your vault. The connection string keys must match the format the chart expects:

| Key | Format |
|:----|:-------|
| `QueueService_RedisCache_ConnectionString` | `rpi-queuereader-cache:6379,password=<your-password>,abortConnect=False` |
| `ExecutionService_RedisCache_ConnectionString` | `rpi-executionservice-cache:6379,password=<your-password>,abortConnect=False` |

The hostname in the connection string must match the internal service name the chart creates (e.g., `rpi-queuereader-cache`, `rpi-executionservice-cache`).

---

## Image Pull Secrets

Image pull secrets (for private container registries) cannot be managed through CSI due to a chicken-and-egg problem: the pod needs the secret to pull its image, but CSI only syncs secrets when a pod mounts the volume.

An image pull secret is only required when your cluster cannot already authenticate to the container registry. If your nodes already have access (e.g., EKS node IAM roles for ECR, AKS with `AcrPull` role on your own ACR), set `imagePullSecret.enabled: false` and no secret is needed.

When authentication is required (e.g., pulling directly from the Redpoint ACR, or from a private registry that requires credentials), create the secret before deploying using `kubectl create secret docker-registry` or `rpihelmcli secrets`.

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
| **sdk** | Each RPI service reads secrets directly from the vault at runtime using cloud identity. A separate `rpi-internal-services` Kubernetes Secret is auto-generated for chart-managed infrastructure (Redis, RabbitMQ). |

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

The chart deploys internal Redis and RabbitMQ StatefulSets for features like distributed queue processing and realtime caching. These are chart-managed infrastructure, not customer applications. They always run with authentication regardless of your secrets provider.

### How Internal Passwords Work Per Provider

| Provider | Internal service passwords | Secret name |
|:---------|:--------------------------|:------------|
| **kubernetes** | Auto-generated and stored in the main `redpoint-rpi-secrets` Secret alongside all other keys | `redpoint-rpi-secrets` |
| **csi** | You store them in your vault and include them in your SecretProviderClass. The CSI driver syncs them to the main Secret | `redpoint-rpi-secrets` (CSI-synced) |
| **sdk** | Auto-generated by the chart into a separate `rpi-internal-services` Secret. RPI services read application secrets (DB, cache, queue connections) from the vault, but connect to internal Redis/RabbitMQ using these auto-generated passwords | `rpi-internal-services` |

### SDK Provider: The `rpi-internal-services` Secret

When using the `sdk` provider, the chart automatically creates a Kubernetes Secret called `rpi-internal-services` with random passwords for all internal services. This secret is created at install time and preserved across upgrades (`helm.sh/resource-policy: keep`).

The internal secret contains:

| Key | Description |
|:----|:------------|
| `QueueService_RedisCache_Password` | Queue reader internal Redis password |
| `QueueService_RedisCache_ConnectionString` | Queue reader Redis connection string (includes hostname and password) |
| `QueueService_RabbitMQ_Password` | Queue reader internal RabbitMQ password |
| `ExecutionService_RedisCache_Password` | Execution service internal Redis password |
| `ExecutionService_RedisCache_ConnectionString` | Execution service Redis connection string |
| `RealtimeAPI_RedisCache_Password` | Realtime API internal Redis password |
| `RealtimeAPI_RabbitMQ_Password` | Realtime API internal RabbitMQ password |
| `Rebrandly_RedisPassword` | Rebrandly internal Redis password |

These passwords are generated and managed automatically by the chart. You do not need to create or populate this secret. The internal Redis and RabbitMQ containers reference this secret, as do the RPI services that connect to them.

To inspect the auto-generated passwords after deployment:

```bash
kubectl get secret rpi-internal-services -n <namespace> -o jsonpath='{.data.QueueService_RedisCache_Password}' | base64 -d
```

### CSI Provider: Internal Passwords in Your Vault

When using the `csi` provider, you are responsible for all keys including internal service passwords. Generate a strong password for each internal service and store it in your vault. The connection string keys must match the format the chart expects:

| Key | Format |
|:----|:-------|
| `QueueService_RedisCache_ConnectionString` | `rpi-queuereader-cache:6379,password=<your-password>,abortConnect=False` |
| `ExecutionService_RedisCache_ConnectionString` | `rpi-executionservice-cache:6379,password=<your-password>,abortConnect=False` |

The hostname in the connection string must match the internal service name the chart creates (e.g., `rpi-queuereader-cache`, `rpi-executionservice-cache`).

---

## Snowflake Private Key Authentication

Snowflake supports two methods for providing the RSA private key used in JWT authentication:

| Method | Connection string parameter | How it works |
|:-------|:---------------------------|:-------------|
| **File-based** | `PRIVATE_KEY_FILE=/app/snowflake-creds/key.p8` | The `.p8` file is mounted into the container from a Kubernetes Secret |
| **Inline** | `PRIVATE_KEY=<key-content>` | The private key content is passed directly in the connection string |

### Recommended Approach Per Provider

| Provider | Recommended method | Why |
|:---------|:-------------------|:----|
| **kubernetes** | File-based (`PRIVATE_KEY_FILE`) | The CLI creates the Secret from your `.p8` file. The chart mounts it automatically. |
| **csi** | File-based (`PRIVATE_KEY_FILE`) | A SecretProviderClass syncs the key from your vault to a Kubernetes Secret. A smoke test pod triggers the sync. |
| **sdk** | Inline (`PRIVATE_KEY`) | SDK services read secrets from the vault at runtime. There is no Kubernetes Secret to mount as a file, so use the inline method. |

### SDK Provider: Using Inline Private Key

When using the `sdk` provider, store the private key content (not the file) in your vault. In the RPI client, configure the Snowflake connection string using `PRIVATE_KEY` instead of `PRIVATE_KEY_FILE`:

```
User=<user>;Db=<database>;Host=<host>;Account=<account>;AUTHENTICATOR=snowflake_jwt;PRIVATE_KEY=<base64-encoded-key-content>;PRIVATE_KEY_PWD=<passphrase-if-encrypted>
```

If the private key value contains equal signs (`=`), replace each with two (`==`) so the connection string is parsed correctly.

With this approach, no Snowflake-related Helm configuration is needed in your overrides. The `databases.datawarehouse.snowflake` section and its associated Secret mount can be omitted entirely.

### Kubernetes / CSI Provider: Using File-based Private Key

For `kubernetes` and `csi` providers, configure the Snowflake section in your overrides to mount the `.p8` file:

```yaml
databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      secretName: snowflake-creds
      mountPath: /app/snowflake-creds
      keys:
      - keyName: my-snowflake-rsakey.p8
```

The connection string in the RPI client then uses the file path:

```
User=<user>;Db=<database>;Host=<host>;Account=<account>;AUTHENTICATOR=snowflake_jwt;PRIVATE_KEY_FILE=/app/snowflake-creds/my-snowflake-rsakey.p8
```

For CSI, add a SecretProviderClass that syncs the private key from your vault, and a smoke test deployment to trigger the CSI sync.

---

## Image Pull Secrets

Image pull secrets (for private container registries) cannot be managed through CSI due to a chicken-and-egg problem: the pod needs the secret to pull its image, but CSI only syncs secrets when a pod mounts the volume.

An image pull secret is only required when your cluster cannot already authenticate to the container registry. If your nodes already have access (e.g., EKS node IAM roles for ECR, AKS with `AcrPull` role on your own ACR), set `imagePullSecret.enabled: false` and no secret is needed.

You need an image pull secret when:
- **Pulling directly from the Redpoint Container Registry** (`rg1acrpub.azurecr.io`), which requires authentication credentials provided by Redpoint Support.
- **Pulling from an internal registry that requires Docker credentials** (e.g., Artifactory, Harbor, or any registry where node-level authentication is not configured).

In either case, create the secret before deploying. The `rpihelmcli secrets` command will prompt you for registry URL, username, and password, then generate the image pull secret automatically as part of the secrets workflow.

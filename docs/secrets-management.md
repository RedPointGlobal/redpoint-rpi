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

<details>
<summary><strong style="font-size:1.25em;">SDK Provider: Prerequisites</strong></summary>

When using the `sdk` provider, RPI services authenticate to your cloud vault using workload identity and read secrets at runtime. Before deploying, you must complete two steps:

### 1. Create a Managed Identity and Configure Workload Identity Federation

Create a User-Assigned Managed Identity (Azure), IAM Role (AWS), or GCP Service Account and grant it read access to your vault.

Then configure Kubernetes workload identity federation so the RPI pods can authenticate as that identity. The federation must cover the service accounts used by the RPI pods.

**Shared service account** (simplest): Create one federation for a single service account (e.g., `redpoint-rpi`). All RPI pods use this identity. Set `cloudIdentity.serviceAccount.mode: shared`.

```bash
# Example: Azure federated credential for a shared service account
az identity federated-credential create \
  --name rpi-shared \
  --identity-name <managed-identity-name> \
  --resource-group <rg> \
  --issuer <aks-oidc-issuer-url> \
  --subject system:serviceaccount:<namespace>:redpoint-rpi \
  --audiences api://AzureADTokenExchange
```

**Per-service service accounts** (more granular): Create a federation for each RPI service account. This allows different vault access policies per service but requires more setup. Set `cloudIdentity.serviceAccount.mode: per-service`.

The services that need federation:

| Service Account | Service |
|:----------------|:--------|
| `rpi-interactionapi` | Interaction API (client login, campaign management) |
| `rpi-executionservice` | Execution Service (workflow processing) |
| `rpi-nodemanager` | Node Manager (cluster coordination) |
| `rpi-integrationapi` | Integration API (data integration) |
| `rpi-realtimeapi` | Realtime API (decisioning, cache, queues) |
| `rpi-callbackapi` | Callback API (async callbacks) |
| `rpi-queuereader` | Queue Reader (queue processing) |
| `rpi-deploymentapi` | Deployment API (configuration management) |

```bash
# Example: Azure federated credentials for per-service accounts
for sa in rpi-interactionapi rpi-executionservice rpi-nodemanager \
          rpi-integrationapi rpi-realtimeapi rpi-callbackapi \
          rpi-queuereader rpi-deploymentapi; do
  az identity federated-credential create \
    --name "$sa" \
    --identity-name <managed-identity-name> \
    --resource-group <rg> \
    --issuer <aks-oidc-issuer-url> \
    --subject "system:serviceaccount:<namespace>:$sa" \
    --audiences api://AzureADTokenExchange
done
```

### 2. Create the Required Vault Secrets

Store the following secrets in your vault. The secret names must match exactly as shown. RPI services look up secrets by these names at runtime.

**Database connections** (always required):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `ConnectionStrings--LoggingDatabase` | Full connection string to the logging database |
| `ConnectionStrings--OperationalDatabase` | Full connection string to the operational database |
| `ClusterEnvironment--OperationalDatabase--PulseDatabaseName` | Operational database name |
| `ClusterEnvironment--OperationalDatabase--LoggingDatabaseName` | Logging database name |
| `ClusterEnvironment--OperationalDatabase--ConnectionSettings--Username` | Database username |
| `ClusterEnvironment--OperationalDatabase--ConnectionSettings--Password` | Database password |
| `ClusterEnvironment--OperationalDatabase--ConnectionSettings--Server` | Database server hostname |

**Realtime API** (if enabled):

| Vault Secret Name | Value | Description |
|:-------------------|:------|:------------|
| `RealtimeAPIConfiguration--AppSettings--RealtimeAPIKey` | Your API key | API key for Realtime API authentication |
| `RealtimeAPIConfiguration--AppSettings--RPIAuthToken` | Your auth token | Auth token for API access |

**Realtime API -- Cache provider** (e.g., MongoDB):

| Vault Secret Name | Value | Description |
|:-------------------|:------|:------------|
| `RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Key` | `ConnectionString` | Key name (always `ConnectionString`) |
| `RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Value` | Your cache connection string | MongoDB, Redis, or other cache connection string |

**Realtime API -- Client queue provider** (e.g., Azure Service Bus):

| Vault Secret Name | Value | Description |
|:-------------------|:------|:------------|
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Key` | `QueueType` | Key name (always `QueueType`) |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Value` | `ServiceBus` | Queue provider type (e.g., `ServiceBus`, `AmazonSQS`, `RabbitMQ`) |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Key` | `ConnectionString` | Key name (always `ConnectionString`) |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Value` | Your queue connection string | Service Bus, SQS, or other queue connection string |

**Realtime API -- Listener queue provider** (e.g., Azure Service Bus):

| Vault Secret Name | Value | Description |
|:-------------------|:------|:------------|
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Key` | `QueueType` | Key name (always `QueueType`) |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Value` | `ServiceBus` | Queue provider type (e.g., `ServiceBus`, `AmazonSQS`, `RabbitMQ`) |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Key` | `ConnectionString` | Key name (always `ConnectionString`) |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Value` | Your queue connection string | Service Bus, SQS, or other queue connection string |

**Callback API** (if enabled):

| Vault Secret Name | Value | Description |
|:-------------------|:------|:------------|
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Key` | `ConnectionString` | Key name (always `ConnectionString`) |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Value` | Your callback queue connection string | Queue connection string for callback processing |

**SMTP** (if sending email):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `RPI--SMTP--Password` | SMTP server password |

The secret names use `--` as the hierarchy separator. In Azure Key Vault, create the secrets with `--` in the name exactly as shown (e.g., `ConnectionStrings--LoggingDatabase`).

To automate the creation of these secrets, use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Vault Secrets Setup** to generate a Bash or Terraform script. The script can create a new Key Vault or use an existing one, and pre-populates all required secret names.

</details>

<details>
<summary><strong style="font-size:1.25em;">CSI Provider: Required Vault Keys</strong></summary>

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

</details>

<details>
<summary><strong style="font-size:1.25em;">CSI SecretProviderClass Configuration</strong></summary>

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

</details>

<details>
<summary><strong style="font-size:1.25em;">Internal Service Passwords (Redis, RabbitMQ)</strong></summary>

When distributed queue processing is enabled on the Queue Reader (`queuereader.realtimeConfiguration.isDistributed: true`), the chart deploys internal Redis and RabbitMQ StatefulSets. The Rebrandly service also deploys its own internal Redis when enabled. These are chart-managed infrastructure and always run with authentication regardless of your secrets provider.

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

The hostname in the connection string must match the internal service name the chart creates (e.g., `rpi-queuereader-cache`).

</details>

<details>
<summary><strong style="font-size:1.25em;">Snowflake Private Key Authentication</strong></summary>

Snowflake JWT authentication requires the `.p8` RSA private key file to be mounted in the container. All three providers use the file-based approach (`PRIVATE_KEY_FILE`), but the way the file gets into the pod differs.

### How It Works Per Provider

| Provider | Key source | Volume type | Validation pod needed? |
|:---------|:-----------|:------------|:-----------------------|
| **kubernetes** | CLI creates a K8s Secret from your `.p8` file | Secret volume with `subPath` | No |
| **csi** | SecretProviderClass syncs key from vault to a K8s Secret | Secret volume with `subPath` | Yes (triggers CSI sync) |
| **sdk** | SecretProviderClass mounts key directly via CSI inline volume | CSI inline volume | No (mounted by RPI pods directly) |

All three result in the same file path inside the container. The connection string in the RPI client is always:

```
User=<user>;Db=<database>;Host=<host>;Account=<account>;AUTHENTICATOR=snowflake_jwt;PRIVATE_KEY_FILE=/app/snowflake-creds/my-snowflake-rsakey.p8
```

### kubernetes Provider

The CLI (`rpihelmcli secrets`) creates a Kubernetes Secret from your `.p8` file. Configure the Snowflake section in your overrides:

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

### csi Provider

Store the `.p8` private key in your vault. Define a SecretProviderClass that syncs it to a K8s Secret, and a validation pod to trigger the sync:

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

secretsManagement:
  provider: csi
  csi:
    secretProviderClasses:
    - name: snowflake-creds
      provider: azure
      parameters:
        clientID: <managed-identity-client-id>
        keyvaultName: <your-keyvault>
        resourceGroup: <your-rg>
        subscriptionId: <your-sub>
        tenantId: <your-tenant>
        useVMManagedIdentity: "false"
        usePodIdentity: "false"
      objects:
      - objectName: my-snowflake-private-key
        objectType: secret
        objectAlias: my-snowflake-rsakey.p8
      secretObjects:
      - secretName: snowflake-creds
        type: Opaque
        data:
        - objectName: my-snowflake-rsakey.p8
          key: my-snowflake-rsakey.p8

validationPods:
  deployments:
  - name: deployment-sf
    enabled: true
    containerName: secrets
    image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
    type: csiSecret
    secretProviderClass: snowflake-creds
    mountPath: /home/secrets/snowflake
    volumeName: secrets-store-sf
```

### sdk Provider

With SDK, RPI services read secrets from the vault at runtime. But Snowflake needs a file, not a runtime value. The chart solves this by mounting the key directly via a CSI inline volume on the RPI pods themselves, so no K8s Secret is created and no validation pod is needed.

Define a SecretProviderClass under `secretsManagement.csi` (the chart renders it regardless of the main provider) and set `secretProviderClassName` on the Snowflake config:

```yaml
secretsManagement:
  provider: sdk
  sdk:
    azure:
      vaultUri: https://myvault.vault.azure.net/
      configurationReloadIntervalSeconds: 30
      useADTokenForDatabaseConnection: true
  csi:
    secretProviderClasses:
    - name: snowflake-creds
      provider: azure
      parameters:
        clientID: <managed-identity-client-id>
        keyvaultName: <your-keyvault>
        resourceGroup: <your-rg>
        subscriptionId: <your-sub>
        tenantId: <your-tenant>
        useVMManagedIdentity: "false"
        usePodIdentity: "false"
      objects:
      - objectName: my-snowflake-private-key
        objectType: secret
        objectAlias: my-snowflake-rsakey.p8

databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      secretName: snowflake-creds
      mountPath: /app/snowflake-creds
      secretProviderClassName: snowflake-creds
      keys:
      - keyName: my-snowflake-rsakey.p8
```

Key differences from the CSI provider approach:
- No `secretObjects` on the SecretProviderClass (no K8s Secret created)
- `secretProviderClassName` tells the chart to use a CSI inline volume instead of a Secret volume
- No validation pod needed since the CSI volume is mounted directly by the RPI pods
- The `objectAlias` controls the filename inside the container

</details>

<details>
<summary><strong style="font-size:1.25em;">Image Pull Secrets</strong></summary>

Image pull secrets (for private container registries) cannot be managed through CSI due to a chicken-and-egg problem: the pod needs the secret to pull its image, but CSI only syncs secrets when a pod mounts the volume.

An image pull secret is only required when your cluster cannot already authenticate to the container registry. If your nodes already have access (e.g., EKS node IAM roles for ECR, AKS with `AcrPull` role on your own ACR), set `imagePullSecret.enabled: false` and no secret is needed.

You need an image pull secret when:
- **Pulling directly from the Redpoint Container Registry** (`rg1acrpub.azurecr.io`), which requires authentication credentials provided by Redpoint Support.
- **Pulling from an internal registry that requires Docker credentials** (e.g., Artifactory, Harbor, or any registry where node-level authentication is not configured).

In either case, create the secret before deploying. The `rpihelmcli secrets` command will prompt you for registry URL, username, and password, then generate the image pull secret automatically as part of the secrets workflow.

</details>

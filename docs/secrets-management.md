![redpoint_logo](../chart/images/redpoint.png)
# Secrets Management

[< Back to main README](../README.md)

RPI supports three secrets management providers. The provider controls how sensitive values (database credentials, connection strings, internal service passwords) are stored and consumed by the chart.

---

## Providers

| Provider | How it works |
|:---------|:-------------|
| **kubernetes** (default) | The CLI (`rpihelmcli secrets`) prompts for your database credentials, connection strings, and other values, then generates a Kubernetes Secret (`redpoint-rpi-secrets`). Internal service passwords (Redis, RabbitMQ) are randomly generated. Apply the secret before deploying. |
| **csi** | The CSI Secrets Store Driver syncs secrets from an external vault (Azure Key Vault, AWS Secrets Manager, GCP Secret Manager) into a Kubernetes Secret. You are responsible for storing ALL required keys in your vault. |
| **sdk** | Each RPI service reads secrets directly from the vault at runtime using cloud identity. A separate `rpi-internal-services` Kubernetes Secret is auto-generated for chart-managed infrastructure (Redis, RabbitMQ). |

<details>
<summary><strong style="font-size:1.25em;">SDK Provider: Prerequisites</strong></summary>

When using the `sdk` provider, RPI services authenticate to your cloud vault using workload identity and read secrets at runtime. Before deploying, you need to:

1. **Create a Key Vault** (or use an existing one) and store the required secrets
2. **Create a Managed Identity** and grant it the required roles (vault access + storage access)
3. **Configure Workload Identity Federation** for each RPI service account

For Azure, the managed identity needs the following role assignments:

| Scope | Role |
|:------|:-----|
| Key Vault | `Key Vault Secrets Officer` |
| Storage Account (FileOutputDirectory) | `Reader` |
| Storage Account (FileOutputDirectory) | `Storage Account Key Operator Service Role` |
| Storage Account (FileOutputDirectory) | `Storage Blob Data Contributor` |
| Storage Account (FileOutputDirectory) | `Storage File Data SMB Share Contributor` |

The [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Vault Secrets Setup** generates a complete setup script (Bash or Terraform) that handles all three steps. Select your platform, enter your environment details, and download the script.

### Required Vault Secrets

The secret names use `--` as the hierarchy separator and must match exactly. RPI services look up secrets by these names at runtime.

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

| Vault Secret Name | Value |
|:-------------------|:------|
| `RealtimeAPIConfiguration--AppSettings--RealtimeAPIKey` | Your API key |
| `RealtimeAPIConfiguration--AppSettings--RPIAuthToken` | Your auth token |
| `RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Value` | Your cache connection string (MongoDB, Redis, etc.) |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Key` | `QueueType` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Value` | `ServiceBus` (or `AmazonSQS`, `RabbitMQ`) |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Value` | Your queue connection string |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Key` | `QueueType` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Value` | `ServiceBus` (or `AmazonSQS`, `RabbitMQ`) |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Value` | Your queue connection string |

**Callback API** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Key` | `ConnectionString` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Value` | Your callback queue connection string |

**SMTP** (if sending email):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI--SMTP--Password` | Your SMTP password |

### Workload Identity Federation

Each RPI service runs under its own Kubernetes ServiceAccount. The managed identity must have a federated credential for each service account so the pods can authenticate to Key Vault.

| Service Account | Service |
|:----------------|:--------|
| `rpi-interactionapi` | Interaction API |
| `rpi-integrationapi` | Integration API |
| `rpi-executionservice` | Execution Service |
| `rpi-nodemanager` | Node Manager |
| `rpi-realtimeapi` | Realtime API |
| `rpi-callbackapi` | Callback API |
| `rpi-queuereader` | Queue Reader |
| `rpi-deploymentapi` | Deployment API |

Use `cloudIdentity.serviceAccount.mode: per-service` in your overrides. This provides per-service audit trails in Key Vault access logs.

For a fully automated setup, use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Vault Secrets Setup** which generates a script that creates the Key Vault secrets, the managed identity, and all 8 federated credentials in one step.

</details>

<details>
<summary><strong style="font-size:1.25em;">CSI Provider: Required Vault Keys</strong></summary>

When `secretsManagement.provider: csi`, the CSI Secrets Store Driver syncs secrets from your vault into a Kubernetes Secret. The chart templates reference specific keys from that secret, so the names must match exactly.

### How It Works

1. You store secrets in your vault (e.g., Azure Key Vault)
2. You define a SecretProviderClass with `objects` (what to fetch) and `secretObjects` (what K8s Secret to create)
3. A validation pod mounts the SecretProviderClass to trigger the sync
4. The CSI driver creates the Kubernetes Secret, and RPI pods read from it

The vault secret names you choose can be anything (e.g., `V7-ConnectionString-Operations-Database`). The `objectAlias` in the SecretProviderClass maps your vault name to the key name the chart expects (e.g., `ConnectionString_Operations_Database`).

### Vault Secret Naming

Store your secrets in Key Vault using any naming convention you prefer. Then use `objectAlias` in the SecretProviderClass to map them to the keys the chart expects.

Example mapping:

| Your Key Vault secret name | `objectAlias` (what the chart expects) |
|:----------------------------|:---------------------------------------|
| `V7-ConnectionString-Operations-Database` | `ConnectionString_Operations_Database` |
| `V7-ConnectionString-LoggingDatabase` | `ConnectionString_Logging_Database` |
| `V7-Operations-Database-ServerHost` | `Operations_Database_ServerHost` |
| `V7-RealtimeAPI-Auth-Token` | `RealtimeAPI_Auth_Token` |

### Required Keys

The keys the chart expects in the synced Kubernetes Secret (the `objectAlias` / `secretObjects` key values):

**Always required:**

| Key | Description |
|:----|:------------|
| `ConnectionString_Operations_Database` | Full connection string to the operational database |
| `ConnectionString_Logging_Database` | Full connection string to the logging database |
| `Operations_Database_ServerHost` | Database server hostname |
| `Operations_Database_Server_Username` | Database username |
| `Operations_Database_Server_Password` | Database password |
| `Operations_Database_Pulse_Database_Name` | Operational database name |
| `Operations_Database_Pulse_Logging_Database_Name` | Logging database name |

**Realtime API** (if enabled):

| Key | Description |
|:----|:------------|
| `RealtimeAPI_Auth_Token` | Authentication token for API access |
| `ConnectionString_RealtimeApi_OAuth` | OAuth database connection string (if using OAuth) |
| `RealtimeAPI_MongoCache_ConnectionString` | MongoDB connection string (if mongodb cache) |
| `RealtimeAPI_MongoCache_ConnectionKey` | MongoDB connection key (if mongodb cache) |
| `RealtimeAPI_ServiceBus_ConnectionString` | Service Bus connection string (if azureservicebus queue) |
| `RealtimeAPI_RabbitMQ_Password` | RabbitMQ password (if rabbitmq queue, internal) |

**Queue Reader** (if distributed processing enabled):

| Key | Description |
|:----|:------------|
| `QueueService_RedisCache_ConnectionString` | Format: `rpi-queuereader-cache:6379,password=<password>,abortConnect=False` |
| `QueueService_RedisCache_Password` | Password for the queue reader Redis instance |
| `QueueService_RabbitMQ_Password` | Password for the queue reader RabbitMQ instance |

**SMTP** (if using credentials): `SMTP_Password`

**Rebrandly** (if enabled): `Rebrandly_RedisPassword`, `Rebrandly_ApiKey`

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Vault Secrets Setup** to generate a script that creates all required vault secrets. The same script works for both SDK and CSI -- the secrets are the same, only the naming convention differs (SDK uses `--` separators, CSI uses whatever names you choose and maps them via `objectAlias`).

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

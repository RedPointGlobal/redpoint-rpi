![redpoint_logo](../chart/images/redpoint.png)
# Secrets Management

[< Back to main README](../README.md)

RPI supports three secrets management providers. The provider controls how sensitive values (database credentials, connection strings, internal service passwords) are stored and consumed by the chart.

---

## Providers

| Provider | How it works |
|:---------|:-------------|
| **kubernetes** (default) | The CLI (`rpihelmcli/setup.sh secrets`) prompts for your database credentials, connection strings, and other values, then generates a Kubernetes Secret (`redpoint-rpi-secrets`). Internal service passwords (Redis, RabbitMQ) are randomly generated. Apply the secret before deploying. |
| **csi** | The CSI Secrets Store Driver syncs secrets from an external vault (Azure Key Vault, AWS Secrets Manager, GCP Secret Manager) into a Kubernetes Secret. You are responsible for storing ALL required keys in your vault. |
| **sdk** (recommended for cloud) | Each RPI service reads secrets directly from the vault at runtime using cloud identity. A separate `rpi-internal-services` Kubernetes Secret is auto-generated for chart-managed infrastructure (Redis, RabbitMQ). |

### What each provider handles

<details>
<summary><strong>kubernetes</strong></summary>

| Item | How it's handled |
|:-----|:----------------|
| Image pull secret | CLI prompts for registry credentials and creates the K8s Secret |
| Ingress TLS certificate | CLI prompts for cert/key files and creates a `kubernetes.io/tls` Secret |
| Snowflake private key (if using Snowflake) | CLI creates a K8s Secret from the `.p8` file, mounted as a volume |
| Custom CA certificate (if required) | CLI prompts for the CA bundle file and creates a K8s Secret |
| RPI application secrets | CLI prompts for database, realtime, SMTP credentials and creates the main K8s Secret |

</details>

<details>
<summary><strong>csi</strong></summary>

| Item | How it's handled |
|:-----|:----------------|
| Image pull secret | Create manually with `kubectl` before deploying |
| Ingress TLS certificate | SecretProviderClass syncs from vault into a `kubernetes.io/tls` K8s Secret |
| Snowflake private key (if using Snowflake) | SecretProviderClass syncs from vault into a K8s Secret, mounted as a volume |
| Custom CA certificate (if required) | SecretProviderClass syncs from vault into a K8s Secret |
| RPI application secrets | SecretProviderClass syncs all keys from vault into a K8s Secret |

A validation pod is required to trigger the initial CSI sync before RPI pods can start.

</details>

<details>
<summary><strong>sdk - Azure</strong></summary>

RPI services authenticate to Azure Key Vault using Workload Identity Federation and read application secrets at runtime. The CSI Secrets Store driver with the Azure Key Vault provider works fully with Workload Identity, so file-based secrets can also be pulled from Key Vault.

| Item | How it's handled |
|:-----|:----------------|
| Image pull secret | Create manually with `kubectl` before deploying |
| Ingress TLS certificate | SecretProviderClass syncs from Key Vault into a `kubernetes.io/tls` K8s Secret |
| Snowflake private key (if using Snowflake) | Mounted directly into the pod from Key Vault via CSI inline volume |
| Custom CA certificate (if required) | Mounted directly into the pod from Key Vault via CSI inline volume |
| RPI application secrets | Read directly from Azure Key Vault at runtime via SDK (no K8s Secret needed) |

No validation pods needed for application secrets. Snowflake keys and CA certs are mounted as files by the pods themselves.

</details>

<details>
<summary><strong>sdk - Amazon</strong></summary>

RPI services authenticate to AWS Secrets Manager using IRSA or Pod Identity and read application secrets at runtime.

| Item | How it's handled |
|:-----|:----------------|
| Image pull secret | Create manually with `kubectl` before deploying |
| AWS credentials | Create a K8s Secret with IAM access keys (`useAccessKeys: true`). The IAM user associated with these keys needs read/write access to Amazon SQS and Amazon S3. |
| Ingress TLS certificate | Create manually with `kubectl create secret tls` before deploying |
| Snowflake private key (if using Snowflake) | Create manually with `kubectl create secret generic` before deploying |
| Custom CA certificate (if required) | Create manually with `kubectl create secret generic` before deploying |
| RPI application secrets | Read directly from AWS Secrets Manager at runtime via SDK (no K8s Secret needed) |

No validation pods needed. File-based secrets (TLS cert, Snowflake key, CA cert) must be created as Kubernetes Secrets since the ingress controller and volume mounts cannot read from Secrets Manager directly.

</details>

<details>
<summary><strong>sdk - Google</strong></summary>

RPI services authenticate to Google Secret Manager using GKE Workload Identity and read application secrets at runtime.

| Item | How it's handled |
|:-----|:----------------|
| Image pull secret | Create manually with `kubectl` before deploying |
| Ingress TLS certificate | Create manually with `kubectl create secret tls` before deploying |
| Snowflake private key (if using Snowflake) | Create manually with `kubectl create secret generic` before deploying |
| Custom CA certificate (if required) | Create manually with `kubectl create secret generic` before deploying |
| RPI application secrets | Read directly from Google Secret Manager at runtime via SDK (no K8s Secret needed) |

No validation pods needed. File-based secrets (TLS cert, Snowflake key, CA cert) must be created as Kubernetes Secrets since the ingress controller and volume mounts cannot read from Secret Manager directly.

</details>

---

<details>
<summary><strong style="font-size:1.25em;">SDK Provider: Prerequisites</strong></summary>

When using the `sdk` provider, RPI services authenticate to your cloud vault using workload identity and read secrets at runtime. Before deploying, you need to:

1. **Create a Key Vault** (or use an existing one) and store the required secrets
2. **Create a Managed Identity** and grant it the required roles (vault access + storage access)
3. **Configure Workload Identity Federation** for each RPI service account

For Azure, the managed identity needs the following role assignments:

| Scope | Role(s) |
|:------|:--------|
| Key Vault | `Key Vault Secrets Officer` |
| Storage Account (FileOutputDirectory) | `Reader`, `Storage Account Key Operator Service Role`, `Storage Blob Data Contributor`, `Storage File Data SMB Share Contributor` |

The [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Azure** / **Amazon** / **Google** > **Vault Secrets Setup** generates a setup script that handles all three steps. Select your platform, enter your environment details, and download the script.

### Required Vault Secrets

The secret names must match exactly. The hierarchy separator differs by platform:

| Platform | Separator | Example |
|:---------|:----------|:--------|
| Azure Key Vault | `--` (double dash) | `ConnectionStrings--OperationalDatabase` |
| AWS Secrets Manager | `__` (double underscore) | `ConnectionStrings__OperationalDatabase` |
| Google Secret Manager | `--` (double dash) | `ConnectionStrings--OperationalDatabase` |

> Azure Key Vault does not allow `__` in secret names, so `--` is used instead. AWS Secrets Manager stores all keys as JSON within a single secret, so `__` is used to match the .NET configuration hierarchy.

The tables below use `{s}` as a placeholder for the platform-specific separator.

**Database connections** (always required):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `ConnectionStrings{s}LoggingDatabase` | Full connection string to the logging database |
| `ConnectionStrings{s}OperationalDatabase` | Full connection string to the operational database |
| `ClusterEnvironment{s}OperationalDatabase{s}PulseDatabaseName` | Operational database name |
| `ClusterEnvironment{s}OperationalDatabase{s}LoggingDatabaseName` | Logging database name |
| `ClusterEnvironment{s}OperationalDatabase{s}ConnectionSettings{s}Username` | Database username |
| `ClusterEnvironment{s}OperationalDatabase{s}ConnectionSettings{s}Password` | Database password |
| `ClusterEnvironment{s}OperationalDatabase{s}ConnectionSettings{s}Server` | Database server hostname |

**Realtime API** (if enabled):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `RealtimeAPIConfiguration{s}AppSettings{s}RealtimeAPIKey` | Your API key |
| `RealtimeAPIConfiguration{s}AppSettings{s}RPIAuthToken` | Your auth token |
| `RealtimeAPIConfiguration{s}CacheSettings{s}Caches{s}0{s}Settings{s}1{s}Key` | `ConnectionString` |
| `RealtimeAPIConfiguration{s}CacheSettings{s}Caches{s}0{s}Settings{s}1{s}Value` | Your cache connection string (MongoDB, Redis, etc.) |

<details>
<summary><strong>Azure queue secrets (Service Bus)</strong></summary>

| Vault Secret Name | Value |
|:-------------------|:------|
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Key` | `QueueType` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Value` | `ServiceBus` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Value` | Your Service Bus connection string |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Key` | `QueueType` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Value` | `ServiceBus` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Value` | Your Service Bus connection string |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--0--Key` | `QueueType` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--0--Value` | `ServiceBus` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Key` | `ConnectionString` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Value` | Your Service Bus connection string |

</details>

<details>
<summary><strong>AWS queue secrets (Amazon SQS)</strong></summary>

| Vault Secret Name | Value |
|:-------------------|:------|
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__0__Key` | `AccessKey` |
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__0__Value` | Your AWS access key ID |
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__1__Key` | `SecretKey` |
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__1__Value` | Your AWS secret access key |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__0__Key` | `AccessKey` |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__0__Value` | Your AWS access key ID |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__1__Key` | `SecretKey` |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__1__Value` | Your AWS secret access key |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__0__Key` | `AccessKey` |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__0__Value` | Your AWS access key ID |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__1__Key` | `SecretKey` |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__1__Value` | Your AWS secret access key |

</details>

<details>
<summary><strong>Google queue secrets (Pub/Sub)</strong></summary>

| Vault Secret Name | Value |
|:-------------------|:------|
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Key` | `QueueType` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--0--Value` | `GooglePubSub` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--Queues--ClientQueueSettings--Settings--1--Value` | Your GCP project ID |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Key` | `QueueType` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--0--Value` | `GooglePubSub` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--Queues--ListenerQueueSettings--Settings--1--Value` | Your GCP project ID |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--0--Key` | `QueueType` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--0--Value` | `GooglePubSub` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Key` | `ConnectionString` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Value` | Your GCP project ID |

</details>

**SMTP** (if sending email):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI{s}SMTP{s}Password` | Your SMTP password |

### Workload Identity / IRSA

Each RPI service runs under its own Kubernetes ServiceAccount. Your cloud identity must be configured to allow these service accounts to access the vault.

<details>
<summary><strong>Azure (Workload Identity Federation)</strong></summary>

The managed identity needs a federated credential for each service account:

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

Use `cloudIdentity.serviceAccount.mode: per-service` for per-service audit trails, or `mode: shared` for a single federation credential.

For automated setup, use the [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Azure** > **Vault Secrets Setup**.

</details>

<details>
<summary><strong>AWS (IRSA / Pod Identity / Access Keys)</strong></summary>

RPI on AWS supports multiple authentication methods. Choose based on your EKS configuration:

| Method | How it works | When to use |
|:-------|:-------------|:------------|
| **IRSA** | Service account annotated with IAM role ARN; JWT token injected at `/var/run/secrets/eks.amazonaws.com/serviceaccount/token` | Standard EKS managed/self-managed node groups |
| **Pod Identity** | Credentials injected via EKS Pod Identity Agent (`AWS_CONTAINER_CREDENTIALS_FULL_URI`) | EKS Auto Mode (IRSA token not injected on auto nodes) |
| **Access Keys** | Static IAM credentials stored in a K8s Secret, injected as env vars | When services need direct AWS API access (e.g., SQS) alongside IRSA/Pod Identity |

**IRSA + Access Keys** is the most common combination. IRSA handles Secrets Manager reads, while access keys provide credentials for services like Amazon SQS.

#### Setup

1. **Create an IAM role** with `SecretsManagerReadWrite` permissions and an OIDC trust policy for your EKS cluster
2. **Create IAM access keys** (if needed for SQS or other AWS services) and store them in a K8s Secret:

```bash
kubectl create secret generic rpi-aws-credentials \
  --from-literal=AWS_Access_Key_ID=<your-access-key-id> \
  --from-literal=AWS_Secret_Access_Key=<your-secret-access-key> \
  -n <namespace>
```

3. **Create file-based secrets** before deploying. These cannot be read from Secrets Manager at runtime:

```bash
# Ingress TLS certificate (required)
kubectl create secret tls ingress-tls \
  --cert=tls.crt --key=tls.key \
  -n <namespace>

# Snowflake private key (only if using Snowflake as a data warehouse)
kubectl create secret generic snowflake-rsa-private-key \
  --from-file=sf_rpi_usr_private_key.p8 \
  -n <namespace>

# Custom CA certificate (only if required)
kubectl create secret generic custom-ca-cert \
  --from-file=ca-bundle.pem \
  -n <namespace>
```

> **Why K8s Secrets for these?** The SDK provider enables RPI services to read application secrets (database credentials, connection strings, API keys) directly from Secrets Manager at runtime. However, the ingress controller, Snowflake JDBC driver, and CA trust store require secrets mounted as files and cannot call Secrets Manager themselves. These must exist as Kubernetes Secrets before deploying.

#### Overrides

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: per-service
  amazon:
    roleArn: arn:aws:iam::<account>:role/<role-name>
    region: us-east-1
    useAccessKeys: true                    # set to false if not using SQS or other direct AWS APIs
    accessKeySecretName: rpi-aws-credentials
    # usePodIdentity: true                 # uncomment for EKS Auto Mode (skips IRSA env vars)
```

For automated setup, use the [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Amazon** > **Vault Secrets Setup**.

</details>

<details>
<summary><strong>Google (Workload Identity)</strong></summary>

Create a GCP service account with `roles/secretmanager.secretAccessor` and bind it to the Kubernetes service accounts:

```bash
gcloud iam service-accounts add-iam-policy-binding <sa>@<project>.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:<project>.svc.id.goog[<namespace>/rpi-interactionapi]"
```

Repeat for each RPI service account, or use `mode: shared` for a single binding.

For automated setup, use the [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Google** > **Vault Secrets Setup**.

</details>

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

**SMTP** (if using credentials): `SMTP_Password`

> **Note:** Queue Reader internal passwords (`QueueService_RedisCache_Password`, `QueueService_RabbitMQ_Password`, `QueueService_RedisCache_ConnectionString`) are auto-generated by the chart into a `rpi-internal-services` K8s Secret. You do not need to store these in your vault.

**Rebrandly** (if enabled): `Rebrandly--ApiKey`

> **Note:** The Rebrandly Redis password (`Rebrandly_RedisPassword`) is auto-generated by the chart into the `rpi-internal-services` Secret. You do not need to store it in your vault.

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Azure** / **Amazon** / **Google** > **Vault Secrets Setup** to generate a script that creates all required vault secrets.

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

The CLI (`rpihelmcli/setup.sh secrets`) creates a Kubernetes Secret from your `.p8` file. Configure the Snowflake section in your overrides:

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

#### AWS Example

On AWS, use the AWS Secrets and Configuration Provider (ASCP) with `provider: aws` and `objectType: secretsmanager`:

```yaml
secretsManagement:
  provider: sdk
  sdk:
    amazon:
      secretTagKey: my-rpi-tag
  csi:
    secretProviderClasses:
    - name: snowflake-rsa-private-key
      provider: aws
      objects:
      - objectName: sf-rpi-svc-rsa-private-key
        objectType: secretsmanager
        objectAlias: sf_rpi_usr_private_key.p8

databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      secretName: snowflake-rsa-private-key
      mountPath: /app/snowflake-creds
      secretProviderClassName: snowflake-rsa-private-key
      keys:
      - keyName: sf_rpi_usr_private_key.p8
```

Store the `.p8` key in AWS Secrets Manager as a binary secret:

```bash
# Get the key from Azure Key Vault (if migrating)
# az keyvault secret show --vault-name <vault> --name <secret> --query value -o tsv > sf_rpi_usr_private_key.p8

# Create in AWS Secrets Manager
aws secretsmanager create-secret \
  --name sf-rpi-svc-rsa-private-key \
  --secret-binary fileb://sf_rpi_usr_private_key.p8 \
  --region us-east-1
```

Prerequisites: the [AWS Secrets and Configuration Provider](https://github.com/aws/secrets-store-csi-driver-provider-aws) and the CSI Secrets Store Driver must be installed on your EKS cluster.

</details>

<details>
<summary><strong style="font-size:1.25em;">TLS Certificates with SDK</strong></summary>

When using the SDK provider, the ingress TLS certificate must still be synced to a `kubernetes.io/tls` Kubernetes Secret because nginx reads TLS from K8s Secrets. Use a SecretProviderClass with `secretObjects` to sync from your vault.

### Azure

Store the certificate in Key Vault and define a SecretProviderClass:

```bash
az keyvault certificate import --vault-name <vault> --name my-tls-certificate --file ingress-cert.pem
```

### AWS

On AWS with the SDK provider, create the ingress TLS certificate as a Kubernetes Secret directly:

```bash
kubectl create secret tls ingress-tls \
  --cert=tls.crt --key=tls.key \
  -n <namespace>
```

The ingress controller reads the TLS cert from this K8s Secret. No SecretProviderClass or CSI driver is needed.

### SecretProviderClass configuration (Azure only)

Azure Key Vault splits the cert and key automatically from a single imported certificate:

```yaml
- name: ingress-tls-certificate
  provider: azure
  parameters:
    clientID: <managed-identity-client-id>
    keyvaultName: <your-keyvault>
    resourceGroup: <your-rg>
    subscriptionId: <your-sub>
    tenantId: <your-tenant>
  objects:
  - objectName: my-tls-certificate
    objectType: secret
  secretObjects:
  - secretName: ingress-tls
    type: kubernetes.io/tls
    data:
    - objectName: my-tls-certificate
      key: tls.key
    - objectName: my-tls-certificate
      key: tls.crt
```

A validation pod must mount this SecretProviderClass to trigger the initial sync of the K8s TLS Secret. The RPI pods themselves do not mount TLS certificates.

</details>

<details>
<summary><strong style="font-size:1.25em;">Custom CA Certificates with SDK</strong></summary>

When using the SDK provider, custom CA certificates can be mounted directly from your vault via CSI inline volume, just like Snowflake keys. This avoids having to create a separate Kubernetes Secret for the certificate.

### Azure

Store your CA bundle in Azure Key Vault, define a SecretProviderClass, and set `secretProviderClassName` on the `customCACerts` config:

```yaml
customCACerts:
  enabled: true
  mountPath: /usr/local/share/ca-certificates/custom
  certFile: ca-bundle.pem
  secretProviderClassName: ca-cert-provider

secretsManagement:
  provider: sdk
  sdk:
    azure:
      vaultUri: https://myvault.vault.azure.net/
  csi:
    secretProviderClasses:
    - name: ca-cert-provider
      provider: azure
      parameters:
        clientID: <managed-identity-client-id>
        keyvaultName: <your-keyvault>
        resourceGroup: <your-rg>
        subscriptionId: <your-sub>
        tenantId: <your-tenant>
      objects:
      - objectName: my-ca-bundle
        objectType: secret
        objectAlias: ca-bundle.pem
```

Store the certificate in Key Vault:

```bash
# az keyvault secret set --vault-name <vault> --name my-ca-bundle --file ca-bundle.pem
```

### AWS

On AWS with the SDK provider, create the CA certificate as a Kubernetes Secret directly:

```bash
kubectl create secret generic custom-ca-cert \
  --from-file=ca-bundle.pem \
  -n <namespace>
```

Then reference it in your overrides:

```yaml
customCACerts:
  enabled: true
  mountPath: /usr/local/share/ca-certificates/custom
  certFile: ca-bundle.pem
  secretName: custom-ca-cert
```

### Kubernetes / CSI providers

When using the `kubernetes` or `csi` provider, CA certificates are mounted from a Kubernetes Secret:

```yaml
customCACerts:
  enabled: true
  name: my-ca-certs
  mountPath: /usr/local/share/ca-certificates/custom
  certFile: ca-bundle.pem
```

Create the Secret:
```bash
kubectl create secret generic my-ca-certs \
  --from-file=ca-bundle.pem=ca-bundle.pem \
  -n redpoint-rpi
```

</details>

<details>
<summary><strong style="font-size:1.25em;">Image Pull Secrets</strong></summary>

Image pull secrets cannot be managed through your vault (SDK or CSI). The pod needs the pull secret to download its container image before it starts, so the secret must exist as a Kubernetes Secret in the namespace before deployment.

**When you need one:**
- Pulling directly from the Redpoint Container Registry (`rg1acrpub.azurecr.io`), which requires credentials from Redpoint Support
- Pulling from an internal registry that requires Docker credentials (Artifactory, Harbor, etc.)

**When you don't need one:**
- Your nodes already have access to the registry (e.g., EKS node IAM roles for ECR, AKS with `AcrPull` role). Set `imagePullSecret.enabled: false`.
- You mirror images to a registry your nodes can access natively.

**How to create it:**

When using `secretsManagement.provider: kubernetes`, the CLI (`rpihelmcli/setup.sh secrets`) will prompt for registry credentials and generate the pull secret automatically.

When using `sdk` or `csi`, the CLI skips the secrets flow. Create the pull secret manually before deploying:

```bash
kubectl create secret docker-registry redpoint-rpi \
  --docker-server=rg1acrpub.azurecr.io \
  --docker-username=<username> \
  --docker-password='<password>' \
  -n <namespace>
```

Then in your overrides:
```yaml
global:
  deployment:
    images:
      imagePullSecret:
        enabled: true
        name: redpoint-rpi
```

</details>

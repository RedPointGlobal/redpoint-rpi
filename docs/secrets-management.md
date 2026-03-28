![redpoint_logo](../chart/images/redpoint.png)
# Secrets Management

[< Back to Home](../README.md)

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

RPI services authenticate to AWS Secrets Manager using IRSA and read application secrets at runtime.

| Item | How it's handled |
|:-----|:----------------|
| Image pull secret | Create manually with `kubectl` before deploying |
| AWS credentials | Store `AWS_Access_Key_ID` and `AWS_Secret_Access_Key` in your vault alongside other application secrets. The IAM user needs read/write access to Amazon SQS and Amazon S3. |
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

## Kubernetes Provider — Creating the Application Secret

The chart does **not** create the `redpoint-rpi-secrets` Kubernetes Secret. You must create it before deploying. Sensitive values should **never** be stored in your overrides file.

### Recommended: Use the CLI

The CLI reads your overrides file, detects which secrets are required based on your configuration (database provider, realtime cache, queue provider, SMTP, Snowflake, etc.), and prompts for each value interactively:

```bash
rpihelmcli secrets -f overrides.yaml -n redpoint-rpi
```

This generates a `secrets.yaml` file. Apply it:

```bash
kubectl apply -f secrets.yaml -n redpoint-rpi
```

The CLI automatically:
- Builds the correct connection string format for your database provider (SQL Server, PostgreSQL, SQL Server on VM)
- Generates random passwords for internal services (Redis, RabbitMQ)
- Prompts for Snowflake `.p8` key files per tenant
- Prompts for the CA certificate bundle if `customCACerts` is enabled
- Skips sections that aren't enabled in your overrides

### Manual: Create the Secret with kubectl

If you prefer not to use the CLI (e.g., generating secrets in a CI/CD pipeline), create the secret manually. The secret must contain the keys that your configuration requires.

**Always required:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redpoint-rpi-secrets
  namespace: redpoint-rpi
type: Opaque
stringData:
  # Database connection strings (format depends on provider)
  # SQL Server:
  ConnectionString_Logging_Database: "Server=tcp:<host>,1433;Database=<logging-db>;User ID=<user>;Password=<password>;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
  ConnectionString_Operations_Database: "Server=tcp:<host>,1433;Database=<ops-db>;User ID=<user>;Password=<password>;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
  # PostgreSQL:
  # ConnectionString_Logging_Database: "PostgreSQL:Server=<host>;Database=<logging-db>;User Id=<user>;Password=<password>;"
  # ConnectionString_Operations_Database: "PostgreSQL:Server=<host>;Database=<ops-db>;User Id=<user>;Password=<password>;"

  # Deployment API needs these individually
  Operations_Database_ServerHost: "<host>"
  Operations_Database_Server_Username: "<user>"
  Operations_Database_Server_Password: "<password>"
  Operations_Database_Pulse_Database_Name: "<ops-db>"
  Operations_Database_Pulse_Logging_Database_Name: "<logging-db>"
```

**If Realtime API is enabled** (`realtimeapi.enabled: true`):

```yaml
  # Auth token (generate a random string)
  RealtimeAPI_Auth_Token: "<random-token>"

  # Cache provider connection (depends on cacheProvider.provider)
  # MongoDB:
  RealtimeAPI_MongoCache_ConnectionString: "mongodb+srv://<user>:<password>@<host>/<db>"
  # Redis:
  # RealtimeAPI_RedisCache_ConnectionString: "<host>:6379,password=<password>,abortConnect=False"

  # Queue provider connection (depends on queueProvider.provider)
  # Azure Service Bus:
  RealtimeAPI_ServiceBus_ConnectionString: "Endpoint=sb://<namespace>.servicebus.windows.net/;SharedAccessKeyName=<key-name>;SharedAccessKey=<key>"
  # Azure Event Hubs:
  # RealtimeAPI_EventHub_ConnectionString: "Endpoint=sb://<namespace>.servicebus.windows.net/;..."
  # Azure Storage:
  # RealtimeAPI_AzureStorage_ConnectionString: "DefaultEndpointsProtocol=https;AccountName=..."
```

**If Queue Reader is distributed** (`queuereader.realtimeConfiguration.isDistributed: true`):

```yaml
  # Internal Redis/RabbitMQ passwords (generate random strings)
  QueueService_RedisCache_Password: "<random-password>"
  QueueService_RedisCache_ConnectionString: "rpi-queuereader-cache:6379,password=<same-password>,abortConnect=False"
  QueueService_RabbitMQ_Password: "<random-password>"
```

**If SMTP uses credentials** (`SMTPSettings.UseCredentials: true`):

```yaml
  SMTP_Password: "<smtp-password>"
```

**If using AWS with access keys** (`cloudIdentity.amazon.useAccessKeys: true`):

```yaml
  AWS_Access_Key_ID: "<access-key>"
  AWS_Secret_Access_Key: "<secret-key>"
```

**If Redpoint AI is enabled** (`redpointAI.enabled: true`):

```yaml
  RPI_NLP_API_KEY: "<azure-openai-api-key>"
  RPI_NLP_SEARCH_KEY: "<cognitive-search-key>"
  RPI_NLP_MODEL_CONNECTION_STRING: "<model-storage-connection-string>"
```

**If Rebrandly is enabled** (`rebrandly.enabled: true`):

```yaml
  Rebrandly_RedisPassword: "<random-password>"
  Rebrandly_ApiKey: "<rebrandly-api-key>"
```

Apply the secret:

```bash
kubectl apply -f secrets.yaml -n redpoint-rpi
```

> **Note:** The CLI is strongly recommended over manual creation because it detects exactly which keys are needed from your overrides, formats connection strings correctly for your database provider, and generates random passwords for internal services. Manual creation risks missing required keys or using incorrect connection string formats.

---

## Azure

<details>
<summary><strong style="font-size:1.25em;">SDK Prerequisites</strong></summary>

When using the `sdk` provider on Azure, RPI services authenticate to Azure Key Vault using Workload Identity Federation and read secrets at runtime. Before deploying:

1. **Create an Azure Key Vault** (or use an existing one) and store the required secrets
2. **Create a Managed Identity** and grant it the required roles
3. **Configure Workload Identity Federation** for each RPI service account

The managed identity needs the following role assignments:

| Scope | Role(s) |
|:------|:--------|
| Key Vault | `Key Vault Secrets Officer` |
| Storage Account (FileOutputDirectory) | `Reader`, `Storage Account Key Operator Service Role`, `Storage Blob Data Contributor`, `Storage File Data SMB Share Contributor` |

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
<summary><strong style="font-size:1.25em;">Required Vault Secrets</strong></summary>

Azure Key Vault does not allow `__` in secret names, so `--` is used as the hierarchy separator. The secret names must match exactly.

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

| Vault Secret Name | Description |
|:-------------------|:------------|
| `RealtimeAPIConfiguration--AppSettings--RealtimeAPIKey` | Your API key |
| `RealtimeAPIConfiguration--AppSettings--RPIAuthToken` | Your auth token |
| `RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Key` | `ConnectionString` |
| `RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Value` | Your cache connection string (MongoDB, Redis, etc.) |

**Queue secrets (Service Bus):**

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

**Callback API** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--0--Key` | `QueueType` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--0--Value` | `ServiceBus` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Key` | `ConnectionString` |
| `CallbackServiceConfig--QueueProvider--CallbackServiceQueueSettings--Settings--1--Value` | Your Service Bus connection string |

**SMTP** (if sending email):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI--SMTP--Password` | Your SMTP password |

**Redpoint AI** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI--NLP--ApiKey` | Your Azure OpenAI API key |
| `RPI--NLP--SearchKey` | Your Azure Cognitive Search key |
| `RPI--NLP--ModelConnectionString` | Model storage connection string (Azure Blob) |

**Rebrandly** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `Rebrandly--ApiKey` | Your Rebrandly API key |

</details>

<details>
<summary><strong style="font-size:1.25em;">TLS Certificate</strong></summary>

Store the certificate in Key Vault:

```bash
az keyvault certificate import --vault-name <vault> --name my-tls-certificate --file ingress-cert.pem
```

Define a SecretProviderClass to sync from Key Vault into a `kubernetes.io/tls` K8s Secret. Azure Key Vault splits the cert and key automatically from a single imported certificate:

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
<summary><strong style="font-size:1.25em;">Snowflake Private Key</strong></summary>

With SDK on Azure, the Snowflake `.p8` key is mounted directly from Key Vault via CSI inline volume. No K8s Secret is created and no validation pod is needed.

Define a SecretProviderClass under `secretsManagement.csi` and set `secretProviderClassName` on the Snowflake config:

```yaml
secretsManagement:
  provider: sdk
  sdk:
    azure:
      vaultUri: https://myvault.vault.azure.net/
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
      mountPath: /app/snowflake-creds
      secretProviderClassName: snowflake-creds
      keys:
      - keyName: my-snowflake-rsakey.p8
```

The `objectAlias` in the SecretProviderClass controls the filename inside the container.

</details>

<details>
<summary><strong style="font-size:1.25em;">Custom CA Certificate</strong></summary>

With SDK on Azure, CA certificates are mounted directly from Key Vault via CSI inline volume.

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
az keyvault secret set --vault-name <vault> --name my-ca-bundle --file ca-bundle.pem
```

</details>

---

## Amazon

<details>
<summary><strong style="font-size:1.25em;">SDK Prerequisites</strong></summary>

RPI on AWS supports multiple authentication methods. Choose based on your EKS configuration:

| Method | How it works | When to use |
|:-------|:-------------|:------------|
| **IRSA** | Service account annotated with IAM role ARN; JWT token injected at `/var/run/secrets/eks.amazonaws.com/serviceaccount/token` | Standard EKS managed/self-managed node groups |
| **Access Keys** | IAM credentials stored in the main K8s Secret (`AWS_Access_Key_ID`, `AWS_Secret_Access_Key`), injected as env vars | When services need direct AWS API access (e.g., SQS, S3) alongside IRSA |

IRSA handles Secrets Manager reads, while access keys provide credentials for services like Amazon SQS and S3.

#### Setup

1. **Create an IAM role** with `SecretsManagerReadWrite` permissions and an OIDC trust policy for your EKS cluster

2. **Store AWS access keys** in your vault. The keys `AWS_Access_Key_ID` and `AWS_Secret_Access_Key` are read from the same K8s Secret as all other application secrets:
   - **SDK provider**: Include them in your Secrets Manager JSON secret
   - **CSI provider**: Add them to your SecretProviderClass jmesPath/secretObjects mapping
   - **kubernetes provider**: The CLI (`rpihelmcli/setup.sh`) prompts for them and writes them into `secrets.yaml`

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

> **Why K8s Secrets for file-based secrets?** The ingress controller, Snowflake JDBC driver, and CA trust store require secrets mounted as files and cannot call Secrets Manager themselves. These must exist as Kubernetes Secrets before deploying. On Azure, these can be synced from Key Vault via CSI SecretProviderClass instead.

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
```

For automated setup, use the [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Amazon** > **Vault Secrets Setup**.

</details>

<details>
<summary><strong style="font-size:1.25em;">Required Vault Secrets</strong></summary>

AWS Secrets Manager stores all keys as JSON within a single secret, using `__` (double underscore) as the hierarchy separator to match the .NET configuration hierarchy. The secret names must match exactly.

**Database connections** (always required):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `ConnectionStrings__LoggingDatabase` | Full connection string to the logging database |
| `ConnectionStrings__OperationalDatabase` | Full connection string to the operational database |
| `ClusterEnvironment__OperationalDatabase__PulseDatabaseName` | Operational database name |
| `ClusterEnvironment__OperationalDatabase__LoggingDatabaseName` | Logging database name |
| `ClusterEnvironment__OperationalDatabase__ConnectionSettings__Username` | Database username |
| `ClusterEnvironment__OperationalDatabase__ConnectionSettings__Password` | Database password |
| `ClusterEnvironment__OperationalDatabase__ConnectionSettings__Server` | Database server hostname |

**Realtime API** (if enabled):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `RealtimeAPIConfiguration__AppSettings__RealtimeAPIKey` | Your API key |
| `RealtimeAPIConfiguration__AppSettings__RPIAuthToken` | Your auth token |
| `RealtimeAPIConfiguration__CacheSettings__Caches__0__Settings__1__Key` | `ConnectionString` |
| `RealtimeAPIConfiguration__CacheSettings__Caches__0__Settings__1__Value` | Your cache connection string (MongoDB, Redis, etc.) |

**Queue secrets (Amazon SQS):**

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

**Callback API** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__0__Key` | `AccessKey` |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__0__Value` | Your AWS access key ID |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__1__Key` | `SecretKey` |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__1__Value` | Your AWS secret access key |

**SMTP** (if sending email):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI__SMTP__Password` | Your SMTP password |

**AWS Access Keys** (if `useAccessKeys: true`):

| Vault Secret Name | Value |
|:-------------------|:------|
| `AWS_Access_Key_ID` | Your IAM access key ID |
| `AWS_Secret_Access_Key` | Your IAM secret access key |

The IAM user needs read/write access to Amazon SQS and Amazon S3.

**Redpoint AI** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI__NLP__ApiKey` | Your Azure OpenAI API key |
| `RPI__NLP__SearchKey` | Your Azure Cognitive Search key |
| `RPI__NLP__ModelConnectionString` | Model storage connection string (Azure Blob) |

**Rebrandly** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `Rebrandly__ApiKey` | Your Rebrandly API key |

</details>

<details>
<summary><strong style="font-size:1.25em;">CSI Prerequisites</strong></summary>

When using the CSI provider on AWS, the AWS Secrets and Configuration Provider (ASCP) syncs secrets from Secrets Manager into Kubernetes Secrets. Before deploying, you need to:

1. **Install the CSI Secrets Store Driver and ASCP** on your EKS cluster (available as an EKS addon: `aws-secrets-manager`)
2. **Enable secret syncing** on the CSI driver (required for `secretObjects` to create K8s Secrets):
   ```json
   {
     "secrets-store-csi-driver": {
       "syncSecret": { "enabled": true },
       "enableSecretRotation": true
     }
   }
   ```
3. **Create secrets in Secrets Manager** before deploying:

**Step 1: Application secrets** (single JSON secret with all keys):

```bash
aws secretsmanager create-secret \
  --name <your-secret-name> \
  --description "RPI Application Secrets" \
  --secret-string '{}' \
  --region <your-region>
```

Then populate it with all required key-value pairs (see [Required Vault Secrets](#required-vault-secrets-1) above). The CSI SecretProviderClass uses `jmesPath` to extract individual keys from the JSON.

**Step 2: TLS certificate** (two separate binary secrets for cert and key):

```bash
aws secretsmanager create-secret \
  --name <prefix>-tls-crt \
  --secret-binary fileb://tls.crt \
  --region <your-region>

aws secretsmanager create-secret \
  --name <prefix>-tls-key \
  --secret-binary fileb://tls.key \
  --region <your-region>
```

The CSI driver syncs these into a `kubernetes.io/tls` K8s Secret for the ingress controller.

**Step 3: Snowflake private key** (if using Snowflake as a data warehouse):

```bash
aws secretsmanager create-secret \
  --name <prefix>-snowflake-key \
  --secret-binary fileb://sf_rpi_usr_private_key.p8 \
  --region <your-region>
```

The chart mounts this directly into pods via CSI inline volume. No K8s Secret is created.

**Step 4: CA certificate bundle** (if required):

```bash
aws secretsmanager create-secret \
  --name <prefix>-ca-bundle \
  --secret-binary fileb://ca-bundle.pem \
  --region <your-region>
```

Mounted directly into pods via CSI inline volume.

4. **Configure IRSA** so the pod service accounts can access Secrets Manager. The IAM role needs `SecretsManagerReadWrite` policy.

5. **Create a validation pod** to trigger the initial CSI sync. Without it, the K8s Secrets (`redpoint-rpi-secrets`, `ingress-tls`) won't exist and RPI pods will fail to start.

For automated setup scripts, use the [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Amazon** > **Vault Secrets Setup**.

</details>

<details>
<summary><strong style="font-size:1.25em;">TLS Certificate</strong></summary>

**SDK provider:** Create the ingress TLS certificate as a Kubernetes Secret directly:

```bash
kubectl create secret tls ingress-tls \
  --cert=tls.crt --key=tls.key \
  -n <namespace>
```

**CSI provider:** Store the cert and key as separate binary secrets in Secrets Manager and define a SecretProviderClass that syncs them into a `kubernetes.io/tls` K8s Secret:

```yaml
secretsManagement:
  csi:
    secretProviderClasses:
    - name: cert-secretprovider
      provider: aws
      parameters:
        region: us-east-1
      objects:
      - objectName: <prefix>-tls-crt
        objectType: secretsmanager
        objectAlias: tls.crt
      - objectName: <prefix>-tls-key
        objectType: secretsmanager
        objectAlias: tls.key
      secretObjects:
      - secretName: ingress-tls
        type: kubernetes.io/tls
        data:
        - objectName: tls.crt
          key: tls.crt
        - objectName: tls.key
          key: tls.key
```

A validation pod must mount this SecretProviderClass to trigger the sync.

</details>

<details>
<summary><strong style="font-size:1.25em;">Snowflake Private Key</strong></summary>

**SDK provider:** Create the Snowflake private key as a Kubernetes Secret directly:

```bash
kubectl create secret generic snowflake-rsa-private-key \
  --from-file=sf_rpi_usr_private_key.p8 \
  -n <namespace>
```

**CSI provider:** Store the `.p8` key as a binary secret in Secrets Manager and define a SecretProviderClass. The chart mounts it directly via CSI inline volume (no K8s Secret created):

```yaml
databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      secretName: <your-spc-name>
      mountPath: /app/snowflake-creds
      secretProviderClassName: <your-spc-name>
      keys:
      - keyName: sf_rpi_usr_private_key.p8

secretsManagement:
  csi:
    secretProviderClasses:
    - name: <your-spc-name>
      provider: aws
      parameters:
        region: us-east-1
      objects:
      - objectName: <prefix>-snowflake-key
        objectType: secretsmanager
        objectAlias: sf_rpi_usr_private_key.p8
```

No validation pod needed. The CSI volume is mounted directly by the RPI pods.

</details>

<details>
<summary><strong style="font-size:1.25em;">Custom CA Certificate</strong></summary>

**SDK provider:** Create the CA certificate as a Kubernetes Secret directly:

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

**CSI provider:** Store the CA bundle as a binary secret in Secrets Manager and define a SecretProviderClass. The chart mounts it directly via CSI inline volume:

```yaml
customCACerts:
  enabled: true
  mountPath: /usr/local/share/ca-certificates/custom
  certFile: ca-bundle.pem
  secretProviderClassName: <your-ca-spc-name>

secretsManagement:
  csi:
    secretProviderClasses:
    - name: <your-ca-spc-name>
      provider: aws
      parameters:
        region: us-east-1
      objects:
      - objectName: <prefix>-ca-bundle
        objectType: secretsmanager
        objectAlias: ca-bundle.pem
```

No validation pod needed. The CSI volume is mounted directly by the RPI pods.

</details>

---

## Google

<details>
<summary><strong style="font-size:1.25em;">SDK Prerequisites</strong></summary>

Create a GCP service account with `roles/secretmanager.secretAccessor` and bind it to the Kubernetes service accounts:

```bash
gcloud iam service-accounts add-iam-policy-binding <sa>@<project>.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:<project>.svc.id.goog[<namespace>/rpi-interactionapi]"
```

Repeat for each RPI service account, or use `mode: shared` for a single binding.

For automated setup, use the [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Google** > **Vault Secrets Setup**.

</details>

<details>
<summary><strong style="font-size:1.25em;">Required Vault Secrets</strong></summary>

Google Secret Manager uses `__` (double underscore) as the hierarchy separator. The secret names must match exactly.

**Database connections** (always required):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `ConnectionStrings__LoggingDatabase` | Full connection string to the logging database |
| `ConnectionStrings__OperationalDatabase` | Full connection string to the operational database |
| `ClusterEnvironment__OperationalDatabase__PulseDatabaseName` | Operational database name |
| `ClusterEnvironment__OperationalDatabase__LoggingDatabaseName` | Logging database name |
| `ClusterEnvironment__OperationalDatabase__ConnectionSettings__Username` | Database username |
| `ClusterEnvironment__OperationalDatabase__ConnectionSettings__Password` | Database password |
| `ClusterEnvironment__OperationalDatabase__ConnectionSettings__Server` | Database server hostname |

**Realtime API** (if enabled):

| Vault Secret Name | Description |
|:-------------------|:------------|
| `RealtimeAPIConfiguration__AppSettings__RealtimeAPIKey` | Your API key |
| `RealtimeAPIConfiguration__AppSettings__RPIAuthToken` | Your auth token |
| `RealtimeAPIConfiguration__CacheSettings__Caches__0__Settings__1__Key` | `ConnectionString` |
| `RealtimeAPIConfiguration__CacheSettings__Caches__0__Settings__1__Value` | Your cache connection string (MongoDB, Redis, etc.) |

**Queue secrets (Pub/Sub):**

| Vault Secret Name | Value |
|:-------------------|:------|
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__0__Key` | `QueueType` |
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__0__Value` | `GooglePubSub` |
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__1__Key` | `ConnectionString` |
| `RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__1__Value` | Your GCP project ID |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__0__Key` | `QueueType` |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__0__Value` | `GooglePubSub` |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__1__Key` | `ConnectionString` |
| `RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__1__Value` | Your GCP project ID |

**Callback API** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__0__Key` | `QueueType` |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__0__Value` | `GooglePubSub` |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__1__Key` | `ConnectionString` |
| `CallbackServiceConfig__QueueProvider__CallbackServiceQueueSettings__Settings__1__Value` | Your GCP project ID |

**SMTP** (if sending email):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI__SMTP__Password` | Your SMTP password |

**Redpoint AI** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `RPI__NLP__ApiKey` | Your Azure OpenAI API key |
| `RPI__NLP__SearchKey` | Your Azure Cognitive Search key |
| `RPI__NLP__ModelConnectionString` | Model storage connection string (Azure Blob) |

**Rebrandly** (if enabled):

| Vault Secret Name | Value |
|:-------------------|:------|
| `Rebrandly__ApiKey` | Your Rebrandly API key |

</details>

<details>
<summary><strong style="font-size:1.25em;">TLS Certificate</strong></summary>

On Google with the SDK provider, create the ingress TLS certificate as a Kubernetes Secret directly:

```bash
kubectl create secret tls ingress-tls \
  --cert=tls.crt --key=tls.key \
  -n <namespace>
```

The ingress controller reads the TLS cert from this K8s Secret.

</details>

<details>
<summary><strong style="font-size:1.25em;">Snowflake Private Key</strong></summary>

On Google with the SDK provider, create the Snowflake private key as a Kubernetes Secret directly:

```bash
kubectl create secret generic snowflake-rsa-private-key \
  --from-file=sf_rpi_usr_private_key.p8 \
  -n <namespace>
```

Then reference it in your overrides:

```yaml
databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      mountPath: /app/snowflake-creds
      keys:
      - keyName: sf_rpi_usr_private_key.p8
        secretName: snowflake-rsa-private-key
```

</details>

<details>
<summary><strong style="font-size:1.25em;">Custom CA Certificate</strong></summary>

On Google with the SDK provider, create the CA certificate as a Kubernetes Secret directly:

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

</details>

---

## Shared Reference

<details>
<summary><strong style="font-size:1.25em;">CSI Provider: Required Vault Keys</strong></summary>

When `secretsManagement.provider: csi`, the CSI Secrets Store Driver syncs secrets from your vault into a Kubernetes Secret. The chart templates reference specific keys from that secret, so the names must match exactly.

### How It Works

1. You store secrets in your vault (e.g., Azure Key Vault)
2. You define a SecretProviderClass with `objects` (what to fetch) and `secretObjects` (what K8s Secret to create)
3. A validation pod mounts the SecretProviderClass to trigger the sync
4. The CSI driver creates the Kubernetes Secret, and RPI pods read from it

The vault secret names should use the same platform-specific separator as the SDK provider:

| Platform | Separator | Example vault secret name |
|:---------|:----------|:--------------------------|
| Azure Key Vault | `--` (double dash) | `ConnectionStrings--OperationalDatabase` |
| AWS Secrets Manager | `__` (double underscore) | `ConnectionStrings__OperationalDatabase` |
| Google Secret Manager | `__` (double underscore) | `ConnectionStrings__OperationalDatabase` |

### Required Keys

The keys the chart expects in the synced Kubernetes Secret:

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

**Redpoint AI** (if enabled):

| Key | Description |
|:----|:------------|
| `RPI_NLP_API_KEY` | Azure OpenAI API key |
| `RPI_NLP_SEARCH_KEY` | Azure Cognitive Search key |
| `RPI_NLP_MODEL_CONNECTION_STRING` | Model storage connection string (Azure Blob) |

**Rebrandly** (if enabled): `Rebrandly--ApiKey`

**Distributed Queue** (if `queuereader.realtimeConfiguration.isDistributed: true`):

| Key | Description |
|:----|:------------|
| `QueueService_RedisCache_Password` | Internal Redis password for queue reader cache |
| `QueueService_RedisCache_ConnectionString` | Internal Redis connection string (format: `rpi-queuereader-cache:6379,password=<password>,abortConnect=False`) |
| `QueueService_RabbitMQ_Password` | Internal RabbitMQ password for queue reader |
| `Rebrandly_RedisPassword` | Internal Redis password for Rebrandly (if rebrandly enabled) |

> **Note:** For the **SDK** provider, these distributed queue and Rebrandly Redis passwords are auto-generated by the chart into the `rpi-internal-services` K8s Secret. You do not need to store them in your vault. For the **CSI** provider, you must store them in your vault and include them in your SecretProviderClass.

**AWS Access Keys** (if platform is Amazon and `useAccessKeys: true`):

| Key | Description |
|:----|:------------|
| `AWS_Access_Key_ID` | IAM access key ID for SQS/S3 access |
| `AWS_Secret_Access_Key` | IAM secret access key |

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
<summary><strong style="font-size:1.25em;">Snowflake: kubernetes and csi Providers</strong></summary>

Snowflake JWT authentication requires the `.p8` RSA private key file to be mounted in the container. The connection string in the RPI client is always:

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
      mountPath: /app/snowflake-creds
      keys:
      - keyName: my-snowflake-rsakey.p8
        secretName: snowflake-rsa-private-key
```

### csi Provider

Store the `.p8` private key in your vault. Define a SecretProviderClass and set `secretProviderClassName` on the Snowflake config. The key is mounted directly via CSI inline volume - no K8s Secret is created and no validation pod is needed.

```yaml
databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      mountPath: /app/snowflake-creds
      secretProviderClassName: snowflake-creds
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
      objects:
      - objectName: my-snowflake-private-key
        objectType: secret
        objectAlias: my-snowflake-rsakey.p8
```

For multi-tenant, add multiple objects to the same SecretProviderClass:

```yaml
      objects:
      - objectName: vault-tenant1-key
        objectType: secret
        objectAlias: tenant1-private-key.p8
      - objectName: vault-tenant2-key
        objectType: secret
        objectAlias: tenant2-private-key.p8
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

---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

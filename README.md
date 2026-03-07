![redpoint_logo](chart/images/logo.png)
## Redpoint Interaction (RPI) | Deployment on Kubernetes

With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

This chart deploys RPI on Kubernetes using Helm.

---
<p align="left">
  <a href="docs/greenfield.md"><strong>New Installation</strong></a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="docs/migration.md"><strong>Upgrade from v7.6</strong></a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="docs/readme-values.md"><strong>Values Guide</strong></a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="docs/readme-argocd.md"><strong>ArgoCD Guide</strong></a>&nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="docs/readme-mcp.md"><strong>MCP Server</strong></a>
</p>

---
![architecture](chart/images/diagram.png)

> **v7.7 Breaking Change** — The values file has been redesigned. You now maintain a small overrides file instead of a full copy of `values.yaml`. See [readme-values.md](docs/readme-values.md) for details.

---

## Choose Your Path

| | New Installation | Upgrading from v7.6 |
|---|---|---|
| **Guide** | [Greenfield Installation](docs/greenfield.md) | [Migration Guide](docs/migration.md) |
| **Environment** | New cluster, databases, cache, and queue providers | Existing v7.6 deployment with existing infrastructure |
| **Databases** | Created from scratch | Existing operational and logging databases are reused |
| **Overrides file** | Start from a `deploy/values/` example | Convert your existing `values.yaml` to the new format |

> **Quick Start (Demo Mode):** For evaluation or development, set `global.deployment.mode: demo` to deploy embedded MSSQL and MongoDB containers — no external database setup required. See [Demo Database Mode](#demo-database-mode).

![upgrade_diagram](chart/images/upgrade.png)

---

## System Requirements

| Component | Requirement |
|-----------|-------------|
| **Operational Databases** | Microsoft SQL Server 2019+, PostgreSQL — on `SQLServer on VM`, `AzureSQLDatabase`, `AmazonRDSSQL`, `GoogleCloudSQL`, or `PostgreSQL`. 8 GB RAM, 200 GB disk minimum. |
| **Data Warehouses** | `AzureSQLDatabase`, `AmazonRDSSQL`, `GoogleCloudSQL`, `SQLServer on VM`, `Snowflake`, `PostgreSQL`, `Amazon Redshift`, `Google BigQuery` |
| **Kubernetes** | Latest stable version from a [certified provider](https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/). Minimum two nodes (8 vCPU, 32 GB RAM each). |

**Example node SKUs:**

| Azure | AWS | GCP |
|-------|-----|-----|
| D8s_v5 | m5.2xlarge | n2-standard-8 |

These specs are for a modest environment. Adjust based on your production workloads.

## Prerequisites

Before starting, ensure you have:

- **Redpoint Container Registry** — Open a [Support](mailto:support@redpointglobal.com) ticket requesting access to download RPI images.
- **RPI License** — Open a [Support](mailto:support@redpointglobal.com) ticket to obtain your RPI v7 license activation key.
- **kubectl** — Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) for interacting with your Kubernetes cluster.
- **Helm** — Install [Helm](https://helm.sh/docs/helm/helm_install/) and ensure you have the required permissions for your target cluster.

## Repository Structure

```
redpoint-rpi/
├── chart/                        # Helm chart (don't edit)
│   ├── Chart.yaml
│   ├── values.yaml               # Chart defaults
│   └── templates/
│       ├── _defaults.tpl         # Internal defaults
│       ├── _helpers.tpl          # Merge helpers
│       └── deploy-*.yaml         # Resource templates
├── deploy/
│   ├── cli/rpi-init.sh           # Interactive overrides generator
│   ├── terraform/modules/        # IaC modules (Azure, AWS, GCP)
│   └── values/                   # Your environment overrides
│       ├── azure/azure.yaml      # Azure example
│       ├── aws/amazon.yaml       # AWS example
│       └── demo/demo.yaml        # Demo/dev example
├── docs/                         # Deployment guides
│   ├── greenfield.md             # New installation guide
│   ├── migration.md              # v7.6 → v7.7 upgrade guide
│   ├── readme-values.md          # Values & overrides guide
│   ├── readme-argocd.md          # ArgoCD deployment guide
│   ├── readme-mcp.md             # AI-assisted operations guide
│   ├── readme-terraform.md       # Terraform deployment guide
│   ├── smartActivation.md        # Smart Activation guide
│   └── values-reference.yaml     # Complete reference of all keys
└── README.md
```

---

## Configuration

After completing either the [Greenfield](docs/greenfield.md) or [Migration](docs/migration.md) guide, configure the optional features below that apply to your environment.

### Configure Cloud Identity

> **Optional.** Skip this section if you're not using cloud services.

Cloud provider identity enables RPI to authenticate with cloud services (secret managers, Azure/GCP plugins). The cloud provider is determined by `global.deployment.platform`. Supported methods: `Azure AKS Workload Identity`, `Google Workload Identity`, `Amazon IRSA (IAM Roles for Service Accounts)`.

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true       # true = shared SA for all services, false = per-service SAs
    name: redpoint-rpi
```

<details>
<summary><strong>Azure — Workload Identity</strong></summary>

Enable [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-migrate-from-pod-identity) and grant the Managed Identity access to the required Azure services:

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  azure:
    managedIdentityClientId: <your-managed-identity-client-id>
    tenantId: <your-azure-tenant-id>
```

</details>

<details>
<summary><strong>Google Cloud — Workload Identity</strong></summary>

Create a Google Service Account, enable [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) on your GKE cluster, and create a Kubernetes ConfigMap containing the JSON key file:

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  google:
    serviceAccountEmail: my-sa@my-project.iam.gserviceaccount.com
    projectId: <my-google-project-id>
    configMapName: my-google-svs-account
    keyName: my-google-svs-account.json
    configMapFilePath: /app/google-creds
```

</details>

<details>
<summary><strong>Amazon — IRSA (IAM Roles for Service Accounts)</strong></summary>

Create an IAM role with the required permissions and configure [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) on your EKS cluster:

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  amazon:
    roleArn: arn:aws:iam::123456789012:role/redpoint-rpi-irsa-role
    region: us-east-1
```

For environments that cannot use IRSA, static access keys are supported as a fallback:

```yaml
  amazon:
    useAccessKeys: true
    accessKeyId: <my-iam-access-key>
    secretAccessKey: <my-iam-secret-access-key>
    region: us-east-1
```

</details>

### Configure Secrets Management

Three modes are supported for managing sensitive configuration:

#### 1. Kubernetes Secrets (default)

Kubernetes Secrets and ConfigMaps are automatically created from your overrides file. No additional setup required.

```yaml
secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: true
    secretName: redpoint-rpi-secrets
```

To manage secrets yourself (e.g., via an external secrets operator), set `autoCreateSecrets: false` and create the Kubernetes Secret manually following the format in `chart/templates/deploy-secrets.yaml`.

<details>
<summary>Migrating from auto-created to self-managed secrets</summary>

```bash
# Export existing resources
kubectl get secret redpoint-rpi-secrets -o yaml > redpoint-rpi-secrets.yaml
kubectl get configmap odbc-config -o yaml > odbc-config.yaml

# Set autoCreateSecrets: false in your overrides, then:
kubectl apply -f redpoint-rpi-secrets.yaml
kubectl apply -f odbc-config.yaml
```

</details>

#### 2. SDK (cloud-native vault)

The application reads secrets directly from `Azure Key Vault`, `AWS Secrets Manager`, or `Google Secret Manager` at runtime. Requires `cloudIdentity.enabled: true`.

<details>
<summary><strong>Azure Key Vault</strong></summary>

1. Create a managed identity with a federated credential
2. Enable Workload Identity Federation on your AKS cluster
3. Grant the managed identity access to Key Vault

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  azure:
    managedIdentityClientId: your_managed_identity_client_id
    tenantId: your_azure_tenant_id

secretsManagement:
  provider: sdk
  sdk:
    azure:
      vaultUri: https://myvault.vault.azure.net/
      configurationReloadIntervalSeconds: 30
      useADTokenForDatabaseConnection: true
```

Secret names must replace underscores with hyphens. For example: `ConnectionStrings__OperationalDatabase` becomes `ConnectionStrings--OperationalDatabase`.

Required secrets:
```
ClusterEnvironment--OperationalDatabase--ConnectionSettings--Password
ClusterEnvironment--OperationalDatabase--ConnectionSettings--Username
ConnectionStrings--LoggingDatabase
ConnectionStrings--OperationalDatabase
RealtimeAPIConfiguration--AppSettings--RealtimeAPIKey
RealtimeAPIConfiguration--CacheSettings--Caches--0--Settings--1--Value
```

</details>

<details>
<summary><strong>AWS Secrets Manager</strong></summary>

The IAM role used by IRSA needs [SecretsManagerReadWrite](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/SecretsManagerReadWrite.html) permissions.

Create the secret with minimum required key/value pairs:

```bash
aws secretsmanager create-secret \
  --name <my-rpi-namespace-name> \
  --description "My RPI Application Secrets" \
  --secret-string '{
    "ClusterEnvironment__OperationalDatabase__ConnectionSettings__Username": "<my_sql_server_username>",
    "ClusterEnvironment__OperationalDatabase__ConnectionSettings__Password": "<my_sql_server_password>",
    "ConnectionStrings__LoggingDatabase": "<my_Pulse_Logging_Database_Connection_String>",
    "ConnectionStrings__OperationalDatabase": "<my_Pulse_Database_Connection_String>",
    "RealtimeAPIConfiguration__AppSettings__RPIAuthToken": "<my_realtime_auth_token>",
    "RealtimeAPIConfiguration__AppSettings__RealtimeAPIKey": "<my_realtime_auth_token>",
    "RealtimeAPIConfiguration__CacheSettings__Caches__0__Settings__1__Key": "ConnectionString",
    "RealtimeAPIConfiguration__CacheSettings__Caches__0__Settings__1__Value": "<my_mongodb_connection_string>",
    "RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__0__Key": "AccessKey",
    "RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__0__Value": "<my_IAM_AccessKey>",
    "RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__1__Key": "SecretKey",
    "RealtimeAPIConfiguration__Queues__ListenerQueueSettings__Settings__1__Value": "<my_IAM_Secret_AccessKey>",
    "RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__0__Key": "AccessKey",
    "RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__0__Value": "<my_IAM_AccessKey>",
    "RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__1__Key": "SecretKey",
    "RealtimeAPIConfiguration__Queues__ClientQueueSettings__Settings__1__Value": "<my_IAM_Secret_AccessKey>",
    "RPI__SMTP__Password": "<my_smtp_server_password>"
  }'

# Tag the secret (RPI filters by this tag)
aws secretsmanager tag-resource \
  --secret-id <my-rpi-namespace-name> \
  --tags Key=<my-rpi-namespace-name>,Value=true
```

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  amazon:
    roleArn: arn:aws:iam::123456789012:role/redpoint-rpi-irsa-role
    region: us-east-1

secretsManagement:
  provider: sdk
  sdk:
    amazon:
      secretTagKey: my-dev-namespace
```

</details>

<details>
<summary><strong>Google Secret Manager</strong></summary>

1. Create a Google Cloud Service Account
2. Grant secret access permissions
3. Enable Workload Identity Federation on GKE

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  google:
    serviceAccountEmail: my-sa@my-project.iam.gserviceaccount.com
    projectId: your_google_project_id
    configMapName: my-google-svs-account
    keyName: my-google-svs-account.json
    configMapFilePath: /app/google-creds

secretsManagement:
  provider: sdk
  sdk:
    google:
      projectId: your_google_project_id
```

</details>

#### 3. CSI Secrets Store (volume-mounted)

For environments using the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/), the chart creates `SecretProviderClass` resources that sync secrets from external vaults into Kubernetes Secrets. The pods then consume those synced secrets via `secretKeyRef` — the same way they consume `kubernetes` mode secrets. This works with Azure Key Vault, AWS Secrets Manager, GCP Secret Manager, and HashiCorp Vault. Requires `cloudIdentity.enabled: true`.

```yaml
secretsManagement:
  provider: csi
  csi:
    secretName: redpoint-rpi-secrets
    secretProviderClasses:
      - name: rpi-secrets
        provider: azure
        parameters:
          usePodIdentity: "false"
          useVMManagedIdentity: "false"
          useWorkloadIdentity: "true"
          clientID: "00000000-0000-0000-0000-000000000000"
          keyvaultName: my-keyvault
          tenantId: "00000000-0000-0000-0000-000000000000"
        objects:
          - objectName: V7-ConnectionString-Operations
            objectType: secret
        secretObjects:
          - secretName: rpi-synced-secrets
            type: Opaque
            data:
              - objectName: V7-ConnectionString-Operations
                key: ConnectionString_Operations_Database
      - name: cert-secretprovider
        provider: azure
        parameters:
          keyvaultName: my-keyvault
          clientID: "00000000-0000-0000-0000-000000000000"
          tenantId: "00000000-0000-0000-0000-000000000000"
          usePodIdentity: "false"
          useVMManagedIdentity: "false"
          useWorkloadIdentity: "true"
        objects:
          - objectName: my-tls-cert
            objectType: secret
        secretObjects:
          - secretName: certsecrets
            type: kubernetes.io/tls
            data:
              - objectName: my-tls-cert
                key: tls.key
              - objectName: my-tls-cert
                key: tls.crt
```

Each class is a standalone `SecretProviderClass` resource with its own `provider`, `parameters`, and `objects`.

### Configure Storage

RPI uses file share storage for [File Output directories](https://docs.redpointglobal.com/rpi/file-output-directory), custom plugins, and Redpoint Data Management (RPDM) uploads. Provision storage using your platform's managed service (`Azure Files`, `Amazon EFS`, `Google Filestore`), create PVCs, and reference them:

```yaml
storage:
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
    Plugins:
      enabled: true
      claimName: realtimeplugins
      mountPath: /app/plugins
    DataManagementUploadDirectory:
      enabled: true
      claimName: rpdmuploaddirectory
      mountPath: /rpdmuploaddirectory
```

#### Create PV + PVC Pairs

If your storage isn't pre-provisioned, the chart can create `PersistentVolume` and `PersistentVolumeClaim` resources for CSI-backed storage (Azure Blob, Azure Files, AWS EFS, GCP Filestore):

```yaml
storage:
  persistentVolumes:
    - name: rpi-blob-storage
      capacity: 100Gi
      accessModes: [ReadWriteMany]
      storageClassName: blob-fuse
      reclaimPolicy: Retain
      mountOptions:
        - -o allow_other
        - --file-cache-timeout-in-seconds=120
      csi:
        driver: blob.csi.azure.com
        volumeHandle: unique-volume-handle
        volumeAttributes:
          containerName: rpi-data
          storageAccount: mystorageaccount
      pvc:
        claimName: rpi-blob-pvc
```

Each entry generates a matched PV + PVC pair. The CSI driver, volume attributes, and mount options are passed through as-is — any CSI driver is supported.

### Configure Realtime

[RPI Realtime](https://docs.redpointglobal.com/rpi/configuring-realtime-queue-providers) enables real-time decisioning for personalized content delivery.

#### Queue Providers

Supported: `amazonsqs`, `googlepubsub`, `azureeventhubs`, `azureservicebus`, `rabbitmq`

```yaml
queueProvider:
  provider: amazonsqs
```

#### Personalized Content Queues

RabbitMQ is currently the only supported provider for personalized content delivery. Options:

| Mode | Configuration |
|------|--------------|
| **Internal** (chart-provisioned) | `type: internal` — free, open-source RabbitMQ deployed by the chart |
| **External** (BYO) | `type: external` — provide your own RabbitMQ connection details |

```yaml
queueProvider:
  rabbitmq:
    type: internal
    hostname: rpi-rabbitmq
    virtualHost: "/"
    username: redpointdev
    password: <my-secure-password>
```

The internal RabbitMQ console is available at `https://rpi-rabbitmq-console.example.com`.

![rabbitmq_config](https://cdn.redpointglobal.com/devops/rabbit_mq_personalized_content_queue.png)

#### Cache Providers

Supported: `mongodb`, `redis`, `googlebigtable`, `inMemorySql`

```yaml
cacheProvider:
  provider: mongodb
```

> **Note:** For SQL Server in-memory cache, download setup scripts from `https://$DEPLOYMENT_SERVICE_URL/download/UsefulSQLScripts` and run `UsefulSQLScripts\SQLServer\Realtime\In Memory Cache Setup.sql`.

#### API Authentication

**Basic** (default) — authentication token in the request header:

```yaml
realtimeapi:
  authentication:
    type: basic
```

**OAuth** — requires a `RealtimeCore` database. Download the creation script from `https://$DEPLOYMENT_SERVICE_URL/download/UsefulSQLScripts` (`UsefulSQLScripts\SQLServer\Realtime\RealtimeCore.sql`). Create it on the same SQL server as your operational databases, then:

```yaml
realtimeapi:
  authentication:
    type: oauth
```

<details>
<summary>OAuth token request example</summary>

```bash
# Request a bearer token
TOKEN=$(curl -L -X POST \
  "http://$REALTIME_API_ADDRESS/connect/token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "username=$USERNAME" \
  --data-urlencode "password=$PASSWORD" \
  --data-urlencode "client_secret=$CLIENT_SECRET" | jq -r '.access_token')

# Call the API
curl -X GET "https://$REALTIME_API_ADDRESS/api/v2/system/version" \
  -H "accept: application/json" \
  -H "Authorization: Bearer $TOKEN" | jq
```

</details>

#### Multi-Tenancy

RPI Realtime uses a single-tenant architecture. Deploy a separate Realtime instance per tenant with dedicated queues and cache:

```yaml
# values-realtime-tenant1.yaml
realtimeapi:
  enabled: true
interactionapi:
  enabled: false
executionservice:
  enabled: false
```

```bash
helm install realtime-tenant1 ./chart \
  --values values-realtime-tenant1.yaml --namespace redpoint-rpi
```

Repeat for each tenant with its own overrides file.

### RPI Queue Reader

The [Queue Reader](https://docs.redpointglobal.com/rpi/admin-queue-reader-setup) drains Queue Listener and Realtime queues, replacing the deprecated Web cache data importer, Web events importer, and Web form processor system tasks.

```yaml
queuereader:
  enabled: true
  realtimeConfiguration:
    isDistributed: false
    tenantIds:
      - "<my-rpi-client-id>"
```

**Operational endpoints** (available via Ingress):

| Endpoint | Description |
|----------|-------------|
| `/api/operations/start` | Initiate an operation |
| `/api/operations/status` | Get current status |
| `/api/operations/stop` | Stop an operation |
| `/api/operations/stats` | Execution statistics |

### Configure Microsoft Entra ID

RPI supports Microsoft Entra ID (formerly Azure AD) for SSO.

**1. Register the Interaction Client** in Azure Portal > Microsoft Entra ID > App registrations:
- Name: `interaction-client`. Note the `Client ID` and `Tenant ID`.
- Authentication > Redirect URIs: add `ms-appx-web://Microsoft.AAD.BrokerPlugin/{Client ID}` (type: Mobile & Desktop).

**2. Register the Interaction API:**
- Name: `interaction-api`. Note the `Client ID` and `Tenant ID`.
- Expose an API > add scope `Interaction.Clients` (name: `Access RPI`, consent: `Admins and users`).
- Authorized client applications > add the Interaction Client's `Client ID`.

**3. Enable in your overrides file:**

```yaml
MicrosoftEntraID:
  enabled: true
  name: Microsoft
  interaction_client_id: <interaction-client Client ID>
  interaction_api_id: <interaction-api Client ID>
  tenant_id: <azure tenant id>
```

> **Note:** Your RPI account email must match your Entra ID username (e.g., `first.last@example.com`).

### Configure Open ID Connect

RPI supports [OIDC providers](https://docs.redpointglobal.com/rpi/admin-appendix-b-open-id-connect-oidc-configuratio) for user authentication:

```yaml
OpenIdProviders:
  enabled: true
  name: Keycloak
```

### Configure Security Context

RPI containers run as non-root user `uid: 7777, gid: 777` by default.

**Option 1: Override via `advanced:` (recommended)**

For simple UID/GID changes:

```yaml
advanced:
  securityContext:
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
```

Per-component override:

```yaml
advanced:
  interactionapi:
    securityContext:
      runAsUser: 10001
      fsGroup: 10001
```

**Option 2: Custom container image**

If you need to reconcile file ownership, build a custom image:

<details>
<summary>Example Dockerfile</summary>

```dockerfile
FROM rg1acrpub.azurecr.io/docker/redpointglobal/releases/rpi-interactionapi

USER root

ENV RUNTIME_USER=redpointrpi
ENV RUNTIME_UID=10001
ENV RUNTIME_GROUP=redpointrpi
ENV RUNTIME_GID=10001

RUN addgroup --gid "$RUNTIME_GID" "$RUNTIME_GROUP" \
 && adduser --disabled-password --gecos "" --home /app \
    --ingroup "$RUNTIME_GROUP" --no-create-home --uid "$RUNTIME_UID" "$RUNTIME_USER"

RUN chown -R "$RUNTIME_UID":"$RUNTIME_GID" /app /app/logs /app/.dotnet-tools /app/.dotnet-counters

USER "$RUNTIME_UID":"$RUNTIME_GID"
```

</details>

### Configure Service Mesh

> **Optional.** Skip if you're not using a service mesh.

The chart can generate [Linkerd](https://linkerd.io/) `Server` CRDs for L7 traffic policy. Define one entry per service that should participate in the mesh:

```yaml
serviceMesh:
  enabled: true
  provider: linkerd
  servers:
    - name: realtimeapi
      podSelector:
        app.kubernetes.io/name: rpi-realtimeapi
      port: 8080
      proxyProtocol: HTTP/1
    - name: executionservice
      podSelector:
        app.kubernetes.io/name: rpi-executionservice
      port: 8080
      proxyProtocol: HTTP/1
```

Per-service proxy annotations (e.g., Linkerd timeout overrides, skip-outbound-ports) can be applied via `podAnnotations`:

```yaml
executionservice:
  podAnnotations:
    config.linkerd.io/skip-outbound-ports: "443"
    config.linkerd.io/proxy-outbound-connect-timeout: "240000ms"
```

See [Per-Service Pod Annotations](#per-service-pod-annotations--labels) below.

### Configure Automatic Database Upgrades

> **Optional.** Recommended for all environments to simplify version upgrades.

After updating the RPI container image tag, the operational databases must be upgraded by calling the deployment API endpoint. By default this is a manual step. Enable automatic database upgrades to have the chart run this call for you:

```yaml
databaseUpgrade:
  enabled: true
```

When enabled, the chart creates a Kubernetes Job whose name includes the image tag. On each `helm upgrade` that changes the tag, a new Job is created that:

1. Waits for `rpi-deploymentapi` to become healthy
2. Calls the upgrade endpoint (`/api/deployment/upgrade`)
3. Logs the response and exits

The upgrade endpoint is idempotent — safe to run multiple times. Completed Jobs are auto-cleaned after 1 hour.

**ArgoCD compatibility:** The Job includes `argocd.argoproj.io/hook: PostSync` annotations. ArgoCD runs it as a post-sync hook after all resources are healthy, then cleans it up automatically. For plain Helm deployments, these annotations are ignored and the Job behaves normally.

<details>
<summary><strong>Email notification</strong></summary>

Send the upgrade result to an email address using the chart's existing SMTP settings:

```yaml
databaseUpgrade:
  enabled: true
  notification:
    enabled: true
    recipientEmail: admin@example.com
```

The email includes the full upgrade API response (status, messages, version info). Requires `SMTPSettings` to be configured. Email failures are non-fatal — the upgrade still succeeds.

</details>

<details>
<summary><strong>Monitor the upgrade Job</strong></summary>

```bash
kubectl get jobs -n redpoint-rpi -l app.kubernetes.io/component=upgrade
kubectl logs -n redpoint-rpi -l app.kubernetes.io/component=upgrade --tail=50
```

</details>

<details>
<summary><strong>Advanced overrides</strong></summary>

All Job parameters can be tuned via `advanced.databaseUpgrade` or at the top level:

```yaml
databaseUpgrade:
  enabled: true
  waitTimeoutSeconds: "600"      # Increase upgrade timeout
  maxReadyWaitSeconds: "900"     # Wait longer for deploymentapi

advanced:
  databaseUpgrade:
    backoffLimit: 5              # More retry attempts
    pollIntervalSeconds: "10"    # Poll more frequently
```

See `docs/values-reference.yaml` for all available keys.

</details>

### Smoke Tests

> **Optional.** Enable during initial setup or after infrastructure changes to validate mounts.

When a service fails to start, it can be hard to tell whether the problem is the application or the underlying infrastructure (IAM permissions, CSI drivers, storage accounts, Key Vault access policies). Smoke tests isolate infrastructure issues by deploying minimal pods that do nothing except mount a single volume and sit there. If a smoke test pod starts, the infrastructure works. If it's stuck in `ContainerCreating`, the problem is the mount — not your application.

**Recommended workflow for initial setup:**
1. Enable smoke tests and deploy — `helm upgrade --install rpi ./chart -f overrides.yaml`
2. Check pod status — `kubectl get pods` (look for your smoke test deployment names)
3. Verify mounts — `kubectl exec deployment-blob-<pod-id> -- ls /mnt/rpifileoutputdir`
4. Once all smoke test pods are running, disable them and deploy the full application

Each test is a single-replica Deployment that either writes to a PVC or reads from a CSI secret volume.

```yaml
smokeTests:
  enabled: true
  deployments:
    # Verify blob storage PVC is writable
    - name: blob
      type: pvc
      claimName: rpifileoutputdir
      mountPath: /mnt/rpifileoutputdir
    # Verify CSI secrets are accessible
    - name: kv-secrets
      type: csiSecret
      secretProviderClass: rpi-secrets
      mountPath: /mnt/secrets
```

| Type | Behavior |
|------|----------|
| `pvc` | Mounts the PVC and writes a timestamp to `smoketest.log` every 30 seconds |
| `csiSecret` | Mounts the SecretProviderClass volume and lists the mounted files |

Once verified, set `smokeTests.enabled: false` to remove the test pods.

### Post-Deploy Validation

After install or upgrade, run `helm test` to verify all services are healthy and reachable:

```bash
helm test rpi -n redpoint-rpi
```

This creates a short-lived pod that checks `/health/ready` on every enabled service. A healthy response confirms the service is running, its image was pulled, volumes are mounted, and DNS resolution works.

```
RPI Connectivity Test

PASS  rpi-realtimeapi
PASS  rpi-callbackapi
PASS  rpi-executionservice
PASS  rpi-interactionapi
PASS  rpi-integrationapi
PASS  rpi-nodemanager
PASS  rpi-deploymentapi
PASS  rpi-queuereader

8 passed, 0 failed
```

The test automatically adapts to your configuration — only enabled services are checked. If any service fails, the test exits with a non-zero code.

### Demo Database Mode

> **Optional.** For development or evaluation only — not for production.

Set `global.deployment.mode: demo` to deploy embedded MSSQL Server and MongoDB containers inside the cluster. This eliminates the need to provision external databases when getting started:

```yaml
global:
  deployment:
    mode: demo
    platform: selfhosted

databases:
  operational:
    server_host: rpi-demo-mssql
    server_username: sa
    # Password is auto-generated and stored in secret "rpi-demo-mode"
    # Retrieve with: kubectl get secret rpi-demo-mode -n <namespace> -o jsonpath="{.data.DEMOMode_SQL_Password}" | base64 -d
    server_password: RETRIEVE_FROM_SECRET
```

The demo databases use `StatefulSet` with persistent volume claims (20 Gi for MSSQL, 10 Gi for MongoDB), so data survives pod restarts. The MSSQL `sa` password and MongoDB connection string are auto-generated and stored in the `rpi-demo-mode` Kubernetes Secret. However, they are single-replica with no backups or HA — use `mode: standard` (the default) with managed database services in production.

See `deploy/values/demo/demo.yaml` for a complete demo overrides example.

### Configure Content Generation Tools

RPI integrates with OpenAI and Azure Cognitive Search for [content generation](https://docs.redpointglobal.com/rpi/configuring-content-generation-tools):

```yaml
redpointAI:
  enabled: true
```

See `chart/values.yaml` for all `redpointAI` configuration keys.

### Configure Custom Metrics

RPI services expose a `/metrics` endpoint for Prometheus scraping. Ensure Prometheus is running in your cluster and targeting the RPI namespace.

```yaml
customMetrics:
  enabled: true
```

Per-component metrics can be enabled via the `advanced:` block — see [readme-values.md](docs/readme-values.md).

<details>
<summary><strong>Available Metrics</strong></summary>

**Execution Service**

| Metric | Description |
|--------|-------------|
| `execution_max_thread_count` | Configured max work items per execution service |
| `execution_total_executing_count` | Currently executing work items |
| `execution_client_jobs_executing_count` | Client jobs currently executing |
| `execution_tasks_executing_count` | System tasks currently executing |
| `execution_workflows_executing_count` | Workflow activities currently executing |
| `execution_client_jobs_completed_count` | Client jobs completed |
| `execution_tasks_completed_count` | System tasks completed |
| `execution_workflows_completed_count` | Workflow activities completed |
| `execution_workflows_suspended_count` | Workflow activities suspended |

**Node Manager**

| Metric | Description |
|--------|-------------|
| `node_manager_activities_allocated_count` | Workflow activities allocated |
| `node_manager_tasks_allocated_count` | System tasks allocated |
| `node_manager_triggers_fired_count` | Triggers fired |

**Queue Reader**

| Metric | Description |
|--------|-------------|
| `queue_listener_valid_queue_listener_messages` | Valid messages processed |
| `queue_listener_invalid_queue_listener_messages` | Invalid messages processed |

</details>

### Configure Autoscaling

#### Resource-Based (HPA)

Native Kubernetes HPA scaling on CPU and memory:

```yaml
realtimeapi:
  autoscaling:
    enabled: true
    type: hpa
    minReplicas: 1
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
    targetMemoryUtilizationPercentage: 80
```

#### Custom Metrics (KEDA + Prometheus)

Recommended for the **Execution Service**, which requires graceful shutdown during scale-in.

**How it works:**
1. Prometheus scrapes `execution_total_executing_count` and `execution_max_thread_count`
2. KEDA scales out/in based on the thread count threshold
3. A `preStop` hook calls `/api/operations/sleep` and waits for in-flight work to drain
4. `terminationGracePeriodSeconds` (recommended: 24h) ensures long-running tasks complete

**Prerequisites:** [Prometheus](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/kubernetes-monitoring/configuration/config-other-methods/prometheus/prometheus-operator/) and [KEDA](https://keda.sh/docs/2.17/deploy/) installed in your cluster.

```yaml
customMetrics:
  enabled: true
  prometheus_scrape: true

executionservice:
  autoscaling:
    enabled: true
    type: keda
    kedaScaledObject:
      serverAddress: <my-prometheus-query-endpoint>
      useTriggerAuthentication: true
      authenticationRef: rpi-executionservice
```

<details>
<summary>Generated ScaledObject example</summary>

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: rpi-executionservice
  namespace: redpoint-rpi
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rpi-executionservice
  fallback:
    failureThreshold: 3
    replicas: 2
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleUp:
          stabilizationWindowSeconds: 300
          policies:
            - type: Percent
              value: 100
              periodSeconds: 60
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
            - type: Percent
              value: 50
              periodSeconds: 60
  triggers:
    - type: prometheus
      metadata:
        serverAddress: "<my-prometheus-query-endpoint>"
        metricName: "execution_max_thread_count"
        query: "sum(execution_max_thread_count{kubernetes_namespace=\"<my-rpi-namespace>\", app=\"rpi-executionservice\"})"
        threshold: "80"
      authenticationRef:
        name: rpi-executionservice
  pollingInterval: 30
  minReplicaCount: 2
  maxReplicaCount: 10
```

</details>

> **Note:** `authenticationRef` references a KEDA `TriggerAuthentication` resource, only required if Prometheus enforces authentication. Set `useTriggerAuthentication: false` if not needed.

Verify the ScaledObject:

```bash
kubectl get ScaledObject
```

```
NAME                   SCALETARGETKIND      SCALETARGETNAME        MIN   MAX   READY
rpi-executionservice   apps/v1.Deployment   rpi-executionservice   2     10    True
```

---

## AI-Assisted Operations

RPI ships with built-in support for AI-assisted operations via [MCP (Model Context Protocol)](https://modelcontextprotocol.io) and a JSON Schema for IDE autocomplete.

- **`values.schema.json`** — Bundled with the chart. Provides IDE autocomplete in VS Code/IntelliJ, and Helm-native validation that catches invalid platform names, provider values, and missing dependencies before deployment. No setup required.
- **`@redpoint-rpi/helm-mcp`** — An MCP server published as an npm package that enables AI assistants like Claude to validate configurations, generate overrides files, render templates, explain values, and diagnose deployment issues.

See [readme-mcp.md](docs/readme-mcp.md) for setup instructions and available tools.

---

## Customizing This Helm Chart

The chart uses a **two-tier values system**: you maintain a small overrides file with only your customizations, and the chart manages all internal defaults. See [readme-values.md](docs/readme-values.md) for a full explanation.

### 1. Environment overrides (preferred)

Common settings — image references, credentials, replicas, resources, providers — are documented in `chart/values.yaml` and the examples in `deploy/values/`:

```bash
helm upgrade --install rpi ./chart -f my-overrides.yaml -n redpoint-rpi
```

### 2. The `advanced:` block

Every internal default (health probes, security contexts, logging levels, service ports, rollout strategies, thread pools, retry policies) can be overridden without forking the chart:

```yaml
advanced:
  # Global probe tuning
  livenessProbe:
    periodSeconds: 30
    failureThreshold: 5
  # Per-service logging
  realtimeapi:
    logging:
      realtimeapi:
        default: Debug
```

See `docs/values-reference.yaml` for every available key.

### Per-Service Pod Annotations & Labels

Every service supports `podAnnotations` and `podLabels` for applying metadata to individual deployments without affecting other services. These are added after the global `customAnnotations`/`customLabels`:

```yaml
executionservice:
  podAnnotations:
    config.linkerd.io/skip-outbound-ports: "443"
  podLabels:
    sidecar.istio.io/inject: "true"

interactionapi:
  podAnnotations:
    prometheus.io/scrape: "true"
```

Supported on: `realtimeapi`, `callbackapi`, `executionservice`, `interactionapi`, `integrationapi`, `deploymentapi`, `queuereader`, `nodemanager`, `rebrandly`.

## RPI Documentation

Visit the [RPI Documentation Site](https://docs.redpointglobal.com/rpi/) for in-depth guides and release notes.

## Getting Support

For RPI application issues, contact [support@redpointglobal.com](mailto:support@redpointglobal.com).

> **Scope of Support:** Redpoint supports RPI application issues. Kubernetes infrastructure, networking, and external system configuration fall outside our support scope — consult your IT infrastructure team or relevant technical forums for those.

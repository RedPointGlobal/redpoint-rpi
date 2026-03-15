![redpoint_logo](../chart/images/redpoint.png)
# Configuration Reference

[< Back to main README](../README.md)

After completing either the [Greenfield](greenfield.md) or [Migration](migration.md) guide, configure the optional features below. The Interaction CLI supports two workflows:

- **During initial setup:** the CLI offers each feature after generating your base config, so you can include everything in one pass.
- **After deployment:** add features to an existing overrides file at any time:

```bash
bash deploy/cli/interactioncli.sh -a <feature>    # add a specific feature
bash deploy/cli/interactioncli.sh -a menu          # interactive feature picker
```

Available features: `database_upgrade`, `queue_reader`, `autoscaling`, `custom_metrics`, `service_mesh`, `smoke_tests`, `entra_id`, `oidc`, `smtp`, `redpoint_ai`, `storage`, `secrets_management`, `node_scheduling`.

For the complete list of every key, see [values_reference.yaml](values_reference.yaml).

---

| Feature | Values Key | CLI Feature | Description |
|---------|-----------|-------------|-------------|
| [Cloud Identity](#cloud-identity) | `cloudIdentity` | *(base config)* | Azure Workload Identity, Google WI, Amazon IRSA |
| [Secrets Management](#secrets-management) | `secretsManagement` | `secrets_management` | Kubernetes Secrets, cloud vault SDK, CSI driver |
| [Storage](#storage) | `storage` | `storage` | PVCs and PV+PVC pairs for file output, plugins, RPDM |
| [Realtime API](#realtime-api) | `realtimeapi` | *(base config)* | Queue providers, cache providers, API auth, multi-tenancy |
| [Queue Reader](#queue-reader) | `queuereader` | `queue_reader` | Drains queue listener and realtime queues |
| [Database Upgrades](#automatic-database-upgrades) | `databaseUpgrade` | `database_upgrade` | Auto-upgrade operational databases on image tag change |
| [Autoscaling](#autoscaling) | `autoscaling` | `autoscaling` | HPA (CPU/memory) or KEDA (Prometheus custom metrics) |
| [Custom Metrics](#custom-metrics) | `customMetrics` | `custom_metrics` | Prometheus `/metrics` endpoint for all services |
| [Service Mesh](#service-mesh) | `serviceMesh` | `service_mesh` | Linkerd Server CRDs for L7 traffic policy |
| [Smoke Tests](#smoke-tests) | `smokeTests` | `smoke_tests` | Validate PVC mounts and CSI drivers before deploying |
| [Microsoft Entra ID](#microsoft-entra-id) | `MicrosoftEntraID` | `entra_id` | SSO via Azure AD |
| [OIDC](#open-id-connect) | `OpenIdProviders` | `oidc` | SSO via Keycloak or other OIDC providers |
| [Demo Mode](#demo-mode) | `global.deployment.mode` | *(base config)* | Embedded MSSQL + MongoDB for dev/eval |
| [Content Generation](#content-generation) | `redpointAI` | `redpoint_ai` | OpenAI and Azure Cognitive Search integration |
| [SMTP](#smtp) | `SMTPSettings` | `smtp` | Email delivery for notifications and workflows |
| [Node Scheduling](#node-scheduling) | `nodeSelector` / `tolerations` | `node_scheduling` | Schedule pods on dedicated node pools |

---

## Cloud Identity

Enables RPI to authenticate with cloud services using platform-native identity federation, removing the need for static credentials. The Interaction CLI configures this automatically based on your platform.

### Azure (Workload Identity)

Requires an AKS cluster with [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview) enabled and a User-Assigned Managed Identity with a federated credential bound to the RPI service account.

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: shared        # shared | per-service | both
    name: redpoint-rpi
  azure:
    managedIdentityClientId: <client-id>
    tenantId: <tenant-id>
```

### Amazon (IRSA)

Requires an EKS cluster with an [OIDC provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) and an IAM role with a trust policy for the RPI service account.

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: shared        # shared | per-service | both
    name: redpoint-rpi
  amazon:
    roleArn: arn:aws:iam::123456789012:role/rpi
    region: us-east-1
```

### Google (Workload Identity)

Requires a GKE cluster with [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) enabled and a GCP service account bound to the Kubernetes service account.

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: shared        # shared | per-service | both
    name: redpoint-rpi
  google:
    serviceAccountEmail: rpi-sa@my-project.iam.gserviceaccount.com
```

### Per-service ServiceAccount override

Any service can override its ServiceAccount by setting `serviceAccountName` in its config block. This is particularly useful in `both` mode, where every service gets its own per-service SA and the shared SA is also created but not used by default. To assign the shared SA to a specific service while the others keep their own:

```yaml
cloudIdentity:
  serviceAccount:
    mode: both
    name: redpoint-rpi

realtimeapi:
  serviceAccountName: redpoint-rpi      # use the shared SA
# all other services keep their per-service SAs (rpi-interactionapi, rpi-executionservice, etc.)
```

The resolution priority is: per-service `serviceAccountName` override first, then mode-based resolution. This works in any mode, not just `both`.

---

## Secrets Management

Controls how RPI reads sensitive values (database passwords, connection strings, API tokens). Three providers are available. Use the Interaction CLI to configure:

```bash
bash deploy/cli/interactioncli.sh -a secrets_management
```

### Kubernetes Secrets (default)

Secrets are stored in a Kubernetes Secret object that you create and manage outside the chart. The [Interaction CLI](greenfield.md#2-quick-start-with-the-interaction-cli) generates this Secret manifest for you (`secrets.yaml`) with all the required keys pre-populated.

```yaml
secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
```

The chart does not create the Secret. That is the administrator's responsibility. This keeps sensitive values out of Helm release metadata and version control. Apply the Secret before running `helm install` or `helm upgrade`.

### SDK (Cloud Vault)

Reads secrets directly from a cloud vault using the cloud SDK. Requires [Cloud Identity](#cloud-identity) to be configured.

```yaml
secretsManagement:
  provider: sdk
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
  sdk:
    azure:
      vaultUri: https://my-keyvault.vault.azure.net/
      configurationReloadIntervalSeconds: 30
      useADTokenForDatabaseConnection: true
```

To add Azure SDK settings to an existing `secretsManagement` block, run the CLI and choose `add_sdk_settings`.

### CSI (Volume-Mounted)

Mounts secrets from a cloud vault as files using the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/). The chart includes a template at `chart/templates/secret-providerclass.yaml` that generates `SecretProviderClass` resources from values.

```yaml
secretsManagement:
  provider: csi
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
  csi:
    secretProviderClasses:
      - name: redpoint-rpi-secrets
        provider: azure
        secretObjects:
          - secretName: rpi-synced-secrets
            type: Opaque
            data:
              - key: ConnectionString_Operations_Database
                objectName: V7-ConnectionString-Operations-Database
        parameters:
          keyvaultName: my-keyvault
          resourceGroup: my-resource-group
          subscriptionId: aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
          clientID: "11111111-2222-3333-4444-555555555555"
          tenantId: "66666666-7777-8888-9999-000000000000"
          usePodIdentity: "false"
          useVMManagedIdentity: "false"
          useWorkloadIdentity: "true"
          syncSecret: "true"
          enable-secret-rotation: "true"
        objects:
          - objectName: "V7-ConnectionString-Operations-Database"
            objectType: secret
```

### Managing CSI Classes with the CLI

The CLI supports incremental updates. You don't need to rebuild the entire block each time.

| CLI action | What it does |
|:-----------|:-------------|
| `add_csi_class` | Add a new `SecretProviderClass` entry to the list |
| `update_csi_class` | Add objects or secret data mappings to an existing class |
| `add_sdk_settings` | Add Azure SDK vault settings to an existing block |
| `change_provider` | Replace the entire `secretsManagement` block |

**Adding a new class:**

```bash
bash deploy/cli/interactioncli.sh -a secrets_management
# Choose: add_csi_class
# Follow prompts for name, provider, vault parameters, objects, and secret mappings
```

**Updating an existing class (adding vault objects):**

```bash
bash deploy/cli/interactioncli.sh -a secrets_management
# Choose: update_csi_class
# Select class name (auto-selected if only one exists)
# Choose: objects
# Enter object names and types to add
```

This appends new entries to the class's `objects:` list:

```yaml
        objects:
          - objectName: "V7-ConnectionString-Operations-Database"
            objectType: secret
          # ← new entries are inserted here
          - objectName: "V7-ConnectionString-LoggingDatabase"
            objectType: secret
          - objectName: "V7-SMTP-Password"
            objectType: secret
```

**Updating an existing class (adding secret data mappings):**

```bash
bash deploy/cli/interactioncli.sh -a secrets_management
# Choose: update_csi_class
# Select class name
# Choose: secret_data
# Enter key/objectName pairs to add
```

This appends new entries to the class's `secretObjects[].data:` list:

```yaml
        secretObjects:
          - secretName: rpi-synced-secrets
            type: Opaque
            data:
              - key: ConnectionString_Operations_Database
                objectName: V7-ConnectionString-Operations-Database
              # ← new entries are inserted here
              - key: ConnectionString_Logging_Database
                objectName: V7-ConnectionString-LoggingDatabase
              - key: SMTP_Password
                objectName: V7-SMTP-Password
```

Choose `both` to add vault objects and secret data mappings in one pass.

### Combining Providers

You can configure multiple providers in a single `secretsManagement` block. For example, using Kubernetes Secrets as the primary provider while also configuring SDK and CSI for specific use cases:

```yaml
secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
  sdk:
    azure:
      vaultUri: https://my-keyvault.vault.azure.net/
      configurationReloadIntervalSeconds: 30
      useADTokenForDatabaseConnection: true
  csi:
    secretProviderClasses:
      - name: redpoint-rpi-secrets
        provider: azure
        # ... (see CSI example above)
```

---

## Storage

PVCs for file output, plugins, and RPDM uploads. Each claim can be a standalone PVC (using an existing StorageClass) or a PV+PVC pair (for pre-provisioned volumes like Azure Files, AWS EFS, or GCP Filestore).

### PVC Only (StorageClass)

```yaml
storage:
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
      storageClassName: default
      accessModes:
        - ReadWriteMany
      storage: 10Gi
```

### PV + PVC (Pre-Provisioned)

For cloud file shares that require explicit PV configuration:

<details>
<summary><strong>Azure Files CSI</strong></summary>

```yaml
storage:
  persistentVolumes:
    FileOutputDirectory:
      enabled: true
      pvName: rpi-fileoutput-pv
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
      storage: 100Gi
      accessModes:
        - ReadWriteMany
      csi:
        driver: file.csi.azure.com
        volumeHandle: rpi-fileoutput-handle
        volumeAttributes:
          shareName: rpifileoutput
          resourceGroup: <resource-group>
          storageAccount: <storage-account>
```

</details>

<details>
<summary><strong>AWS EFS CSI</strong></summary>

```yaml
storage:
  persistentVolumes:
    FileOutputDirectory:
      enabled: true
      pvName: rpi-fileoutput-pv
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
      storage: 100Gi
      accessModes:
        - ReadWriteMany
      csi:
        driver: efs.csi.aws.com
        volumeHandle: fs-0123456789abcdef0
```

</details>

<details>
<summary><strong>GCP Filestore CSI</strong></summary>

```yaml
storage:
  persistentVolumes:
    FileOutputDirectory:
      enabled: true
      pvName: rpi-fileoutput-pv
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
      storage: 100Gi
      accessModes:
        - ReadWriteMany
      csi:
        driver: filestore.csi.storage.gke.io
        volumeHandle: "modeInstance/<zone>/<filestore-name>/<share-name>"
        volumeAttributes:
          ip: <filestore-ip>
          volume: <share-name>
```

</details>

### Available Volume Mounts

| Key | Default Mount Path | Purpose |
|-----|--------------------|---------|
| `FileOutputDirectory` | `/rpifileoutputdir` | Selection rule file exports |
| `RPDMUploadDirectory` | `/rpdmuploads` | RPDM file uploads |
| `PluginsDirectory` | `/plugins` | Custom channel plugins |

---

## Realtime API

[RPI Realtime](https://docs.redpointglobal.com/rpi/configuring-realtime-queue-providers) enables real-time decisioning via queue-based request/response.

### Queue Providers

| Provider | Key | Platforms |
|----------|-----|-----------|
| Azure Service Bus | `azureservicebus` | Azure |
| Azure Event Hubs | `azureeventhubs` | Azure |
| Amazon SQS | `amazonsqs` | AWS |
| Google Pub/Sub | `googlepubsub` | GCP |
| RabbitMQ | `rabbitmq` | Any |

### Cache Providers

| Provider | Key | Notes |
|----------|-----|-------|
| MongoDB | `mongodb` | Recommended for most deployments |
| Redis | `redis` | External Redis instance |
| Google Bigtable | `googlebigtable` | GCP only |
| In-Memory SQL | `inMemorySql` | SQL Server on VM only |

### Configuration

```yaml
realtimeapi:
  enabled: true
  cacheProvider:
    provider: mongodb
  queueProvider:
    provider: azureservicebus
    queueNames:
      RPIQueueInputName: "RPIQueue_Input"
      RPIQueueOutputName: "RPIQueue_Output"
      RPIQueueControlName: "RPIQueue_Control"
  authentication:
    type: basic               # basic | oauth
```

### OAuth Authentication

For production environments, OAuth provides token-based authentication instead of a static API key.

```yaml
realtimeapi:
  authentication:
    type: oauth
    oauth:
      audience: "rpi-realtime"
      authority: "https://login.microsoftonline.com/<tenant-id>/v2.0"
```

### Multi-Tenancy

When serving multiple RPI tenants from a single Realtime API deployment:

```yaml
realtimeapi:
  multitenancy:
    enabled: true
    tenants:
      - clientId: "<tenant-1-client-id>"
        cacheDatabaseNumber: 0
      - clientId: "<tenant-2-client-id>"
        cacheDatabaseNumber: 1
```

---

## Queue Reader

The [Queue Reader](https://docs.redpointglobal.com/rpi/admin-queue-reader-setup) drains Queue Listener and Realtime queues, processing async selection rules and realtime decisions.

```yaml
queuereader:
  enabled: true
  realtimeConfiguration:
    isDistributed: false
    tenantIds:
      - "<my-rpi-client-id>"
```

When `isDistributed: true`, the Queue Reader operates in distributed mode with seed services and partition handlers for horizontal scaling.

---

## Automatic Database Upgrades

Runs a Kubernetes Job on each `helm upgrade` that changes the image tag. The job calls the Deployment API to apply database schema migrations. ArgoCD-compatible via `PostSync` hook.

```yaml
databaseUpgrade:
  enabled: true
```

Additional options:

```yaml
databaseUpgrade:
  enabled: true
  sendEmailOnUpgradeStart: false
  sendEmailOnUpgradeComplete: false
  monitorUpgrade: false
```

---

## Autoscaling

Two modes: HPA (Horizontal Pod Autoscaler) for CPU/memory scaling, or KEDA for Prometheus-based custom metrics scaling.

### HPA

```yaml
realtimeapi:
  autoscaling:
    enabled: true
    type: hpa
    minReplicas: 1
    maxReplicas: 5
    targetCPUUtilizationPercentage: 80
```

### KEDA (Prometheus Metrics)

Requires [KEDA](https://keda.sh/) installed on the cluster and [Custom Metrics](#custom-metrics) enabled. Recommended for Execution Service and Realtime API where queue depth drives scaling.

```yaml
executionservice:
  autoscaling:
    enabled: true
    type: keda
    minReplicas: 1
    maxReplicas: 10
    keda:
      serverAddress: http://prometheus-server.monitoring.svc.cluster.local
      threshold: "5"
```

Autoscaling is available for: `realtimeapi`, `executionservice`, `interactionapi`, `integrationapi`.

---

## Custom Metrics

Exposes `/metrics` endpoints for Prometheus scraping on all RPI services. Provides operational visibility into request rates, queue depths, and processing times.

```yaml
customMetrics:
  enabled: true
```

When enabled, each service pod exposes a `/metrics` endpoint on its service port. Configure your Prometheus instance to scrape these endpoints, or use pod annotations for auto-discovery:

```yaml
interactionapi:
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
```

---

## Service Mesh

Generates [Linkerd](https://linkerd.io/) Server CRDs for L7 traffic policy. This allows fine-grained control over which services can communicate with each other.

```yaml
serviceMesh:
  enabled: true
  provider: linkerd
```

When enabled, the chart creates Server resources for each RPI service, defining the ports and protocols for Linkerd's policy engine.

---

## Node Scheduling

Controls which nodes RPI pods are placed on. Use this to schedule workloads on dedicated node pools (e.g., nodes labeled for RPI) and tolerate their taints.

```bash
bash deploy/cli/interactioncli.sh -a node_scheduling
```

### Node Selector

When enabled, all RPI pods are scheduled only on nodes with the specified label.

```yaml
nodeSelector:
  enabled: true
  key: app
  value: redpoint-rpi
```

### Tolerations

When enabled, RPI pods tolerate the matching taint so they can run on dedicated nodes that reject other workloads.

```yaml
tolerations:
  enabled: true
  effect: NoSchedule
  key: app
  operator: Equal
  value: redpoint-rpi
```

Both settings apply globally to all RPI services, including Smart Activation and supporting services (Redis, RabbitMQ). Smoke test deployments support per-entry `nodeSelector` overrides via `smokeTests.deployments[].nodeSelector`.

---

## Smoke Tests

Deploys minimal pods to validate PVC mounts and CSI drivers before running the full application. Useful for catching storage misconfigurations early.

```yaml
smokeTests:
  enabled: true
  deployments:
    - name: blob
      type: pvc
      claimName: rpifileoutputdir
      mountPath: /mnt/rpifileoutputdir
    - name: csi-secrets
      type: csi
      secretProviderClass: rpi-secret-provider
      mountPath: /mnt/secrets
```

Each smoke test pod mounts the specified volume and runs a basic read/write check. Use `kubectl logs` to inspect results.

---

## Microsoft Entra ID

SSO via Azure AD. Requires registering two applications in the Azure Portal:

1. **Interaction Client:** The SPA (single-page application) that users log into
2. **Interaction API:** The backend API that validates tokens

```yaml
MicrosoftEntraID:
  enabled: true
  interaction_client_id: <client-id>
  interaction_api_id: <api-id>
  tenant_id: <tenant-id>
```

See the [RPI documentation](https://docs.redpointglobal.com/rpi/) for Azure Portal registration steps.

---

## Open ID Connect

SSO via Keycloak or other [OIDC providers](https://docs.redpointglobal.com/rpi/admin-appendix-b-open-id-connect-oidc-configuratio). The chart can optionally deploy a Keycloak instance for development/testing.

```yaml
OpenIdProviders:
  enabled: true
  name: Keycloak
```

When using the embedded Keycloak (`cdp-keycloak`), the chart deploys a Keycloak instance pre-configured with the RPI realm and client.

---

## Demo Mode

Deploys embedded MSSQL and MongoDB containers for dev/eval. **Not for production.** No external database setup required.

```yaml
global:
  deployment:
    mode: demo
    platform: selfhosted
```

Demo mode:
- Deploys a SQL Server container with the operational databases pre-created
- Deploys a MongoDB container for Realtime cache
- Uses default storage classes for PVCs
- Suitable for evaluation, development, and CI/CD pipelines

See `deploy/values/demo/demo.yaml` for a complete example.

---

## Content Generation

Integrates with OpenAI and Azure Cognitive Search for AI-powered [content generation](https://docs.redpointglobal.com/rpi/configuring-content-generation-tools) within RPI workflows.

```yaml
redpointAI:
  enabled: true
```

API keys and endpoints are configured via Kubernetes Secrets. See the secret key reference in the [Greenfield guide](greenfield.md#2-quick-start-with-the-interaction-cli).

---

## SMTP

Email delivery for notifications and workflows. Configure your SMTP server details:

```yaml
SMTPSettings:
  UseCredentials: true
  SMTP_Server: smtp.example.com
  SMTP_Port: "587"
  SMTP_FromAddress: rpi@example.com
```

When `UseCredentials: true`, the SMTP password is read from the Kubernetes Secret key `SMTP_Password`.

---

## Overriding Internal Defaults

Every internal default (probes, security contexts, logging, ports, rollout strategies, thread pools) can be overridden directly under the matching top-level key without forking the chart.

```yaml
interactionapi:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
```

See [values_reference.yaml](values_reference.yaml) for every available key.

---

## Post-Deploy Validation

After install or upgrade, run `helm test` to verify all services are healthy:

```bash
helm test rpi -n redpoint-rpi
```

---

## Customizing This Helm Chart

The chart uses a **two-tier values system**: a small overrides file with your customizations, and internal defaults managed by the chart. See [readme-values.md](readme-values.md) for details on how the merge works.

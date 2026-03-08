![redpoint_logo](../chart/images/redpoint.png)
# Configuration Reference

[< Back to main README](../README.md)

After completing either the [Greenfield](greenfield.md) or [Migration](migration.md) guide, configure the optional features below. The Interaction CLI supports two workflows:

- **During initial setup** — the CLI offers each feature after generating your base config, so you can include everything in one pass.
- **After deployment** — add features to an existing overrides file at any time:

```bash
bash deploy/cli/interactioncli.sh -a <feature>    # add a specific feature
bash deploy/cli/interactioncli.sh -a menu          # interactive feature picker
```

Available features: `databaseUpgrade`, `queuereader`, `autoscaling`, `customMetrics`, `serviceMesh`, `smokeTests`, `entraID`, `oidc`, `smtp`, `redpointAI`, `storage`, `helmcopilot`, `advanced`.

For the complete list of every key, see [values-reference.yaml](values-reference.yaml).

---

| Feature | Key | Description |
|---------|-----|-------------|
| [Cloud Identity](#cloud-identity) | `cloudIdentity` | Azure Workload Identity, Google WI, Amazon IRSA |
| [Secrets Management](#secrets-management) | `secretsManagement` | Kubernetes Secrets, cloud vault SDK, CSI driver |
| [Storage](#storage) | `storage` | PVCs and PV+PVC pairs for file output, plugins, RPDM |
| [Realtime API](#realtime-api) | `realtimeapi` | Queue providers, cache providers, API auth, multi-tenancy |
| [Queue Reader](#queue-reader) | `queuereader` | Drains queue listener and realtime queues |
| [Database Upgrades](#automatic-database-upgrades) | `databaseUpgrade` | Auto-upgrade operational databases on image tag change |
| [Autoscaling](#autoscaling) | `autoscaling` | HPA (CPU/memory) or KEDA (Prometheus custom metrics) |
| [Custom Metrics](#custom-metrics) | `customMetrics` | Prometheus `/metrics` endpoint for all services |
| [Service Mesh](#service-mesh) | `serviceMesh` | Linkerd Server CRDs for L7 traffic policy |
| [Smoke Tests](#smoke-tests) | `smokeTests` | Validate PVC mounts and CSI drivers before deploying |
| [Microsoft Entra ID](#microsoft-entra-id) | `MicrosoftEntraID` | SSO via Azure AD |
| [OIDC](#open-id-connect) | `OpenIdProviders` | SSO via Keycloak or other OIDC providers |
| [Demo Mode](#demo-mode) | `global.deployment.mode` | Embedded MSSQL + MongoDB for dev/eval |
| [Content Generation](#content-generation) | `redpointAI` | OpenAI and Azure Cognitive Search integration |
| [SMTP](#smtp) | `SMTPSettings` | Email delivery for notifications and workflows |

---

## Cloud Identity

Enables RPI to authenticate with cloud services using platform-native identity federation — no static credentials required. The Interaction CLI configures this automatically based on your platform.

### Azure (Workload Identity)

Requires an AKS cluster with [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview) enabled and a User-Assigned Managed Identity with a federated credential bound to the RPI service account.

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
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
    create: true
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
    create: true
    name: redpoint-rpi
  google:
    serviceAccountEmail: rpi-sa@my-project.iam.gserviceaccount.com
```

---

## Secrets Management

Controls how RPI reads sensitive values (database passwords, connection strings, API tokens). Three modes are available.

### Kubernetes Secrets (default)

Secrets are stored in a Kubernetes Secret object that you create and manage outside the chart. The [Interaction CLI](greenfield.md#2-quick-start-with-the-interaction-cli) generates this Secret manifest for you (`secrets.yaml`) with all the required keys pre-populated.

```yaml
secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
```

The chart does not create the Secret — that is the administrator's responsibility. This keeps sensitive values out of Helm release metadata and version control. Apply the Secret before running `helm install` or `helm upgrade`.

### SDK (Cloud Vault)

Reads secrets directly from a cloud vault using the cloud SDK. Requires [Cloud Identity](#cloud-identity) to be configured.

```yaml
secretsManagement:
  provider: sdk
  sdk:
    azure:
      vaultUri: https://my-keyvault.vault.azure.net/
    # amazon:
    #   region: us-east-1
    #   secretName: rpi/secrets
    # google:
    #   projectId: my-project
```

### CSI (Volume-Mounted)

Mounts secrets from a cloud vault as files using the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/).

```yaml
secretsManagement:
  provider: csi
  csi:
    secretProviderClass: rpi-secret-provider
```

A `SecretProviderClass` resource must exist in the namespace. The chart includes a template at `chart/templates/secret-providerclass.yaml` that can generate one when configured in values.

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

Advanced options:

```yaml
databaseUpgrade:
  enabled: true
  advanced:
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
advanced:
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

1. **Interaction Client** — The SPA (single-page application) that users log into
2. **Interaction API** — The backend API that validates tokens

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

Deploys embedded MSSQL and MongoDB containers for dev/eval — **not for production**. No external database setup required.

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

## Advanced Overrides

Every internal default — probes, security contexts, logging, ports, rollout strategies, thread pools — can be overridden via the `advanced:` block without forking the chart.

```yaml
advanced:
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

See [values-reference.yaml](values-reference.yaml) for every available key.

---

## Post-Deploy Validation

After install or upgrade, run `helm test` to verify all services are healthy:

```bash
helm test rpi -n redpoint-rpi
```

---

## Customizing This Helm Chart

The chart uses a **two-tier values system**: a small overrides file with your customizations, and internal defaults managed by the chart. See [readme-values.md](readme-values.md) for details on how the merge works and how to use the `advanced:` block.

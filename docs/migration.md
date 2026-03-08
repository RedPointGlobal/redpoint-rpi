![redpoint_logo](../chart/images/logo.png)
# Upgrading from v7.6 to v7.7

[< Back to main README](../README.md)

This guide covers upgrading an existing RPI v7.6 Helm deployment to v7.7. If you're deploying RPI for the first time, see the [Greenfield Installation](greenfield.md) guide instead.

> **Not ready to upgrade?** The `release/v7.6` branch remains available on GitHub for critical fixes. You are not required to upgrade immediately. Stay on v7.6 as long as needed and migrate when it suits your schedule.

## What Changed in v7.7

> **v7.7 Breaking Change**

The `values.yaml` has been redesigned from a **3,000+ line monolithic file** to a **few line user-facing override** file. Internal defaults (health probes, security contexts, logging levels, service ports, rollout strategies, etc.) are now managed by the chart and no longer need to be carried in your overrides file. 

You now maintain a small overrides file instead of a full copy of `values.yaml`. See [readme-values.md](readme-values.md) for details.

| Before (v7.6) | After (v7.7) |
|:---|:---|
| Copy the full `values.yaml` and edit it | Maintain a small overrides file with only your customizations |
| 3,000+ lines to manage | 50-100 lines typical |
| Upgrades require diffing the entire file | Upgrades apply new defaults automatically |
| No escape hatch for hidden internals | `advanced:` block overrides any internal default |

**New in v7.7:**

- **Demo mode**: Set `global.deployment.mode: demo` to deploy embedded MSSQL + MongoDB for development without external databases
- **Service mesh support**: Generate Linkerd Server CRDs via `serviceMesh.servers[]`
- **Secrets Store CSI**: Create SecretProviderClass resources for Azure Key Vault
- **Static Persistent volumes**: Create static PV + PVC pairs for CSI-backed storage (Azure Blob and Azure Files)
- **Database upgrade Assistant**: Helm-native Job that runs schema migrations on each RPI image version upgrade
- **Interaction CLI**: Interactive script that generates your overrides file, secrets, and prerequisites in one step

See [readme-values.md](readme-values.md) for full details on the new architecture.

---

## Migration Steps

### 1. Get the v7.7 Chart

Clone the repository if you haven't already:

```bash
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi
```

If you already have a local clone, pull the latest:

```bash
cd redpoint-rpi
git fetch origin
git checkout main        # v7.7 is on main
git pull
```

**If you maintain an internal copy** (Azure Repos, GitLab, Bitbucket, etc.):

Most teams mirror the Redpoint GitHub repo into their own version control. To pull in the v7.7 chart, add the upstream GitHub repo as a remote, fetch the latest, and push to your internal repo:

```bash
cd redpoint-rpi

# Add the upstream Redpoint repo (one-time setup)
git remote add upstream https://github.com/RedPointGlobal/redpoint-rpi.git

# Fetch the latest from upstream
git fetch upstream

# Merge v7.7 into your main branch
git checkout main
git merge upstream/main

# Push to your internal repo
git push origin main
```


### 2. Generate Your v7.7 Overrides File

Run the [Interaction CLI](greenfield.md#2-quick-start-with-the-interaction-cli) and enter your existing resource coordinates — database host, credentials, platform, ingress domain, cache/queue providers, etc. The CLI generates a v7.7-compatible overrides file with the correct structure, so you don't need to manually diff or translate your v7.6 values:

```bash
bash deploy/cli/interactioncli.sh
```

The CLI produces three files:

| File | Purpose |
|:-----|:--------|
| `overrides.yaml` | Helm values overrides in v7.7 format |
| `secrets.yaml` | Kubernetes Secret manifest with all required keys |
| `prereqs.sh` | kubectl commands for namespace, image pull, TLS, and secrets |

> **Tip:** Have your v7.6 `values.yaml` open while running the CLI so you can copy values like database hostnames, connection strings, and ingress domains directly into the prompts.

If you have customizations beyond what the CLI covers (custom plugins, KEDA scaling, advanced overrides), add them to the generated `overrides.yaml` after. See the mapping tables below for key renames.

### 3. Key Mapping Reference

The sections below document every key that changed between v7.6 and v7.7. If you used the Interaction CLI, most of these are handled automatically. Review this section only if you have customizations the CLI doesn't cover, or if you prefer to build your overrides file manually.

<details>
<summary><strong>Common values to carry over</strong> (click to expand)</summary>

| Category | Keys |
|:---------|:-----|
| **Platform** | `global.deployment.platform`, `global.deployment.images.tag` |
| **Database** | `databases.operational.*` |
| **Data Warehouse** | `databases.datawarehouse.*` |
| **Cloud Identity** | `cloudIdentity.*` (see [step 3a](#3a-map-cloud-identity-changes) below) |
| **Secrets Management** | `secretsManagement.*` (see [step 3b](#3b-map-secrets-management-changes) below) |
| **Ingress** | `ingress.domain`, `ingress.hosts.*`, `ingress.tls` |
| **Realtime** | `realtimeapi.cacheProvider.*`, `realtimeapi.queueProvider.*` |
| **Replicas/Resources** | Per-service `replicas`, `resources`, `autoscaling` |
| **Authentication** | `MicrosoftEntraID.*`, `OpenIdProviders.*` |
| **SMTP** | `SMTPSettings.*` |
| **Pod Metadata** | Per-service `podAnnotations`, `podLabels` |
| **Service Mesh** | `serviceMesh.*` |

</details>

#### 3a. Map Cloud Identity Changes

The cloud identity structure has been simplified. The `provider` field is removed — it is now derived from `global.deployment.platform`. ServiceAccount configuration has moved under `cloudIdentity`.

**Azure:**

```yaml
# Before (v7.6):
cloudIdentity:
  enabled: true
  provider: Azure
  azureSettings:
    credentialsType: workloadIdentity
    managedIdentityClientId: my-client-id
global:
  deployment:
    serviceAccount:
      create: true
      name: redpoint-rpi

# After (v7.7):
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  azure:
    managedIdentityClientId: my-client-id
    tenantId: my-tenant-id
```

**Amazon:**

```yaml
# Before (v7.6):
cloudIdentity:
  enabled: true
  provider: Amazon
  amazonSettings:
    credentialsType: podIdentity
    region: us-east-1

# After (v7.7):
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  amazon:
    roleArn: arn:aws:iam::123456789012:role/my-irsa-role
    region: us-east-1
```

For static access keys (v7.6 `credentialsType: accessKey`):

```yaml
  amazon:
    useAccessKeys: true
    accessKeyId: my-access-key
    secretAccessKey: my-secret-key
    region: us-east-1
```

**Google:**

```yaml
# Before (v7.6):
cloudIdentity:
  enabled: true
  provider: Google
  googleSettings:
    credentialsType: serviceAccount
    configMapName: my-google-svs-account
    keyName: my-google-svs-account.json
    serviceAccountEmail: my-sa@project.iam.gserviceaccount.com
    projectId: my-project

# After (v7.7):
cloudIdentity:
  enabled: true
  serviceAccount:
    create: true
    name: redpoint-rpi
  google:
    serviceAccountEmail: my-sa@project.iam.gserviceaccount.com
    projectId: my-project
    configMapName: my-google-svs-account
    keyName: my-google-svs-account.json
    configMapFilePath: /app/google-creds
```

| v7.6 Key | v7.7 Key | Notes |
|:---------|:---------|:------|
| `cloudIdentity.provider` | *(removed)* | Derived from `global.deployment.platform` |
| `cloudIdentity.azureSettings.*` | `cloudIdentity.azure.*` | Flattened |
| `cloudIdentity.amazonSettings.*` | `cloudIdentity.amazon.*` | Flattened; `credentialsType` replaced by `useAccessKeys` boolean |
| `cloudIdentity.googleSettings.*` | `cloudIdentity.google.*` | Flattened |
| `global.deployment.serviceAccount.*` | `cloudIdentity.serviceAccount.*` | Moved |

#### 3b. Map Secrets Management Changes

Secrets management is now a top-level section (no longer nested under `cloudIdentity`). Provider names have changed and CSI is a first-class mode.

```yaml
# Before (v7.6):
cloudIdentity:
  secretsManagement:
    enabled: true
    secretsProvider: keyvault     # or kubernetes, awssecretsmanager
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets

# After (v7.7):
secretsManagement:
  provider: sdk                    # or kubernetes, csi
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
```

| v7.6 Provider | v7.7 Provider | Notes |
|:-------------|:-------------|:------|
| `kubernetes` | `kubernetes` | Unchanged |
| `keyvault` | `sdk` | Azure Key Vault settings move to `secretsManagement.sdk.azure.*` |
| `awssecretsmanager` | `sdk` | AWS SM settings move to `secretsManagement.sdk.amazon.*` |
| `googlesm` | `sdk` | Google SM settings move to `secretsManagement.sdk.google.*` |
| *(new)* | `csi` | CSI driver syncs vault secrets into K8s secrets |

**SDK vault URIs:**

```yaml
# Before (v7.6):
cloudIdentity:
  azureSettings:
    vaultUri: https://myvault.vault.azure.net/

# After (v7.7):
secretsManagement:
  provider: sdk
  sdk:
    azure:
      vaultUri: https://myvault.vault.azure.net/
      configurationReloadIntervalSeconds: 30
      useADTokenForDatabaseConnection: true
```

#### 3c. Map Image Configuration

v7.6 listed full image paths per service. v7.7 uses a shared `repository` prefix. Note that `imagePullPolicy` default changed from `IfNotPresent` to `Always`:

```yaml
# Before (v7.6):
global:
  deployment:
    images:
      interactionapi: rg1acrpub.azurecr.io/docker/redpointglobal/releases/rpi-interactionapi
      integrationapi: rg1acrpub.azurecr.io/docker/redpointglobal/releases/rpi-integrationapi
      # ... one per service
      tag: "7.6.20260212.1413"
      imagePullPolicy: IfNotPresent

# After (v7.7):
global:
  deployment:
    images:
      repository: rg1acrpub.azurecr.io/docker/redpointglobal/releases
      tag: "7.7.20260220.1524"
      imagePullPolicy: Always
      imagePullSecret:
        enabled: true
        name: redpoint-rpi
```

#### 3d. Map Per-Service Labels and Annotations

v7.6 used `customLabels` and `customAnnotations` per service. v7.7 renames these to `podLabels` and `podAnnotations`:

```yaml
# Before (v7.6):
realtimeapi:
  customLabels:
    environment: "prod"
  customAnnotations:
    my-annotation: "my-value"

# After (v7.7):
realtimeapi:
  podLabels:
    environment: "prod"
  podAnnotations:
    my-annotation: "my-value"
```

Global custom labels and annotations are still available at the top level as `customLabels` and `customAnnotations`.

#### 3e. Map ServiceAccount Configuration

Per-service `serviceAccount.enabled` fields are removed. ServiceAccount is now managed centrally:

```yaml
# Before (v7.6 — repeated in every service):
realtimeapi:
  serviceAccount:
    enabled: true

# After (v7.7 — set once):
cloudIdentity:
  serviceAccount:
    create: true
    name: redpoint-rpi
```

#### 3f. Map Ingress Changes

**TLS:** The `ingress.tlsSecretName` key has been replaced by an `ingress.tls` array:

```yaml
# Before (v7.6):
ingress:
  tlsSecretName: ingress-tls

# After (v7.7):
ingress:
  tls:
    - secretName: ingress-tls
```

For multi-certificate setups, add entries with explicit hosts lists:

```yaml
ingress:
  tls:
    - secretName: ingress-tls
      hosts:
        - client.example.com
        - config.example.com
    - secretName: certsecrets
      hosts:
        - mpulse.example.com
```

**className:** The default `ingress.className` now uses the release namespace (e.g., `redpoint-rpi`) instead of the hardcoded `nginx-redpoint-rpi` from v7.6. If your ingress controller expects the old class name, set it explicitly:

```yaml
ingress:
  className: nginx-redpoint-rpi   # override if your controller uses the old name
```

**FQDN hosts:** Host values containing a dot are now treated as FQDNs and used as-is (not prepended to `domain`). Values without dots continue to be treated as subdomains:

```yaml
ingress:
  domain: example.com
  hosts:
    client: rpi-interactionapi        # becomes rpi-interactionapi.example.com
    callbackapi: mpulse.example.com   # used as-is (FQDN)
```

#### 3g. Map Queue Reader Changes

Queue path keys have been simplified, and the distributed cache section has been renamed:

| v7.6 Key | v7.7 Key |
|:---------|:---------|
| `queuereader.listenerQueueErrorQueuePath` | `queuereader.errorQueuePath` |
| `queuereader.listenerQueueNonActiveQueuePath` | `queuereader.nonActiveQueuePath` |
| `queuereader.realtimeConfiguration.distributedCache` | `queuereader.realtimeConfiguration.internalCache` |
| `queuereader.threadPoolSize` | `advanced.queuereader.threadPoolSize` |
| `queuereader.timeoutMinutes` | `advanced.queuereader.timeoutMinutes` |
| `queuereader.maxBatchSize` | `advanced.queuereader.maxBatchSize` |
| `queuereader.useMessageLocks` | `advanced.queuereader.useMessageLocks` |
| `queuereader.isFormProcessingEnabled` | `advanced.queuereader.isFormProcessingEnabled` |
| `queuereader.isEventProcessingEnabled` | `advanced.queuereader.isEventProcessingEnabled` |
| `queuereader.isCacheProcessingEnabled` | `advanced.queuereader.isCacheProcessingEnabled` |
| `queuereader.queueListenerEnabled` | `advanced.queuereader.queueListenerEnabled` |
| `queuereader.isCallbackServiceProcessingEnabled` | `advanced.queuereader.isCallbackServiceProcessingEnabled` |

#### 3h. Map Execution Service Changes

The execution service internal cache now supports additional providers, and several job execution settings have moved to defaults:

```yaml
# Before (v7.6):
executionservice:
  internalCache:
    enabled: true
    type: internal        # internal | external
  jobExecution:
    maxThreadsPerExecutionService: 100
    auditTaskEvents: true
    # ... 10+ more fields
  seedService:
    memoryCacheSize: "10"

# After (v7.7):
executionservice:
  internalCache:
    enabled: true
    provider: filesystem  # NEW: default (Redis), filesystem, azureblob
    redisSettings:
      type: internal
```

| v7.6 Key | v7.7 Key |
|:---------|:---------|
| `executionservice.internalCache.type` | `executionservice.internalCache.redisSettings.type` |
| `executionservice.jobExecution.*` | `advanced.executionservice.jobExecution.*` |
| `executionservice.seedService.*` | `advanced.executionservice.seedService.*` |

#### 3i. Map Realtime API Changes

Several Realtime API sections have moved to chart defaults:

| v7.6 Key | v7.7 Key |
|:---------|:---------|
| `realtimeapi.dataMaps.*` | `advanced.realtimeapi.dataMaps.*` |
| `realtimeapi.idValidation.*` | `advanced.realtimeapi.idValidation.*` |
| `realtimeapi.customPlugins.*` | `advanced.realtimeapi.customPlugins.*` |
| `realtimeapi.CORSOrigins` | `advanced.realtimeapi.CORSOrigins` |
| `realtimeapi.ThresholdBetweenSiteVisitsMinutes` | `advanced.realtimeapi.ThresholdBetweenSiteVisitsMinutes` |
| `realtimeapi.enableHelpPages` | `advanced.realtimeapi.enableHelpPages` |
| `realtimeapi.enableEventListening` | `advanced.realtimeapi.enableEventListening` |
| `realtimeapi.decisionCacheDuration` | `advanced.realtimeapi.decisionCacheDuration` |

If you didn't customize these in v7.6, the chart defaults handle them automatically.

### 4. Move Hidden Defaults to `advanced:`

Many values that were top-level in v7.6 are now internal chart defaults in v7.7. If you customized any of these, move them under the `advanced:` block:

| v7.6 Location | v7.7 Location |
|:--------------|:--------------|
| `securityContext.*` | `advanced.securityContext.*` |
| `topologySpreadConstraints.*` | `advanced.topologySpreadConstraints.*` |
| `nodeSelector.*` | `advanced.nodeSelector.*` |
| `tolerations.*` | `advanced.tolerations.*` |
| `<service>.type` (deployment/rollout) | `advanced.<service>.type` |
| `<service>.rollout.*` | `advanced.<service>.rollout.*` |
| `<service>.livenessProbe.*` | `advanced.<service>.livenessProbe.*` |
| `<service>.readinessProbe.*` | `advanced.<service>.readinessProbe.*` |
| `<service>.startupProbe.*` | `advanced.<service>.startupProbe.*` |
| `<service>.logging.*` | `advanced.<service>.logging.*` |
| `<service>.service.port` | `advanced.<service>.service.port` |
| `<service>.terminationGracePeriodSeconds` | `advanced.<service>.terminationGracePeriodSeconds` |
| `<service>.resources.enabled` | *(removed — resources always applied)* |
| `<service>.podDisruptionBudget.*` | `advanced.<service>.podDisruptionBudget.*` |
| `<service>.customMetrics.*` | `advanced.<service>.customMetrics.*` |

Example:

```yaml
# Before (v7.6 values.yaml):
securityContext:
  runAsUser: 1000
  fsGroup: 1000

realtimeapi:
  logging:
    default: Debug

# After (v7.7 overrides file):
advanced:
  securityContext:
    runAsUser: 1000
    fsGroup: 1000
  realtimeapi:
    logging:
      default: Debug
```

> **Note:** If you kept the v7.6 defaults and didn't customize these values, you don't need to add them — the chart manages sensible defaults automatically.

Open [values-reference.yaml](values-reference.yaml) to see every available key under `advanced:`.

### 5. Validate with Helm Template

Before applying, render the manifests and compare against your current running state:

```bash
# Render with new overrides
helm template rpi ./chart -f my-overrides.yaml -n redpoint-rpi > rendered-v77.yaml

# Diff against what Helm currently has
helm get manifest rpi -n redpoint-rpi > current-manifest.yaml
diff current-manifest.yaml rendered-v77.yaml
```

Review the diff carefully. Expected differences:
- New labels/annotations added by the chart
- Default values that changed between v7.6 and v7.7 (probe timings, resource defaults, etc.)
- Template structure changes from the merge helper refactor
- `ingressClassName` changed from `nginx-redpoint-rpi` to release namespace

Unexpected differences to investigate:
- Missing environment variables or config maps
- Changed service ports or endpoints
- Missing volume mounts

### 6. Apply the Upgrade

**Staging first** — always upgrade a non-production environment before production:

```bash
# Staging
helm upgrade rpi ./chart \
  -f my-staging-overrides.yaml \
  -n rpi-staging

# Verify staging is healthy
kubectl get pods -n rpi-staging
kubectl get ingress -n rpi-staging
```

**Then production:**

```bash
helm upgrade rpi ./chart \
  -f my-overrides.yaml \
  -n redpoint-rpi
```

<details>
<summary><strong>ArgoCD / Flux users</strong> (click to expand)</summary>

If you use ArgoCD or Flux instead of `helm upgrade`, update the branch reference from `release/v7.6` to `main` (or a specific v7.7 tag) in your Application or GitRepository manifest. The `repoURL` should point to wherever you host the chart:

```yaml
# ArgoCD Application
source:
  repoURL: https://your-org.visualstudio.com/project/_git/redpoint-rpi
  targetRevision: main       # was: release/v7.6
  path: chart
```

```yaml
# Flux GitRepository
spec:
  url: https://your-org.visualstudio.com/project/_git/redpoint-rpi
  ref:
    branch: main             # was: release/v7.6
```

Commit your `overrides.yaml` to the repo and sync. See the [GitOps Guide](readme-argocd.md) for detailed ArgoCD configuration.

</details>

---

## Post-Upgrade Steps

### Trigger Database Upgrade

After the v7.7 containers are running, the operational databases must be upgraded.

**Option A: Automatic (recommended)**

Enable the automatic database upgrade Job in your overrides file. The chart creates a Kubernetes Job that waits for `rpi-deploymentapi` to become ready, then calls the upgrade endpoint automatically:

```yaml
databaseUpgrade:
  enabled: true
```

Monitor progress:

```bash
kubectl get jobs -n redpoint-rpi -l app.kubernetes.io/component=upgrade
kubectl logs -n redpoint-rpi -l app.kubernetes.io/component=upgrade --tail=50
```

See [Database Upgrades](readme-configuration.md#automatic-database-upgrades) for advanced options.

**Option B: Manual**

Call the upgrade endpoint directly:

```bash
DEPLOYMENT_SERVICE_URL=<prefix>-deploymentapi.<domain>

curl -X 'GET' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/upgrade?waitTimeoutSeconds=360" \
  -H 'accept: text/plain'
```

Wait for `"Status": "LastRunComplete"` and `Upgrade Complete` in the response.

<details>
<summary>Example response</summary>

```json
{
  "DeploymentInstanceID": "default",
  "Status": "LastRunComplete",
  "PulseDatabaseName": "Pulse",
  "Messages": [
    "[2024-10-09 17:22:49] Upgrade starting",
    "[2024-10-09 17:22:49] Operational Database Type: AmazonRDSSQL",
    "[2024-10-09 17:22:49] Pulse Database Name: Pulse",
    "[2024-10-09 17:22:49] Logging Database Name: Pulse_Logging",
    "[2024-10-09 17:22:49] Database Host: rpiopsmssqlserver",
    "[2024-10-09 17:22:49] Version before upgrade 6.7.24250",
    "[2024-10-09 17:22:49] Upgrading to version 7.4.24278.1712",
    "[2024-10-09 17:22:49] Upgrading the database",
    "[2024-10-09 17:23:35] Updating database version",
    "[2024-10-09 17:23:35] Adding 'what is new'",
    "[2024-10-09 17:23:35] Loading Plugins",
    "[2024-10-09 17:24:19] Upgrade Complete"
  ]
}
```

</details>

### Update System Configuration

Review and update tenant-level settings via the **Configuration** tab in the RPI client:

| Setting | Description |
|:--------|:------------|
| `Environment > FileExportLocation` | Export destination: 0 = File Output Directory, 1 = Default FTP, 2 = External Content Provider |
| `Environment > FileOutputDirectory` | Mount path for FileOutputDirectory volume (default: `/fileoutputdir`) |
| `Environment > DataManagementUploadDirectory` | Mount path for RPDM upload volume (default: `/rpdmuploaddirectory`) |
| `Channels > Channel name` | Update channel configuration to match your v7.7 requirements |

---

## Rollback

If you need to revert to v7.6:

**Helm rollback:**

```bash
helm rollback rpi -n redpoint-rpi
```

**Or switch back to the v7.6 branch:**

```bash
git checkout release/v7.6
helm upgrade rpi ./chart -f my-old-values.yaml -n redpoint-rpi
```

**ArgoCD:** Set `targetRevision` back to `release/v7.6` and sync.

> **Note:** Database schema changes made by the upgrade API are **not** automatically rolled back. Consult Redpoint Support if you need to revert database changes.

---

## Troubleshooting

### Out of sync after upgrade (ArgoCD)

Expected. The new defaults in `_defaults.tpl` change rendered manifests even if your overrides haven't changed. Review the diff, verify it matches expectations, then sync.

### Missing values after upgrade

If services fail to start, check that all your v7.6 customizations have been transferred to the new overrides file. Common misses:

- Logging levels (now under `advanced.<service>.logging`)
- Security contexts (now under `advanced.securityContext` or `advanced.<service>.securityContext`)
- Service ports (now in chart defaults, override via `advanced.<service>.service.port`)
- Per-service `customLabels`/`customAnnotations` (renamed to `podLabels`/`podAnnotations`)
- Per-service `customMetrics` (moved to `advanced.<service>.customMetrics`)
- Queue reader processing flags (moved to `advanced.queuereader.*`)
- Queue reader `distributedCache` (renamed to `internalCache`)
- Execution service `jobExecution` and `seedService` (moved to `advanced.executionservice.*`)
- Realtime `dataMaps`, `idValidation`, `customPlugins` (moved to `advanced.realtimeapi.*`)
- `ingress.className` (default changed from `nginx-redpoint-rpi` to release namespace)
- `imagePullPolicy` (default changed from `IfNotPresent` to `Always`)

### Helm template shows unexpected changes

Run `helm template` with `--debug` to see the full merge output:

```bash
helm template rpi ./chart -f my-overrides.yaml --debug 2>&1 | head -100
```

---

## Quick Reference: Key Renames

| v7.6 | v7.7 | Change Type |
|:-----|:-----|:------------|
| **Global** | | |
| `global.deployment.images.<service>` | `global.deployment.images.repository` | Consolidated |
| `global.deployment.serviceAccount.*` | `cloudIdentity.serviceAccount.*` | Moved |
| `imagePullPolicy: IfNotPresent` | `imagePullPolicy: Always` | Default changed |
| **Cloud Identity** | | |
| `cloudIdentity.provider` | *(removed)* | Derived from platform |
| `cloudIdentity.azureSettings.*` | `cloudIdentity.azure.*` | Renamed |
| `cloudIdentity.amazonSettings.*` | `cloudIdentity.amazon.*` | Renamed |
| `cloudIdentity.googleSettings.*` | `cloudIdentity.google.*` | Renamed |
| `cloudIdentity.secretsManagement.*` | `secretsManagement.*` | Moved to top-level |
| **Per-Service** | | |
| `<service>.serviceAccount.enabled` | `cloudIdentity.serviceAccount.create` | Centralized |
| `<service>.customLabels` | `<service>.podLabels` | Renamed |
| `<service>.customAnnotations` | `<service>.podAnnotations` | Renamed |
| `<service>.resources.enabled` | *(removed)* | Always applied |
| `<service>.type` / `<service>.rollout.*` | `advanced.<service>.type` | Moved to defaults |
| `<service>.customMetrics.*` | `advanced.<service>.customMetrics.*` | Moved to defaults |
| `<service>.logging.*` | `advanced.<service>.logging.*` | Moved to defaults |
| `<service>.livenessProbe.*` | `advanced.<service>.livenessProbe.*` | Moved to defaults |
| `<service>.readinessProbe.*` | `advanced.<service>.readinessProbe.*` | Moved to defaults |
| `<service>.startupProbe.*` | `advanced.<service>.startupProbe.*` | Moved to defaults |
| **Ingress** | | |
| `ingress.tlsSecretName` | `ingress.tls[].secretName` | Array format |
| `ingress.className: nginx-redpoint-rpi` | `ingress.className` (defaults to namespace) | Default changed |
| **Queue Reader** | | |
| `queuereader.listenerQueueErrorQueuePath` | `queuereader.errorQueuePath` | Shortened |
| `queuereader.listenerQueueNonActiveQueuePath` | `queuereader.nonActiveQueuePath` | Shortened |
| `queuereader.realtimeConfiguration.distributedCache` | `queuereader.realtimeConfiguration.internalCache` | Renamed |
| `queuereader.threadPoolSize` / `maxBatchSize` / etc. | `advanced.queuereader.*` | Moved to defaults |
| **Execution Service** | | |
| `executionservice.internalCache.type` | `executionservice.internalCache.redisSettings.type` | Restructured |
| `executionservice.jobExecution.*` | `advanced.executionservice.jobExecution.*` | Moved to defaults |
| `executionservice.seedService.*` | `advanced.executionservice.seedService.*` | Moved to defaults |
| **Realtime API** | | |
| `realtimeapi.dataMaps.*` | `advanced.realtimeapi.dataMaps.*` | Moved to defaults |
| `realtimeapi.idValidation.*` | `advanced.realtimeapi.idValidation.*` | Moved to defaults |
| `realtimeapi.customPlugins.*` | `advanced.realtimeapi.customPlugins.*` | Moved to defaults |
| **Security & Scheduling** | | |
| `securityContext.*` | `advanced.securityContext.*` | Moved to defaults |
| `topologySpreadConstraints.*` | `advanced.topologySpreadConstraints.*` | Moved to defaults |
| `nodeSelector.*` | `advanced.nodeSelector.*` | Moved to defaults |
| `tolerations.*` | `advanced.tolerations.*` | Moved to defaults |

---

## Next Steps

After migration, review the optional configuration sections in the [Configuration Reference](readme-configuration.md):

- [Cloud Identity](readme-configuration.md#cloud-identity)
- [Secrets Management](readme-configuration.md#secrets-management)
- [Storage](readme-configuration.md#storage)
- [Service Mesh](readme-configuration.md#service-mesh)
- [Autoscaling](readme-configuration.md#autoscaling)
- [Advanced Overrides](readme-configuration.md#advanced-overrides)

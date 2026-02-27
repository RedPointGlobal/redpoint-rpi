# Upgrading from v7.6 to v7.7

[< Back to main README](../README.md)

This guide covers upgrading an existing RPI v7.6 Helm deployment to v7.7. If you're deploying RPI for the first time, see the [Greenfield Installation](greenfield.md) guide instead.

---

## What Changed in v7.7

The `values.yaml` has been redesigned from a **2,608-line monolithic file** to a **764-line user-facing configuration** file. Internal defaults (health probes, security contexts, logging levels, service ports, rollout strategies, etc.) are now managed by the chart and no longer need to be carried in your overrides file.

| Before (v7.6) | After (v7.7) |
|---------------|-------------|
| Copy the full `values.yaml` and edit it | Maintain a small overrides file with only your customizations |
| 2,608 lines to manage | 50-100 lines typical |
| Upgrades require diffing the entire file | Upgrades apply new defaults automatically |
| No escape hatch for hidden internals | `advanced:` block overrides any internal default |

**New in v7.7:**

- **Demo database mode** — Set `global.deployment.mode: demo` to deploy embedded MSSQL + MongoDB for development without external databases
- **Service mesh support** — Generate Linkerd Server CRDs via `serviceMesh.servers[]`
- **CSI SecretProviderClass** — Create SecretProviderClass resources for Azure Key Vault, AWS Secrets Manager, and other CSI secret providers
- **Persistent volume creation** — Create PV + PVC pairs for CSI-backed storage (Azure Blob, Azure Files, AWS EFS, GCP Filestore)
- **Per-service pod annotations/labels** — Apply `podAnnotations` and `podLabels` to individual services without affecting others

See [readme-values.md](../readme-values.md) for full details on the new architecture.

---

## Migration Steps

### 1. Update the Chart Source

**Git (direct clone):**

```bash
# If you cloned with a specific branch
cd redpoint-rpi
git fetch origin
git checkout main        # v7.7 is on main
git pull
```

**ArgoCD:**

Update `targetRevision` from `release/v7.6` to `main` (or a specific v7.7 tag):

```yaml
source:
  repoURL: https://github.com/RedPointGlobal/redpoint-rpi.git
  targetRevision: main       # was: release/v7.6
  path: chart
```

**Flux:**

Update `ref.branch` to `main`:

```yaml
spec:
  ref:
    branch: main             # was: release/v7.6
```

> **Tip:** The `release/v7.6` branch remains available for critical fixes. You can stay on it as long as needed.

### 2. Identify Your Customizations

Diff your current `values.yaml` against the v7.6 chart's original to find what you actually changed:

```bash
# If you still have the original v7.6 values.yaml
diff deployments/my-current-values.yaml chart/values.yaml.orig
```

Or compare against the v7.6 branch:

```bash
git diff release/v7.6:values.yaml -- my-current-values.yaml
```

Focus on the values that differ — these are the only values you need to carry forward.

### 3. Create Your New Overrides File

Start from one of the provided examples:

```bash
# Pick the closest match to your environment
cp deployments/production.yaml my-overrides.yaml
```

Transfer your customizations into this file. Common values to carry over:

| Category | Keys |
|----------|------|
| **Platform** | `global.deployment.platform`, `global.deployment.images.tag` |
| **Database** | `databases.operational.*` |
| **Data Warehouse** | `databases.datawarehouse.*` |
| **Cloud Identity** | `cloudIdentity.*` |
| **Ingress** | `ingress.domain`, `ingress.hosts.*` |
| **Realtime** | `realtimeapi.cacheProvider.*`, `realtimeapi.queueProvider.*` |
| **Replicas/Resources** | Per-service `replicas`, `resources`, `autoscaling` |
| **Authentication** | `MicrosoftEntraID.*`, `OpenIdProviders.*` |
| **SMTP** | `SMTPSettings.*` |
| **Pod Metadata** | Per-service `podAnnotations`, `podLabels` |
| **Service Mesh** | `serviceMesh.*` |

### 4. Move Hidden Defaults to `advanced:`

If you customized values that are no longer top-level in v7.7 (health probes, security contexts, logging levels, service ports), place them under the `advanced:` block:

```yaml
# Before (v7.6 values.yaml):
livenessProbe:
  periodSeconds: 30
  failureThreshold: 5

securityContext:
  runAsUser: 1000
  fsGroup: 1000

# After (v7.7 overrides file):
advanced:
  livenessProbe:
    periodSeconds: 30
    failureThreshold: 5
  securityContext:
    runAsUser: 1000
    fsGroup: 1000
```

Per-component overrides go under `advanced.<component>`:

```yaml
# Before (v7.6):
realtimeapi:
  logging:
    realtimeapi:
      default: Debug

# After (v7.7):
advanced:
  realtimeapi:
    logging:
      realtimeapi:
        default: Debug
```

Open `deployments/values-reference.yaml` to see every available key under `advanced:`.

### 5. Validate with Helm Template

Before applying, render the manifests and compare against your current running state:

```bash
# Render with new overrides
helm template rpi ./chart -f my-overrides.yaml -n redpoint-rpi > rendered-v77.yaml

# Compare against current deployment
kubectl get all -n redpoint-rpi -o yaml > current-state.yaml

# Or diff against what Helm currently has
helm get manifest rpi -n redpoint-rpi > current-manifest.yaml
diff current-manifest.yaml rendered-v77.yaml
```

Review the diff carefully. Expected differences:
- New labels/annotations added by the chart
- Default values that changed between v7.6 and v7.7 (probe timings, resource defaults, etc.)
- Template structure changes from the merge helper refactor

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

---

## Post-Upgrade Steps

### Trigger Database Upgrade

After the v7 containers are running, trigger the database upgrade:

```bash
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com

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

### Activate RPI License

```bash
ACTIVATION_KEY="your_license_activation_key"
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
SYSTEM_NAME="my_dev_rpi_system"

curl -X 'POST' \
  "https://$DEPLOYMENT_SERVICE_URL/api/licensing/activatelicense" \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "ActivationKey": "'"${ACTIVATION_KEY}"'",
  "SystemName": "'"${SYSTEM_NAME}"'"
}'
```

### Update System Configuration

Review and update tenant-level settings via the **Configuration** tab in the RPI client:

| Setting | Description |
|---------|-------------|
| `Environment > FileExportLocation` | Export destination: 0 = File Output Directory, 1 = Default FTP, 2 = External Content Provider |
| `Environment > FileOutputDirectory` | Mount path for FileOutputDirectory volume (default: `/fileoutputdir`) |
| `Environment > DataManagementUploadDirectory` | Mount path for RPDM upload volume (default: `/rpdmuploaddirectory`) |
| `Channels > Channel name` | Update channel configuration to match your v7 requirements |

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

- Logging levels (now under `advanced:<component>.logging`)
- Security contexts (now under `advanced:securityContext` or `advanced:<component>.securityContext`)
- Service ports (now in chart defaults, override via `advanced:<component>.service.port`)

### Helm template shows unexpected changes

Run `helm template` with `--debug` to see the full merge output:

```bash
helm template rpi ./chart -f my-overrides.yaml --debug 2>&1 | head -100
```

---

## Next Steps

After migration, review the optional configuration sections in the [main README](../README.md):

- [Cloud Identity](../README.md#configure-cloud-identity)
- [Secrets Management](../README.md#configure-secrets-management)
- [Service Mesh](../README.md#configure-service-mesh)
- [Autoscaling](../README.md#configure-autoscaling)
- [Customizing This Helm Chart](../README.md#customizing-this-helm-chart)

![redpoint_logo](../chart/images/redpoint.png)
# Upgrading from v7.6 to v7.7

[< Back to main README](../README.md)

This guide covers upgrading an existing RPI v7.6 Helm deployment to v7.7. If you're deploying RPI for the first time, see the [Greenfield Installation](greenfield.md) guide instead.

> **Not ready to upgrade?** The `release/v7.6` branch remains available on GitHub for critical fixes. You are not required to upgrade immediately — stay on v7.6 as long as needed.

---

## What Changed in v7.7

The `values.yaml` has been redesigned from a **3,000+ line monolithic file** to a **small user-facing override** file. Internal defaults (health probes, security contexts, logging, ports, rollout strategies, etc.) are now managed by the chart automatically.

| Before (v7.6) | After (v7.7) |
|:---|:---|
| Copy the full `values.yaml` and edit it | Maintain a small overrides file with only your customizations |
| 3,000+ lines to manage | 50–100 lines typical |
| Upgrades require diffing the entire file | Upgrades apply new defaults automatically |
| No escape hatch for hidden internals | Any internal default can be overridden directly under its top-level key |

---

## Migration Steps

### 1. Get the v7.7 Chart

```bash
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi
```

If you already have a local clone:

```bash
git fetch origin && git checkout main && git pull
```

<details>
<summary><strong>Internal repo</strong> (Azure Repos, GitLab, Bitbucket)</summary>

```bash
# Add the upstream Redpoint repo (one-time setup)
git remote add upstream https://github.com/RedPointGlobal/redpoint-rpi.git

# Fetch and merge v7.7
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

</details>

### 2. Generate Your v7.7 Overrides

You have two options: use the **Interaction Copilot** for automatic migration, or use the **Interaction CLI** to build a new overrides file interactively.

**Option A — Automatic migration with Interaction Copilot (recommended)**

If you have the [Interaction Copilot](readme-mcp.md) connected, ask it to migrate your v7.6 values file:

> "Migrate my v7.6 values file at /path/to/my-values.yaml to v7.7"

The Copilot analyzes your file, identifies customizations vs defaults, remaps renamed keys, and produces a minimal v7.7 overrides file. It warns about breaking changes like `secretsManagement` relocation and `ingress.className` default changes.

**Option B — Interactive CLI**

Run the Interaction CLI with your existing v7.6 values at hand (database host, credentials, ingress domain, cache/queue providers). The CLI generates a v7.7-compatible overrides file — no manual diffing or key translation required:

```bash
bash deploy/cli/interactioncli.sh
```

The CLI produces three files:

| File | Purpose |
|:-----|:--------|
| `overrides.yaml` | Helm values overrides in v7.7 format |
| `secrets.yaml` | Kubernetes Secret manifest with all required keys |
| `prereqs.sh` | kubectl commands for namespace, image pull, TLS, and secrets |

> **Tip:** Have your v7.6 `values.yaml` open so you can copy values directly into the CLI prompts.

For optional features (SMTP, content generation, autoscaling, service mesh, etc.), add them after:

```bash
bash deploy/cli/interactioncli.sh -a menu           # interactive feature picker
bash deploy/cli/interactioncli.sh -a redpointAI     # add a specific feature
```

### 3. Upgrade

Apply prerequisites (if secrets or namespace changed), then upgrade:

```bash
bash prereqs.sh
helm upgrade rpi ./chart -f overrides.yaml -n redpoint-rpi
```

Verify:

```bash
helm test rpi -n redpoint-rpi
kubectl get pods -n redpoint-rpi
```

<details>
<summary><strong>ArgoCD / Flux users</strong></summary>

Update the branch reference from `release/v7.6` to `main` in your Application or GitRepository manifest:

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

Commit your `overrides.yaml` to the repo and sync. See the [GitOps Guide](readme-argocd.md) for details.

</details>

---

## Post-Upgrade: Database Schema Migration

After the v7.7 containers are running, the operational databases need a schema upgrade.

**Option A — Automatic (recommended):**

```bash
bash deploy/cli/interactioncli.sh -a databaseUpgrade
helm upgrade rpi ./chart -f overrides.yaml -n redpoint-rpi
```

The chart creates a Job that waits for the Deployment API to become ready, then runs the upgrade automatically.

**Option B — Manual:**

```bash
DEPLOYMENT_SERVICE_URL=<prefix>-deploymentapi.<domain>

curl -X 'GET' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/upgrade?waitTimeoutSeconds=360" \
  -H 'accept: text/plain'
```

Wait for `"Status": "LastRunComplete"` in the response.

---

## Rollback

```bash
helm rollback rpi -n redpoint-rpi
```

Or switch back to the v7.6 branch:

```bash
git checkout release/v7.6
helm upgrade rpi ./chart -f my-old-values.yaml -n redpoint-rpi
```

> **Note:** Database schema changes are **not** automatically rolled back. Contact [Redpoint Support](mailto:support@redpointglobal.com) if you need to revert database changes.

---

## Template Customizations

If you added custom template files to your v7.6 `chart/templates/` directory (e.g., CronJobs, NetworkPolicies, custom ConfigMaps) or modified any of the stock templates (e.g., added sidecars, init containers, extra env vars), these changes need to be carried forward manually.

**With Interaction Copilot:**

> "Analyze my v7.6 templates at /path/to/chart/templates for migration to v7.7"

The Copilot compares your templates against the stock v7.6 versions, identifies every custom file and every modification, and provides specific guidance for each — including diffs and advice on which changes can now be expressed as values instead of template edits.

**Without the Copilot:**

1. Copy custom template files (files not in the stock v7.6 chart) to the v7.7 `chart/templates/` directory. Review for compatibility with v7.7 values paths.
2. For modified stock templates, diff your version against the [stock v7.6 templates](https://github.com/RedPointGlobal/redpoint-rpi/tree/release/v7.6/redpoint-rpi/templates) and apply your changes to the v7.7 versions.
3. Many v7.6 template-level customizations (probes, resources, labels, annotations, security context) can now be set directly through values — check values first before editing templates.

---

## Troubleshooting

If services fail to start after upgrade, the most common cause is a v7.6 customization that wasn't carried over. Re-run the CLI to regenerate your overrides, or check the reference below.

If you customized probes, logging levels, security contexts, or other internal settings in v7.6, these are now set directly under the matching top-level key in your overrides file. See [values-reference.yaml](values-reference.yaml) for every available key.

<details>
<summary><strong>Key renames reference</strong> (for manual overrides)</summary>

If you prefer to build your overrides manually instead of using the CLI, here are all the key changes between v7.6 and v7.7:

| v7.6 | v7.7 | Change |
|:-----|:-----|:-------|
| `global.deployment.images.<service>` | `global.deployment.images.repository` | Consolidated |
| `global.deployment.serviceAccount.*` | `cloudIdentity.serviceAccount.*` | Moved |
| `imagePullPolicy: IfNotPresent` | `imagePullPolicy: Always` | Default changed |
| `cloudIdentity.provider` | *(removed)* | Derived from platform |
| `cloudIdentity.azureSettings.*` | `cloudIdentity.azure.*` | Renamed |
| `cloudIdentity.amazonSettings.*` | `cloudIdentity.amazon.*` | Renamed |
| `cloudIdentity.googleSettings.*` | `cloudIdentity.google.*` | Renamed |
| `cloudIdentity.secretsManagement.*` | `secretsManagement.*` | Moved to top-level |
| `ingress.tlsSecretName` | `ingress.tls[].secretName` | Array format |
| `ingress.className` default | Defaults to release namespace | Was `nginx-redpoint-rpi` |
| `<service>.customLabels` | `<service>.podLabels` | Renamed |
| `<service>.customAnnotations` | `<service>.podAnnotations` | Renamed |
| `<service>.serviceAccount.enabled` | `cloudIdentity.serviceAccount.mode` | Centralized (shared/per-service/both) |
| `<service>.resources.enabled` | *(removed)* | Always applied |
| `queuereader.listenerQueueErrorQueuePath` | `queuereader.errorQueuePath` | Shortened |
| `queuereader.listenerQueueNonActiveQueuePath` | `queuereader.nonActiveQueuePath` | Shortened |
| `queuereader.realtimeConfiguration.distributedCache` | `queuereader.realtimeConfiguration.internalCache` | Renamed |
| `executionservice.internalCache.type` | `executionservice.internalCache.redisSettings.type` | Restructured |

**Now set directly under the top-level key** (only needed if you customized these in v7.6):

| v7.6 | v7.7 |
|:-----|:-----|
| `securityContext.*` | `securityContext.*` |
| `topologySpreadConstraints.*` | `topologySpreadConstraints.*` |
| `<service>.logging.*` | `<service>.logging.*` |
| `<service>.livenessProbe.*` | `livenessProbe.*` (shared) or `<service>.livenessProbe.*` |
| `<service>.readinessProbe.*` | `readinessProbe.*` (shared) or `<service>.readinessProbe.*` |
| `<service>.type` / `.rollout.*` | `<service>.type` / `<service>.rollout.*` |
| `<service>.customMetrics.*` | `<service>.customMetrics.*` |
| `<service>.terminationGracePeriodSeconds` | `<service>.terminationGracePeriodSeconds` |
| `queuereader.threadPoolSize` / `.maxBatchSize` / etc. | `queuereader.threadPoolSize` / `queuereader.maxBatchSize` / etc. |
| `executionservice.jobExecution.*` | `executionservice.jobExecution.*` |
| `realtimeapi.dataMaps.*` / `.idValidation.*` / `.customPlugins.*` | `realtimeapi.dataMaps.*` / `realtimeapi.idValidation.*` / etc. |

</details>

---

## Next Steps

See the [Configuration Reference](readme-configuration.md) for optional features, or use `bash deploy/cli/interactioncli.sh -a menu` to add them interactively.

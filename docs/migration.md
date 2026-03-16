![redpoint_logo](../chart/images/redpoint.png)
# Upgrading from v7.6 to v7.7

[< Back to main README](../README.md)

This guide covers upgrading an existing RPI v7.6 Helm deployment to v7.7. If you're deploying RPI for the first time, see the [Greenfield Installation](greenfield.md) guide instead.

> **Not ready to upgrade?** The `release/v7.6` branch remains available on GitHub for critical fixes. You can stay on v7.6 as long as needed.

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

## v7.6 Pain Points Addressed in v7.7

### Custom container images and private registries

**v7.6 problem:** Each service had its own image path (`global.deployment.images.interactionapi`, `global.deployment.images.realtimeapi`, etc.), requiring changes to every `images:` entry when deploying from a private registry like ECR. Some customers also needed to edit individual deploy templates to match their registry's naming convention.

**v7.7 solution:** All services now share a single repository and tag:

```yaml
global:
  deployment:
    images:
      repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/redpoint
      tag: "7.7.20260220.1524"
```

The chart constructs each image as `{repository}/{service-name}:{tag}` automatically. No template edits required, regardless of registry provider.

### Service account per deployment file

**v7.6 problem:** Each deploy template created its own ServiceAccount and used the deployment name as the service account name. Customers using a single shared service account (common on EKS with IRSA) had to edit every deploy file to replace `serviceAccountName: {{ $name }}` with their shared SA name.

**v7.7 solution:** The `cloudIdentity.serviceAccount.mode` field controls this centrally:

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: shared              # shared | per-service | both
    name: sa-redpoint-rpi     # any name you want
```

| Mode | Behavior |
|:-----|:---------|
| `shared` | All pods use the single SA specified in `name`. No per-service SAs are created. |
| `per-service` | Each service gets its own SA (e.g., `rpi-realtimeapi`, `rpi-interactionapi`). This is the default. |
| `both` | Per-service SAs are created, plus a shared SA exists for services that need it. |

Any individual service can override its SA by setting `serviceAccountName` in its config block. For example, in `both` mode every service gets its own per-service SA and the shared SA is also created but not used by default. To assign the shared SA to a specific service while the others keep their own:

```yaml
cloudIdentity:
  serviceAccount:
    mode: both
    name: redpoint-rpi

realtimeapi:
  serviceAccountName: redpoint-rpi      # use the shared SA
# all other services keep their per-service SAs (rpi-interactionapi, rpi-executionservice, etc.)
```

The resolution priority is: per-service `serviceAccountName` override first, then mode-based resolution.

No template edits required for any mode.

### Credentials in values.yaml

**v7.6 problem:** Database passwords, API keys, and other credentials had to live in `values.yaml` or be passed via `--set` flags, which made security teams uncomfortable. There was no built-in way to pull secrets from an external vault.

**v7.7 solution:** The new top-level `secretsManagement` section supports three modes:

| Mode | How it works | Credentials in values.yaml? |
|:-----|:-------------|:----------------------------|
| `kubernetes` (default) | Chart creates a K8s Secret from your values | Yes (or pre-create the secret yourself) |
| `sdk` | Apps read directly from your cloud vault at runtime | No |
| `csi` | CSI Secret Store driver syncs vault secrets to a K8s Secret | No |

**To eliminate credentials from your values file entirely**, use `sdk` or `csi`:

<details>
<summary><strong>Example: AWS Secrets Manager with IRSA (sdk mode)</strong></summary>

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: shared
    name: redpoint-rpi
  amazon:
    roleArn: arn:aws:iam::123456789:role/redpoint-rpi-irsa
    region: us-east-1

secretsManagement:
  provider: sdk
  sdk:
    amazon:
      secretTagKey: redpoint-rpi
```

RPI services use IRSA to authenticate to AWS, then read secrets at runtime from Secrets Manager using the tag key for discovery. No database passwords, API keys, or connection strings appear anywhere in your Helm values.

</details>

<details>
<summary><strong>Example: Azure Key Vault with Workload Identity (sdk mode)</strong></summary>

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: shared
    name: redpoint-rpi
  azure:
    managedIdentityClientId: <your-client-id>
    tenantId: <your-tenant-id>

secretsManagement:
  provider: sdk
  sdk:
    azure:
      vaultUri: https://myvault.vault.azure.net/
```

</details>

<details>
<summary><strong>Example: Pre-created Kubernetes Secret (no credentials in values)</strong></summary>

If you prefer to manage K8s secrets yourself (via Sealed Secrets, External Secrets Operator, or manual creation), disable auto-creation and point the chart to your existing secret:

```yaml
secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: false
    secretName: my-existing-rpi-secret
```

The chart references your secret by name without creating or modifying it. You are responsible for ensuring it contains the required keys. Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Reference** tab for the full list of secret keys.

</details>

### Flat container registries (per-service image overrides)

**v7.6 problem:** Some registries (especially AWS ECR) use a flat structure where all images live in a single repository with different tags, rather than separate repositories per service. The v7.6 chart had no way to express this without editing every deploy template.

**v7.7 solution:** The `global.deployment.images.overrides` map lets you override the image for any service. When set, the value is used verbatim instead of the default `{repository}/{service-name}:{tag}` construction:

```yaml
global:
  deployment:
    images:
      repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/redpoint
      tag: "7.7.20260220.1524"
      overrides:
        rpi-interactionapi: 123456789.dkr.ecr.us-east-1.amazonaws.com/rpi:interactionapi-7.7.20260220.1524
        rpi-realtimeapi: 123456789.dkr.ecr.us-east-1.amazonaws.com/rpi:realtimeapi-7.7.20260220.1524
```

Services without an override continue to use the default pattern. You can override one service or all of them.

### Custom CA certificates

**v7.6 problem:** Connecting to databases or internal services that use private/internal certificate authorities required manually editing deploy templates to add volume mounts and environment variables for the CA bundle.

**v7.7 solution:** The `customCACerts` section mounts a ConfigMap or Secret containing your CA certificates into all core service pods:

```yaml
customCACerts:
  enabled: true
  source: configMap           # configMap | secret
  name: my-internal-ca        # name of the ConfigMap or Secret
  mountPath: /usr/local/share/ca-certificates/custom
  certFile: ca-bundle.pem     # optional: sets SSL_CERT_FILE env var
```

Create the ConfigMap from your CA bundle, then reference it in your overrides. The chart handles the volume mount, volume definition, and optional `SSL_CERT_FILE` environment variable automatically.

### Ingress annotations passthrough

**v7.6 problem:** The chart rendered only nginx-specific annotations. Customers using AWS ALB, Traefik, or other ingress controllers had to edit the ingress template to add their controller-specific annotations (scheme, target type, SSL policy, etc.).

**v7.7 solution:** Set `ingress.annotations` in your overrides to pass any annotations to the ingress resources. When set, your annotations replace the nginx defaults entirely:

```yaml
ingress:
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789:certificate/abc123
```

No template edits required for any ingress controller.

### Controllable pod anti-affinity

**v7.6 problem:** Pod anti-affinity was hardcoded in every deploy template as soft (preferred) spreading by hostname. Customers who needed hard (required) anti-affinity for compliance, or wanted to disable it entirely for dev/test environments, had to edit every template.

**v7.7 solution:** The `podAntiAffinity` section controls anti-affinity for all services from a single place:

```yaml
podAntiAffinity:
  enabled: true               # set to false to disable entirely
  type: required              # preferred (soft) | required (hard)
  weight: 100                 # weight for preferred (1-100, ignored for required)
  topologyKey: kubernetes.io/hostname
```

| Setting | Effect |
|:--------|:-------|
| `type: preferred` | Pods prefer different nodes but can co-locate if necessary (default) |
| `type: required` | Pods are guaranteed to land on different nodes; scheduling fails if not possible |
| `enabled: false` | No anti-affinity rules; the scheduler places pods freely |

---

### Common resource annotations

**v7.6 problem:** Adding org-wide annotations (cost center, support email, alert routing, EKS role ARN) required editing every deploy template. Each ServiceAccount, Service, Deployment, and Pod needed the same annotations added manually.

**v7.7 solution:** The `commonAnnotations` field applies annotations to all resource types at once. Per-resource-type overrides merge with the common set:

```yaml
commonAnnotations:
  myorg.com/cost-center: "1234"
  myorg.com/support-email: "team@example.com"
  myorg.com/alert-channel: "email,pagerduty"

# Merged with commonAnnotations on ServiceAccount resources only
serviceAccountAnnotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/redpoint-rpi-irsa

# Merged with commonAnnotations on Service resources only
serviceAnnotations:
  service.beta.kubernetes.io/aws-load-balancer-type: nlb
```

No template edits required. Annotations appear on every ServiceAccount, Service, Deployment, and Pod.

### CSI Secrets Store (AWS Secrets Manager)

**v7.6 problem:** Customers using AWS Secrets Manager via the CSI driver had to create a custom `SecretProviderClass` template and manage it outside the chart.

**v7.7 solution:** The existing `secretsManagement.csi.secretProviderClasses` array now supports AWS-format objects with `jmesPath` extraction via the `objectsContent` field:

```yaml
secretsManagement:
  provider: csi
  csi:
    secretName: redpoint-rpi-secrets
    secretProviderClasses:
      - name: redpoint-secret-class
        provider: aws
        objectsContent: |
          - objectName: "arn:aws:secretsmanager:us-east-1:123456789:secret/rpi-db"
            objectType: secretsmanager
            jmesPath:
              - path: username
                objectAlias: db_username
              - path: password
                objectAlias: db_password
        secretObjects:
          - secretName: redpoint-rpi-secrets
            type: Opaque
            data:
              - key: db_username
                objectName: db_username
              - key: db_password
                objectName: db_password
```

The chart generates the `SecretProviderClass` resource. Use `objectsContent` for raw provider-specific YAML (AWS `jmesPath`, HashiCorp Vault paths, etc.) or `objects` for the structured format.

### StorageClass for CSI-backed storage

**v7.6 problem:** Customers needing a dedicated StorageClass (e.g., EFS CSI on AWS for shared file access) had to create a custom template.

**v7.7 solution:** The `storage.storageClass` section creates a StorageClass directly from values:

```yaml
storage:
  storageClass:
    enabled: true
    name: redpoint-rpi
    provisioner: efs.csi.aws.com
    mountOptions:
      - iam
    parameters:
      provisioningMode: efs-ap
      fileSystemId: fs-0123456789abcdef0
      directoryPerms: "755"
      uid: "10001"
      gid: "10001"
      basePath: /rpi
      subPathPattern: shared-data
      ensureUniqueDirectory: "false"
      reuseAccessPoint: "true"
```

### Karpenter NodePool for dedicated nodes

**v7.6 problem:** Customers using Karpenter for node provisioning had to create and maintain a custom `NodePool` template with instance type requirements, taints, and labels.

**v7.7 solution:** The `nodeProvisioning` section generates a Karpenter `NodePool` resource:

```yaml
nodeProvisioning:
  enabled: true
  provider: karpenter
  karpenter:
    nodePool:
      name: redpoint-nodepool
      labels:
        workload: redpoint-api
      taints:
        - key: workload
          value: redpoint-api
          effect: NoSchedule
      requirements:
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["m7i"]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["4xlarge"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 360h
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 15m
      limits:
        cpu: "1000"
        memory: 1000Gi
```

Use this together with `nodeSelector` and `tolerations` to ensure RPI pods land on the provisioned nodes.

### Ingress domain from external sources

The `ingress.domain` field accepts any value, including those resolved from external sources. If your domain is managed via AWS Secrets Manager or another external system, resolve it before running Helm and pass it with `--set`:

```bash
DOMAIN=$(aws secretsmanager get-secret-value --secret-id my-domain-secret --query SecretString --output text)
helm upgrade rpi ./chart -f overrides.yaml --set ingress.domain=$DOMAIN
```

---

### Enterprise features

Features like per-service image overrides, custom CA certificates, common annotations, CSI secrets, StorageClasses, and Karpenter NodePools are all available in `standard` mode. Simply add the relevant sections to your overrides file. No special mode is required.

---

## Breaking Changes

### Redshift Data Warehouse

Redshift now uses the Npgsql library instead of the ODBC driver. The `databases.datawarehouse.redshift` config block has been removed from the chart. Redshift connections are configured in the RPI client interface using a connection string:

```
Host=<hostname>;Database=<database>;Port=5439;User Id=<username>;Password=<password>;SslMode=Require;Trust Server Certificate=true
```

If you have Redshift in your overrides file, remove the `databases.datawarehouse.redshift` block before upgrading. After deploying v7.7, add your connection string through the client interface.

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

The recommended approach is to generate a fresh v7.7 overrides file using the Web UI, then carry over your environment-specific values from v7.6.

**Step 1: Generate a fresh v7.7 overrides file**

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com):

1. Open the **Generate** tab
2. Select your platform and walk through the 9 configuration steps
3. Use your v7.6 values as reference to fill in the fields (database host, identity settings, ingress domain, cache/queue providers, etc.)
4. Download the generated `overrides.yaml` from the **Validate** tab

This produces a clean v7.7 overrides file with only the keys you need, using the correct v7.7 key structure.

**Step 2: Review what changed**

Use the **Chat** tab to ask "What changed between v7.6 and v7.7?" for a summary of key renames, removed features, and new defaults. The key renames table in Section 1 above has the full mapping.

**Step 3: Verify your configuration**

The **Validate** tab automatically checks your generated overrides for errors, placeholder values, and misconfigurations before you download.

> **Important:** Do not attempt to reuse your v7.6 `values.yaml` directly. The v7.7 chart uses a different key structure, and many settings that were previously in the values file are now chart-managed defaults. A fresh overrides file is typically 50-100 lines instead of 2,600+.

### 3. Generate Secrets and Upgrade

If you used the Web UI or Assistant to generate your overrides, generate secrets from the overrides file:

```bash
bash rpihelmcli/setup.sh secrets -f overrides.yaml
```

Then deploy using the CLI `deploy` command, which handles namespace creation, secrets application, and Helm upgrade with live rollout monitoring:

```bash
bash rpihelmcli/setup.sh deploy -f overrides.yaml
```

Or deploy manually:

```bash
kubectl apply -f secrets.yaml -n redpoint-rpi
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

**Option A: Automatic (recommended)**

```bash
bash rpihelmcli/setup.sh -a database_upgrade
bash rpihelmcli/setup.sh deploy -f overrides.yaml
```

The chart creates a Job that waits for the Deployment API to become ready, then runs the upgrade automatically.

**Option B: Manual**

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

**With Interaction Helm Assistant:**

> "Analyze my v7.6 templates at /path/to/chart/templates for migration to v7.7"

The Assistant compares your templates against the stock v7.6 versions, identifies every custom file and every modification, and provides specific guidance for each, including diffs and advice on which changes can now be expressed as values instead of template edits.

**Without the Assistant:**

1. Copy custom template files (files not in the stock v7.6 chart) to the v7.7 `chart/templates/` directory. Review for compatibility with v7.7 values paths.
2. For modified stock templates, diff your version against the [stock v7.6 templates](https://github.com/RedPointGlobal/redpoint-rpi/tree/release/v7.6/redpoint-rpi/templates) and apply your changes to the v7.7 versions.
3. Many v7.6 template-level customizations (probes, resources, labels, annotations, security context) can now be set directly through values, so check values first before editing templates.

---

## Troubleshooting

If services fail to start after upgrade, the most common cause is a v7.6 customization that wasn't carried over. Use the CLI `troubleshoot` command for quick diagnosis, re-run the migration in the Web UI, or check the reference below.

```bash
bash rpihelmcli/setup.sh troubleshoot -n redpoint-rpi
```

If you customized probes, logging levels, security contexts, or other internal settings in v7.6, these are now set directly under the matching top-level key in your overrides file. Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Reference** tab to browse every available key.

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
| `<service>.resources` (per-service defaults) | `resources` (global) | Global defaults apply to all services; override per-service in your overrides file |
| `queuereader.listenerQueueErrorQueuePath` | `queuereader.errorQueuePath` | Shortened |
| `queuereader.listenerQueueNonActiveQueuePath` | `queuereader.nonActiveQueuePath` | Shortened |
| `queuereader.realtimeConfiguration.distributedCache` | `queuereader.realtimeConfiguration.internalCache` | Renamed |
| `executionservice.internalCache.type` | `executionservice.internalCache.redisSettings.type` | Restructured |
| `databases.datawarehouse.redshift` | *(removed)* | See [Breaking Changes](#breaking-changes) |

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

See the [Configuration Reference](readme-configuration.md) for optional features, or use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) Reference and Chat tabs to browse configuration and ask questions.

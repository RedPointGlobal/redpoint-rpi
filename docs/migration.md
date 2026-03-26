![redpoint_logo](../chart/images/redpoint.png)
# Upgrading from v7.6 to v7.7

[< Back to main README](../README.md)

This guide covers upgrading an existing RPI v7.6 Helm deployment to v7.7. If you're deploying RPI for the first time, see the [Greenfield Installation](greenfield.md) guide instead.

> **Not ready to upgrade?** The `release/v7.6` branch remains available on GitHub for critical fixes. You can stay on v7.6 as long as needed.

---

<details>
<summary><strong style="font-size:1.25em;">What Changed in the Helm Chart</strong></summary>

The `values.yaml` has been redesigned from a **3,000+ line monolithic file** to a **small user-facing override** file. Internal defaults (health probes, security contexts, logging, ports, rollout strategies, etc.) are now managed by the chart automatically.

| Before (v7.6) | After (v7.7) |
|:---|:---|
| Copy the full `values.yaml` and edit it | Maintain a small overrides file with only your customizations |
| 3,000+ lines to manage | 50–100 lines typical |
| Upgrades require diffing the entire file | Upgrades apply new defaults automatically |
| Some defaults were locked inside templates and not overridable | Every internal default can be overridden from your overrides file |


</details>

<details>
<summary><strong style="font-size:1.25em;">New Chart Features</strong></summary>

### Custom container images and private registries

**Before:** Each service had its own image path (`global.deployment.images.interactionapi`, `global.deployment.images.realtimeapi`, etc.), requiring changes to every `images:` entry when deploying from a private registry like ECR. Deploying from registries with different naming conventions also required editing individual deploy templates.

**Now:** All services now share a single repository and tag:

```yaml
global:
  deployment:
    images:
      registry: 123456789.dkr.ecr.us-east-1.amazonaws.com/redpoint
      tag: "7.7.20260220.1524"
```

The chart constructs each image as `{registry}/{service-name}:{tag}` automatically. No template edits required, regardless of registry provider. To extract the full list of images for pre-pulling or mirroring:

```bash
helm template rpi ./chart -f overrides.yaml | grep "image:" | sort -u
```

### Service account per deployment file

**Before:** Each deploy template created its own ServiceAccount using the deployment name. Using a single shared service account (common on EKS with IRSA) required modifying the deployment templates to hardcode a shared service account name.

**Now:** The `cloudIdentity.serviceAccount.mode` field controls this centrally:

```yaml
cloudIdentity:
  enabled: true
  serviceAccount:
    mode: shared              # shared | per-service
    name: sa-redpoint-rpi     # any name you want
```

| Mode | Behavior |
|:-----|:---------|
| `shared` | All pods use the single SA specified in `name`. Simplest for workload identity -- only one federation credential needed. |
| `per-service` | Each service gets its own SA (e.g., `rpi-realtimeapi`, `rpi-interactionapi`). Enables per-service audit trails in vault access logs, least-privilege access policies per service, and independent credential rotation. This is the default. |

No template edits required for either mode.

### Credentials in values.yaml

**Before:** Database passwords, API keys, and other credentials had to live in `values.yaml` or be passed via `--set` flags. There was no built-in way to pull secrets from an external vault.

**Now:** The new top-level `secretsManagement` section supports three modes:

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

**Before:** Some registries (especially AWS ECR) use a flat structure where all images live in a single repository with different tags, rather than separate repositories per service. The v7.6 chart had no way to express this without editing every deploy template.

**Now:** The `global.deployment.images.overrides` map lets you override the image for any service. When set, the value is used verbatim instead of the default `{registry}/{service-name}:{tag}` construction:

```yaml
global:
  deployment:
    images:
      registry: 123456789.dkr.ecr.us-east-1.amazonaws.com/redpoint
      tag: "7.7.20260220.1524"
      overrides:
        rpi-interactionapi: 123456789.dkr.ecr.us-east-1.amazonaws.com/rpi:interactionapi-7.7.20260220.1524
        rpi-realtimeapi: 123456789.dkr.ecr.us-east-1.amazonaws.com/rpi:realtimeapi-7.7.20260220.1524
```

Services without an override continue to use the default pattern. You can override one service or all of them.

### Custom CA certificates

**Before:** Connecting to databases or internal services that use private/internal certificate authorities required manually editing deploy templates to add volume mounts and environment variables for the CA bundle.

**Now:** The `customCACerts` section mounts a ConfigMap or Secret containing your CA certificates into all core service pods:

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

**Before:** The chart rendered only nginx-specific annotations. Deploying with AWS ALB, Traefik, or other ingress controllers required editing the ingress template to add controller-specific annotations (scheme, target type, SSL policy, etc.).

**Now:** Set `ingress.annotations` in your overrides to pass any annotations to the ingress resources. When set, your annotations replace the nginx defaults entirely:

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

**Before:** Pod anti-affinity was hardcoded in every deploy template as soft (preferred) spreading by hostname. Requiring hard anti-affinity for compliance, or disabling it for dev/test environments, meant editing every template.

**Now:** The `podAntiAffinity` section controls anti-affinity for all services from a single place:

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

**Before:** Adding org-wide annotations (cost center, support email, alert routing, EKS role ARN) required editing every deploy template. Each ServiceAccount, Service, Deployment, and Pod needed the same annotations added manually.

**Now:** The `commonAnnotations` field applies annotations to all resource types at once. Per-resource-type overrides merge with the common set:

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

### StorageClass for CSI-backed storage

**Before:** Creating a dedicated StorageClass (e.g., EFS CSI on AWS for shared file access) required a custom template outside the chart.

**Now:** The `storage.storageClass` section creates a StorageClass directly from values:

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

**Before:** Using Karpenter for node provisioning required creating and maintaining a custom `NodePool` template with instance type requirements, taints, and labels.

**Now:** The `nodeProvisioning` section generates a Karpenter `NodePool` resource:

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

### Service mesh (Linkerd) integration

**Before:** Using Linkerd required manually annotating every deployment with proxy injection and timeout settings, either by editing templates or using namespace-level injection (which affected non-RPI pods too).

**Now:** The `serviceMesh` section enables per-pod Linkerd proxy injection and configuration for all RPI deployments. The `serverDefaults` block sets shared settings for all servers, and each server entry only needs a `name` -- the chart auto-derives `podSelector` from the name (e.g., `aks-rpi-realtimeapi` produces `app.kubernetes.io/name: rpi-realtimeapi`):

```yaml
serviceMesh:
  enabled: true
  provider: linkerd
  serverDefaults:
    allowUnauthenticated: false
  servers:
  - name: aks-rpi-interactionapi
  - name: aks-rpi-executionservice
  - name: aks-rpi-nodemanager
  - name: aks-rpi-realtimeapi
  - name: aks-rpi-callbackapi
  - name: aks-rpi-integrationapi
  - name: aks-rpi-deploymentapi
  - name: aks-rpi-queuereader
```

When enabled, the chart automatically adds these pod annotations to all RPI deployments:
- `linkerd.io/inject: enabled` (per-pod proxy injection)
- `config.linkerd.io/skip-outbound-ports: "443"` (skip TLS for outbound HTTPS)
- `config.linkerd.io/proxy-outbound-connect-timeout: "240000ms"` (proxy timeout)

These annotations are overridable via `serviceMesh.podAnnotations`, and can be disabled per-service using that service's `podAnnotations` (e.g., `deploymentapi.podAnnotations: { linkerd.io/inject: disabled }`).

The `servers` list generates Linkerd `Server` CRDs for L7 traffic policy. Each server is automatically paired with an `AuthorizationPolicy` and `NetworkAuthentication` to allow unmeshed traffic (e.g. from your ingress controller). Server options can be set at `serverDefaults` level or overridden per server:

| Option | Default | Description |
|:-------|:--------|:------------|
| `port` | `8080` | Server port. Settable in `serverDefaults` or per server. |
| `proxyProtocol` | `HTTP/1` | Linkerd proxy protocol. Settable in `serverDefaults` or per server. |
| `allowUnauthenticated` | `true` | When true, creates AuthorizationPolicy + NetworkAuthentication to allow unmeshed clients. Set to false to require mTLS only. Settable in `serverDefaults` or per server. |
| `networks` | All (`0.0.0.0/0`, `::/0`) | Custom CIDR list for NetworkAuthentication. Restricts which source IPs can reach the server. Settable in `serverDefaults` or per server. |

**With overrides** -- set defaults for all servers, then override specific ones:

```yaml
serviceMesh:
  enabled: true
  provider: linkerd
  serverDefaults:
    port: 8080
    proxyProtocol: HTTP/1
    allowUnauthenticated: true
    networks:
    - cidr: 10.147.128.0/18
  servers:
  - name: aks-rpi-interactionapi
  - name: aks-rpi-executionservice
    allowUnauthenticated: false
  - name: aks-rpi-nodemanager
    allowUnauthenticated: false
  - name: aks-rpi-realtimeapi
  - name: aks-rpi-callbackapi
  - name: aks-rpi-integrationapi
  - name: aks-rpi-deploymentapi
  - name: aks-rpi-queuereader
```

No template edits required.

### Ingress domain from external sources

The `ingress.domain` field accepts any value, including those resolved from external sources. If your domain is managed via AWS Secrets Manager or another external system, resolve it before running Helm and pass it with `--set`:

```bash
DOMAIN=$(aws secretsmanager get-secret-value --secret-id my-domain-secret --query SecretString --output text)
helm upgrade rpi ./chart -f overrides.yaml --set ingress.domain=$DOMAIN
```

---

### Execution Service internal cache changed to filesystem

**Before:** The Execution Service used Redis as its internal cache by default, requiring a separate Redis StatefulSet for execution state management.

**Now:** The default internal cache provider is `filesystem`, which uses the same persistent volume mounted for the FileOutputDirectory. This simplifies the deployment by removing the need for a dedicated Redis instance for execution state.

```yaml
executionservice:
  internalCache:
    provider: filesystem
```

---

### Granular Realtime API logging

**Before:** Logging for the Realtime API was controlled by a single default level. Setting it to `Information` to see request details also generated excessive internal framework logs. There was no way to log plugin-specific activity without increasing the noise from core components.

**Now:** The Realtime API logging is split into independent channels that can be configured separately:

```yaml
realtimeapi:
  logging:
    realtimeapi:
      default: Error        # Core Redpoint framework (quiet in production)
      endpoint: Information  # HTTP request/response details
      shared: Error          # Shared libraries
      plugins: Information   # Custom plugin execution
      other: Error           # Everything else
      console: "true"        # Enable stdout logging
    realtimeagent:
      default: Error         # Background worker service
      database: Error        # Database operations
      rpiTrace: Error        # RPI trace events
      rpiError: Error        # RPI error events
      console: "false"
```

This allows you to see detailed plugin and endpoint logs while keeping core framework logging quiet, solving the common problem of log noise in production environments with custom plugins.

---

### Queue Reader distributed processing with flexible storage

**Before:** The queue reader's internal Redis cache and RabbitMQ queue were configured with hardcoded volume settings. Pre-provisioning volumes required editing the StatefulSet templates.

**Now:** The `internalCache` and `internalQueues` sections support two storage modes:

**Dynamic provisioning** (default): The chart creates volumeClaimTemplates that automatically provision storage:

```yaml
queuereader:
  realtimeConfiguration:
    isDistributed: true
  internalCache:
    provider: redis
    type: internal
  internalQueues:
    provider: rabbitmq
    type: internal
```

**Pre-provisioned volumes**: When PVCs are created in advance, set `existingClaim` and disable volumeClaimTemplates:

```yaml
queuereader:
  realtimeConfiguration:
    isDistributed: true
  internalCache:
    provider: redis
    type: internal
    redisSettings:
      existingClaim: my-redis-pvc
      volumeClaimTemplates:
        enabled: false
  internalQueues:
    provider: rabbitmq
    type: internal
    rabbitmqSettings:
      existingClaim: my-rabbitmq-pvc
      volumeClaimTemplates:
        enabled: false
```

Note: `internalCache` and `internalQueues` are top-level keys under `queuereader`, not nested under `realtimeConfiguration`.

---

### Multi-tenant Snowflake support

**Before:** The chart supported a single Snowflake private key file stored in a ConfigMap, which meant multi-tenant deployments where each tenant connects to a different Snowflake database with its own credentials required workarounds.

**Now:** Snowflake private keys are stored in a Kubernetes Secret (not a ConfigMap), supporting both direct creation via the CLI and CSI Secret Store sync from a cloud vault. The `keys` array supports multiple key files for multi-tenant deployments:

```yaml
databases:
  datawarehouse:
    snowflake:
      enabled: true
      credentialsType: snowflake_jwt
      secretName: snowflake-creds
      mountPath: /app/snowflake-creds
      keys:
        - keyName: tenant1-private-key.p8
        - keyName: tenant2-private-key.p8
```

All key files are stored in one Secret and mounted to `/app/snowflake-creds/`. Each tenant's connection string in the RPI client uses:

```
Host=<host>;Account=<account>;User=<user>;AUTHENTICATOR=snowflake_jwt;PRIVATE_KEY_FILE=/app/snowflake-creds/tenant1-private-key.p8;Db=<database>;
```

**For kubernetes secrets provider:** The RPI Helm CLI creates the Secret and prompts for each key file.

**For CSI secrets provider:** Add a Snowflake SecretProviderClass that syncs the private key(s) from your cloud vault to the same Secret:

```yaml
secretsManagement:
  csi:
    secretProviderClasses:
      - name: snowflake-secretprovider
        provider: azure
        parameters:
          clientID: "<your-client-id>"
          keyvaultName: "<your-keyvault>"
          resourceGroup: "<your-rg>"
          subscriptionId: "<your-sub-id>"
          tenantId: "<your-tenant-id>"
          useVMManagedIdentity: "false"
          usePodIdentity: "false"
        objects:
          - objectName: sf-tenant1-key
            objectType: secret
            objectAlias: tenant1-private-key.p8
          - objectName: sf-tenant2-key
            objectType: secret
            objectAlias: tenant2-private-key.p8
        secretObjects:
          - secretName: snowflake-creds
            type: Opaque
            data:
              - objectName: tenant1-private-key.p8
                key: tenant1-private-key.p8
              - objectName: tenant2-private-key.p8
                key: tenant2-private-key.p8
```

---

Features like per-service image overrides, custom CA certificates, common annotations, CSI secrets, StorageClasses, and Karpenter NodePools are all available in `standard` mode. Simply add the relevant sections to your overrides file. No special mode is required.


</details>

<details>
<summary><strong style="font-size:1.25em;">Breaking Changes</strong></summary>

- **Redshift**: The `databases.datawarehouse.redshift` config block no longer exists in the chart. Redshift now uses the Npgsql library instead of the ODBC driver.
- **Databricks**: The `databases.datawarehouse.databricks` config block no longer exists in the chart.
- **ODBC ConfigMap**: The `odbc-config` ConfigMap, `ODBCINI` environment variable, and `postStart` lifecycle hook no longer exist.
- **Snowflake**: Changed from ConfigMap to Secret. `ConfigMapName` is now `secretName`, `ConfigMapFilePath` is now `mountPath`.

When you generate your fresh v7.7 overrides, these blocks will not be present. All data warehouse connections are now configured as connection strings in the RPI client interface after deployment. See [Step 6: Update Data Warehouse Connections](#6-update-data-warehouse-connections) in the Upgrade Steps for connection string formats and examples.

</details>

<details>
<summary><strong style="font-size:1.25em;">Before You Upgrade</strong></summary>

The v7.7 upgrade includes a database schema migration (Step 7) that modifies your operational databases. This migration is **not reversible** without restoring from a database backup. Rolling back to v7.6 after the schema upgrade requires both redeploying the v7.6 chart and restoring the databases to their pre-upgrade state.

**Recommendations:**

- **Test in a non-production environment first.** Deploy v7.7 to a staging or dev cluster with a copy of your databases before upgrading production.
- **Back up your operational databases** before running the schema upgrade in production.
- **Take your time.** The `release/v7.6` branch will remain available after v7.7 is GA. Only upgrade when you are confident in your v7.7 configuration and have validated it in a lower environment.
- **Contact [Redpoint Support](mailto:support@redpointglobal.com)** if you need assistance with the upgrade or if you encounter issues.

</details>

<details>
<summary><strong style="font-size:1.25em;">Upgrade Steps</strong></summary>

### 1. Secrets Management

Your existing secrets management setup carries forward to v7.7. No changes are required unless you want to switch providers.

| Your v7.6 setup | v7.7 action |
|:-----------------|:------------|
| **K8s Secrets** (created manually or via CLI) | Set `secretsManagement.provider: kubernetes`. Your existing secrets continue to work. |
| **CSI Secrets Store** (syncing from vault) | Set `secretsManagement.provider: csi`. Move your SecretProviderClass definitions into the overrides under `secretsManagement.csi.secretProviderClasses`. |
| **Considering SDK** (new in v7.7) | Set `secretsManagement.provider: sdk`. Requires creating vault secrets with the exact naming convention RPI expects. See the [Secrets Management Guide](secrets-management.md) for details. |

If staying with your current provider, your vault secrets and K8s Secrets remain as-is. The only change for CSI users is that SecretProviderClass definitions are now managed inside the Helm overrides instead of as separate YAML files.

For the full list of required keys per provider, see the [Secrets Management Guide](secrets-management.md). The [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Vault Secrets Setup** generates scripts for creating vault secrets if needed.

### 2. Cloud Identity

If you already have cloud identity configured (Workload Identity, IRSA, etc.), your existing setup carries forward. Map it to the v7.7 overrides:

| Your v7.6 setup | v7.7 overrides |
|:-----------------|:---------------|
| Azure Managed Identity with Workload Identity | `cloudIdentity.azure.managedIdentityClientId` and `tenantId` |
| AWS IAM Role with IRSA | `cloudIdentity.amazon.roleArn` and `region` |
| GCP Service Account with Workload Identity | `cloudIdentity.google.serviceAccountEmail` |

Set `cloudIdentity.serviceAccount.mode` to match your current setup:
- `shared` - one ServiceAccount for all pods (your v7.6 default if you used a single SA)
- `per-service` - each service gets its own ServiceAccount

No changes to your cloud identity, role assignments, or federation credentials are needed unless you are adding new services or switching providers.

### 3. Generate Overrides

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Generate** tab to create a fresh v7.7 overrides file:

1. Select your platform and walk through the configuration steps
2. Use your v7.6 values as reference for database host, identity settings, ingress domain, cache/queue providers, etc.
3. Review and download from the **Validate** tab

> **Important:** Do not reuse your v7.6 `values.yaml` directly. The v7.7 chart uses a different key structure, and many settings that were previously in the values file are now chart-managed defaults. A fresh overrides file is typically 50-100 lines instead of 2,600+.

### 4. Pull v7.7 Chart

Clone or mirror the upstream chart repository. If you forked the v7.6 chart, you no longer need the fork -- all customization is now done through the overrides file.

```bash
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi
```

The `main` branch contains v7.7. The `release/v7.6` branch remains available for those not ready to upgrade.

For ArgoCD/Flux: point to the upstream chart (or a clean mirror) and keep overrides in a separate config repo. See the [GitOps Guide](readme-argocd.md) for details.

### 5. Deploy v7.7 Chart

If you mirror images from the Redpoint Container Registry to an internal registry (ECR, ACR, Artifactory, etc.), pull and push the v7.7 images before deploying. Your `global.deployment.images.registry` and `tag` in the overrides should point to your internal registry.

```bash
helm upgrade rpi ./chart \
  -f overrides.yaml \
  -n <namespace> \
  --wait \
  --timeout 15m
```

Verify all pods are running:

```bash
kubectl get pods -n <namespace>
```

For CSI: check that validation pods started and secrets synced (`kubectl get secrets -n <namespace>`).

### 6. Update Data Warehouse Connections

In v7.6, data warehouse connections for Redshift and BigQuery were configured via an ODBC ini file generated by the chart (`odbc-config` ConfigMap). In v7.7, the ODBC ConfigMap has been removed. All data warehouse connections are now configured as connection strings directly in the RPI client interface.

After deploying v7.7, open the RPI client and update your data warehouse connections using the appropriate connection string format:

**Snowflake** (JWT key-pair authentication):

```
Host=<your-snowflake-host>;Account=<your-account>;User=<your-username>;AUTHENTICATOR=snowflake_jwt;PRIVATE_KEY_FILE=/app/snowflake-creds/<your-key-file>.p8;Db=<your-database>
```

The connection string supports additional parameters like `warehouse=`, `role=`, and `schema=`. See the [Snowflake .NET Connector docs](https://github.com/snowflakedb/snowflake-connector-net/blob/master/doc/Connecting.md) for the full list.

JWT authentication requires the `.p8` RSA private key file to be mounted in the container. If you already use Snowflake with JWT, your existing key setup carries forward. If you are migrating from username/password to JWT, you need to:

1. Generate an RSA key pair and register the public key with your Snowflake user(s)
2. Make the `.p8` private key available to the chart:
   - **kubernetes**: The CLI creates a K8s Secret from the key file
   - **csi**: Store the key in your vault and define a SecretProviderClass. The chart mounts it directly via CSI inline volume (set `secretProviderClassName` in the Snowflake config)
   - **sdk**: Same as CSI - store in vault, mount via CSI inline volume
3. Enable Snowflake in your overrides under `databases.datawarehouse.snowflake`

See the [Secrets Management Guide](secrets-management.md) for platform-specific examples.

**Redshift** (PostgreSQL driver via Npgsql):

```
Host=<your-cluster>.redshift.amazonaws.com;Port=5439;Database=<your-database>;Username=<your-username>;Password=<your-password>;SSLMode=Require
```

**Google BigQuery** (ODBC driver with service account):

```
Driver=/app/odbc-lib/bigquery/SimbaODBCDriverforGoogleBigQuery64/lib/libgooglebigqueryodbc_sb64.so;Catalog=<your-gcp-project-id>;Location=<your-dataset-location>;SQLDialect=1;AllowLargeResults=0;LargeResultsDataSetId=<your-large-results-dataset>;LargeResultsTempTableExpirationTime=3600000;OAuthMechanism=0;Email=<your-service-account>@<your-project>.iam.gserviceaccount.com;KeyFilePath=/app/google-creds/<your-key-file>.json
```

**Databricks** (Simba Spark ODBC driver):

```
Driver=/app/odbc-lib/simba/spark/lib/libsparkodbc_sb64.so;SparkServerType=3;Host=<your-workspace>.azuredatabricks.net;Port=443;Schema=<your-schema>;SSL=1;ThriftTransport=2;AuthMech=3;UID=token;PWD=<your-access-token>;HTTPPath=<your-sql-warehouse-path>
```

> **Note:** Snowflake requires the private key file to be mounted in the container. See the [Secrets Management Guide](secrets-management.md) for how this works with each secrets provider (kubernetes, csi, sdk). BigQuery still requires the Google service account JSON key file to be mounted via a ConfigMap.

### 7. Perform Database Upgrade

After the v7.7 containers are running, upgrade the operational database schema:

**Option A: Via the chart (recommended)**

```bash
rpihelmcli/setup.sh deploy -f overrides.yaml
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

</details>

## ArgoCD / GitOps Deployments

If you deploy RPI via ArgoCD or Flux, the v7.7 upgrade is a good time to simplify your setup.

**If you forked the v7.6 chart:** You no longer need the fork. The v7.7 chart is designed so that all customization is done through the overrides file. No template edits should be needed. Import the upstream chart into your internal repository as a clean copy.

**Import the v7.7 chart into your internal VCS:**

Most organizations require charts to be imported into internal systems (Azure DevOps, Artifactory, GitLab, etc.) for security scanning and change control before deployment.

```bash
# Clone the upstream chart
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi
git checkout main

# Push to your internal repository
git remote add internal https://git.yourorg.com/platform/redpoint-rpi.git
git push internal main
```

**Recommended repository layout:**

Keep the chart and your overrides in separate repositories:

```
# Chart source (clean import of upstream, no edits)
https://git.yourorg.com/platform/redpoint-rpi.git

# Your config repo (overrides per environment)
https://git.yourorg.com/platform/rpi-config.git
  overrides/
    dev.yaml
    staging.yaml
    production.yaml
```

**Update your ArgoCD Application:**

```yaml
spec:
  sources:
    - repoURL: https://git.yourorg.com/platform/redpoint-rpi.git
      targetRevision: main
      path: chart
      helm:
        valueFiles:
          - $config/overrides/production.yaml
    - repoURL: https://git.yourorg.com/platform/rpi-config.git
      targetRevision: main
      ref: config
```

**Pulling future chart updates:**

When Redpoint releases a chart update, pull it into your internal mirror:

```bash
cd redpoint-rpi
git fetch origin
git push internal main
```

No merge conflicts since you are not editing the chart. Your overrides stay in the config repo and are updated independently.

---

## Template Customizations

In v7.6, many deployments required editing Helm template files directly (adding annotations, custom probes, sidecars, extra env vars, NetworkPolicies, StorageClasses, Karpenter NodePools, etc.). In v7.7, all of these are now native chart features configurable through the overrides file. No template edits should be needed.

To migrate: generate a fresh v7.7 overrides file using the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com), then update it with your environment-specific values. Use the **Reference** tab to find the keys for any settings you previously customized in templates.

---

<details>
<summary><strong style="font-size:1.25em;">Troubleshooting</strong></summary>

If services fail to start after upgrade, the most common cause is a v7.6 customization that wasn't carried over. Use `rpihelmcli/setup.sh status` for quick diagnosis, or ask the [Helm Assistant Chat](https://rpi-helm-assistant.redpointcdp.com) for help.

```bash
rpihelmcli/setup.sh troubleshoot -n redpoint-rpi
```

If you customized probes, logging levels, security contexts, or other internal settings in v7.6, these are now set directly under the matching top-level key in your overrides file. Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Reference** tab to browse every available key.


</details>

---

## Next Steps

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Reference** and **Chat** tabs to browse configuration and ask questions.

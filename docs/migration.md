![redpoint_logo](../chart/images/redpoint.png)
# Upgrading from v7.6 to v7.7

[< Back to main README](../README.md)

This guide covers upgrading an existing RPI v7.6 Helm deployment to v7.7. If you're deploying RPI for the first time, see the [Greenfield Installation](greenfield.md) guide instead.

> **Not ready to upgrade?** The `release/v7.6` branch remains available on GitHub for critical fixes. You can stay on v7.6 as long as needed.

---

<details>
<summary><strong style="font-size:1.25em;">What Changed in v7.7</strong></summary>

The `values.yaml` has been redesigned from a **3,000+ line monolithic file** to a **small user-facing override** file. Internal defaults (health probes, security contexts, logging, ports, rollout strategies, etc.) are now managed by the chart automatically.

| Before (v7.6) | After (v7.7) |
|:---|:---|
| Copy the full `values.yaml` and edit it | Maintain a small overrides file with only your customizations |
| 3,000+ lines to manage | 50–100 lines typical |
| Upgrades require diffing the entire file | Upgrades apply new defaults automatically |
| No escape hatch for hidden internals | Any internal default can be overridden directly under its top-level key |


</details>

<details>
<summary><strong style="font-size:1.25em;">What's New in v7.7</strong></summary>

### Custom container images and private registries

**Before:** Each service had its own image path (`global.deployment.images.interactionapi`, `global.deployment.images.realtimeapi`, etc.), requiring changes to every `images:` entry when deploying from a private registry like ECR. Some customers also needed to edit individual deploy templates to match their registry's naming convention.

**Now:** All services now share a single repository and tag:

```yaml
global:
  deployment:
    images:
      repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/redpoint
      tag: "7.7.20260220.1524"
```

The chart constructs each image as `{repository}/{service-name}:{tag}` automatically. No template edits required, regardless of registry provider. To extract the full list of images for pre-pulling or mirroring:

```bash
helm template rpi ./chart -f overrides.yaml | grep "image:" | sort -u
```

### Service account per deployment file

**Before:** Each deploy template created its own ServiceAccount and used the deployment name as the service account name. Customers using a single shared service account (common on EKS with IRSA) had to edit every deploy file to replace `serviceAccountName: {{ $name }}` with their shared SA name.

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
| `per-service` | Each service gets its own SA (e.g., `rpi-realtimeapi`, `rpi-interactionapi`). Use when you need per-service IAM roles. This is the default. |

No template edits required for either mode.

### Credentials in values.yaml

**Before:** Database passwords, API keys, and other credentials had to live in `values.yaml` or be passed via `--set` flags, which made security teams uncomfortable. There was no built-in way to pull secrets from an external vault.

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

**Now:** The `global.deployment.images.overrides` map lets you override the image for any service. When set, the value is used verbatim instead of the default `{repository}/{service-name}:{tag}` construction:

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

**Before:** The chart rendered only nginx-specific annotations. Customers using AWS ALB, Traefik, or other ingress controllers had to edit the ingress template to add their controller-specific annotations (scheme, target type, SSL policy, etc.).

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

**Before:** Pod anti-affinity was hardcoded in every deploy template as soft (preferred) spreading by hostname. Customers who needed hard (required) anti-affinity for compliance, or wanted to disable it entirely for dev/test environments, had to edit every template.

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

### CSI Secrets Store (AWS Secrets Manager)

**Before:** Customers using AWS Secrets Manager via the CSI driver had to create a custom `SecretProviderClass` template and manage it outside the chart.

**Now:** The existing `secretsManagement.csi.secretProviderClasses` array now supports AWS-format objects with `jmesPath` extraction via the `objectsContent` field:

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

**Before:** Customers needing a dedicated StorageClass (e.g., EFS CSI on AWS for shared file access) had to create a custom template.

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

**Before:** Customers using Karpenter for node provisioning had to create and maintain a custom `NodePool` template with instance type requirements, taints, and labels.

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

**Before:** Customers using Linkerd had to manually annotate every deployment with proxy injection and timeout settings, either by editing templates or using namespace-level injection (which affected non-RPI pods too).

**Now:** The `serviceMesh` section enables per-pod Linkerd proxy injection and configuration for all RPI deployments:

```yaml
serviceMesh:
  enabled: true
  provider: linkerd
  servers:
  - name: aks-rpi-interactionapi
    podSelector:
      app.kubernetes.io/name: rpi-interactionapi
    port: 8080
    proxyProtocol: HTTP/1
```

When enabled, the chart automatically adds these pod annotations to all RPI deployments:
- `linkerd.io/inject: enabled` (per-pod proxy injection)
- `config.linkerd.io/skip-outbound-ports: "443"` (skip TLS for outbound HTTPS)
- `config.linkerd.io/proxy-outbound-connect-timeout: "240000ms"` (proxy timeout)

Override any default or add additional annotations via `serviceMesh.podAnnotations`:

```yaml
serviceMesh:
  enabled: true
  provider: linkerd
  podAnnotations:
    config.linkerd.io/skip-outbound-ports: "443,587"
    config.linkerd.io/proxy-cpu-request: "100m"
```

To disable injection for a specific service, use that service's `podAnnotations`:

```yaml
deploymentapi:
  podAnnotations:
    linkerd.io/inject: disabled
```

The `servers` list generates Linkerd `Server` CRDs for L7 traffic policy. Each server is automatically paired with an `AuthorizationPolicy` and `NetworkAuthentication` to allow unmeshed traffic (e.g. from your ingress controller). Per-server options:

| Option | Default | Description |
|:-------|:--------|:------------|
| `allowUnauthenticated` | `true` | When true, creates AuthorizationPolicy + NetworkAuthentication to allow unmeshed clients. Set to false to require mTLS only. |
| `networks` | All (`0.0.0.0/0`, `::/0`) | Custom CIDR list for NetworkAuthentication. Restricts which source IPs can reach the server. |

```yaml
serviceMesh:
  servers:
  - name: aks-rpi-interactionapi
    podSelector:
      app.kubernetes.io/name: rpi-interactionapi
    port: 8080
    proxyProtocol: HTTP/1
    # allowUnauthenticated: true    # default
    # networks:                     # restrict to cluster-internal only
    #   - cidr: 10.0.0.0/8
  - name: aks-rpi-executionservice
    podSelector:
      app.kubernetes.io/name: rpi-executionservice
    port: 8080
    proxyProtocol: HTTP/1
    allowUnauthenticated: false     # mTLS only, no ingress traffic
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

**Before:** The queue reader's internal Redis cache and RabbitMQ queue were configured with hardcoded volume settings. Customers who pre-provisioned their volumes had to edit the StatefulSet templates.

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

**Pre-provisioned volumes**: For customers who create PVCs in advance, set `existingClaim` and disable volumeClaimTemplates:

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

### Redshift Data Warehouse

Redshift now uses the Npgsql library instead of the ODBC driver. The `databases.datawarehouse.redshift` config block has been removed from the chart. Redshift connections are configured in the RPI client interface using a connection string:

```
Host=<hostname>;Database=<database>;Port=5439;User Id=<username>;Password=<password>;SslMode=Require;Trust Server Certificate=true
```

If you have Redshift in your overrides file, remove the `databases.datawarehouse.redshift` block before upgrading. After deploying v7.7, add your connection string through the client interface.

### Databricks Data Warehouse

Databricks now uses a connection string configured in the RPI client interface. The `databases.datawarehouse.databricks` config block and the `odbc-config` ConfigMap have been removed from the chart.

Example connection string format:

```
Driver=/app/odbc-lib/simba/spark/lib/libsparkodbc_sb64.so;SparkServerType=3;Host=<hostname>;Port=443;Schema=<schema>;SSL=1;ThriftTransport=2;AuthMech=3;UID=token;PWD=<token>;HTTPPath=<path>
```

If you have Databricks in your overrides file, remove the `databases.datawarehouse.databricks` block before upgrading. After deploying v7.7, add your connection string through the client interface.

### ODBC ConfigMap Removed

The `odbc-config` ConfigMap, `ODBCINI` environment variable, and the `postStart` lifecycle hook that copied the ODBC ini file are no longer needed. All data warehouse providers (Redshift, Databricks, BigQuery) now use connection strings configured directly in the RPI client interface. BigQuery service account credential mounts remain unchanged.

</details>

<details>
<summary><strong style="font-size:1.25em;">Upgrade Steps</strong></summary>

### 1. Determine Secrets Management

Choose how RPI will access sensitive values (database credentials, connection strings, API tokens):

| Provider | Best for | Setup |
|:---------|:---------|:------|
| **sdk** (recommended) | Cloud deployments (Azure, AWS, GCP) | Services read secrets from vault at runtime. Simplest ongoing maintenance. |
| **csi** | Cloud deployments that require all secrets synced to K8s | CSI driver syncs vault to K8s Secret. More YAML config, requires validation pods. |
| **kubernetes** | Self-hosted / on-premise | CLI generates K8s Secret from user input. No vault needed. |

For **sdk** or **csi**, you need to create the required secrets in your vault before deploying. See the [Secrets Management Guide](secrets-management.md) for the full list of required keys per feature, and use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Vault Secrets Setup** to generate a script that creates everything automatically.

### 2. Prepare Cloud Identity

RPI services authenticate to cloud resources (vaults, storage accounts) using workload identity. Create a cloud identity and configure it with the access your deployment needs:

**What to create:**
- **Azure**: User-Assigned Managed Identity with `Key Vault Secrets User` role and storage account access
- **AWS**: IAM Role with Secrets Manager read access and EFS/S3 access
- **GCP**: Service Account with Secret Manager access and Filestore/GCS access

**Configure workload identity federation** so each RPI service account can authenticate as the cloud identity. The services that need federation:

`rpi-interactionapi`, `rpi-integrationapi`, `rpi-executionservice`, `rpi-nodemanager`, `rpi-realtimeapi`, `rpi-callbackapi`, `rpi-queuereader`, `rpi-deploymentapi`, `rpi-validationpods`

Use `cloudIdentity.serviceAccount.mode: per-service` in your overrides for per-service audit trails in vault access logs.

The [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab > **Vault Secrets Setup** generates a script that creates the identity, grants vault and storage access, and configures all 9 federated credentials in one step.

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

```bash
# Update image pull secret if needed (if pulling from Redpoint ACR)
kubectl create secret docker-registry redpoint-rpi-secrets \
  --docker-server=rg1acrpub.azurecr.io \
  --docker-username=<username> \
  --docker-password='<password>' \
  -n <namespace> \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy
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
rpihelmcli -a database_upgrade
rpihelmcli deploy -f overrides.yaml
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

<details>
<summary><strong style="font-size:1.25em;">Rollback</strong></summary>

```bash
helm rollback rpi -n redpoint-rpi
```

Or switch back to the v7.6 branch:

```bash
git checkout release/v7.6
helm upgrade rpi ./chart -f my-old-values.yaml -n redpoint-rpi
```

> **Note:** Database schema changes are **not** automatically rolled back. Contact [Redpoint Support](mailto:support@redpointglobal.com) if you need to revert database changes.


</details>

## Template Customizations

In v7.6, many deployments required editing Helm template files directly (adding annotations, custom probes, sidecars, extra env vars, NetworkPolicies, StorageClasses, Karpenter NodePools, etc.). In v7.7, all of these are now native chart features configurable through the overrides file. No template edits should be needed.

To migrate: generate a fresh v7.7 overrides file using the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com), then update it with your environment-specific values. Use the **Reference** tab to find the keys for any settings you previously customized in templates.

---

<details>
<summary><strong style="font-size:1.25em;">Troubleshooting</strong></summary>

If services fail to start after upgrade, the most common cause is a v7.6 customization that wasn't carried over. Use `rpihelmcli status` for quick diagnosis, or ask the [Helm Assistant Chat](https://rpi-helm-assistant.redpointcdp.com) for help.

```bash
bash rpihelmcli troubleshoot -n redpoint-rpi
```

If you customized probes, logging levels, security contexts, or other internal settings in v7.6, these are now set directly under the matching top-level key in your overrides file. Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Reference** tab to browse every available key.


</details>

---

## Next Steps

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Reference** and **Chat** tabs to browse configuration and ask questions.

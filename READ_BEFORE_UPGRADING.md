![redpoint_logo](assets/images/logo.png)
## Read Before Upgrading

This version introduces significant changes including new StatefulSets for the default Redis and RabbitMQ dependencies, multi-tenantancy for the Callback API, new optional Data Activation services, and several structural changes. 


-----------------------------------------------------------------------
**Because this is a breaking upgrade, a clean reconciliation of several Deployments and the introduction of new StatefulSets are required.**

## What’s New in This Release (High-Level)

- 9 new Data Activation services (optional)
- RabbitMQ redesigned as StatefulSet with persistent storage
- Execution Service Redis cache redesigned as a StatefulSet with persistent storage
- Multi-tenant CallbackAPI
- Multi-tenant Data Warehouse providers (Redshift, BigQuery)
- Support for Pod Disruption Budgets
- Ingress HTTPS enforcement

## Breaking Changes

### 1. RabbitMQ Configuration Restructure ⚠️

- RabbitMQ is now deployed as a **StatefulSet** with persistent storage.

**New Queuereader distributedQueue Configuration (StatefulSet-based):**

```yaml
distributedQueue:
  # Currently, only RabbitMQ is supported.
  provider: rabbitmq
  # Type of RabbitMQ to use:
  # - internal: use the RabbitMQ instance created by the Helm chart
  # - external: use an externally hosted RabbitMQ service
  type: internal
  rabbitmqSettings:
  #  When using the internal RabbitMQ instance:
  #   - Replace `{{ .Release.Namespace }}` with the namespace where this Helm release is deployed.
  # - For external RabbitMQ: replace the entire value with the hostname and port for broker.
    hostname: "rpi-queuereader-rabbitmq-0.rpi-queuereader-rabbitmq.{{ .Release.Namespace }}.svc.cluster.local"
    username: redpointrpi
    # Password used to authenticate with the RabbitMQ instance.
    # - Required if using the internal RabbitMQ instance created by this Helm chart.
    password: my_Super_Strong_Pwd
    virtualhost: /
    resources:
      enabled: true
      requests:
        cpu: 500m
        memory: 750Mi
      limits:
        cpu: "1"
        memory: 3Gi
    volumeClaimTemplates:
      enabled: true
      storage: "50Gi"
```
**What Changed:**
- **Helm chart now deploys Rabbitmq as StatefulSet**: 
- **StatefulSet ensures data persistence**: Cache survives pod restarts and maintains state
- **Connection string uses StatefulSet DNS**: ```"rpi-queuereader-rabbitmq-0.rpi-queuereader-rabbitmq.{{ .Release.Namespace }}.svc.cluster.local"```
- **Password-protected**: Enhanced security with required authentication
- **50Gi persistent volume**: Automatically provisioned PVC per StatefulSet replica

**Required Actions:**
- Replace ```{{ .Release.Namespace }}``` with your actual namespace name
- Update username `redpointrpi` to your preferred username
- Review 50Gi storage requirement for the PVC. Increase as necessary
- Note: StatefulSets provide stable pod identities and persistent storage across pod restarts/rescheduling

---

### 2. Execution Service Redis Cache Restructure ⚠️

- Execution Service now connects to an **internal Redis cache deployed by the Helm chart as a StatefulSet**.

**Old Configuration (Internal Deployment based):**
```yaml
executionservice:
  internalCache:
    enabled: true
    redisSettings:
      connectionString: executionservice-rediscache:6379  # External Redis reference
```

**New Configuration (Internal StatefulSet based Redis):**
```yaml
executionservice:
  internalCache:
    enabled: true
    type: internal  # NEW: Helm chart now deploys Redis StatefulSet
    redisSettings:
      password: my_Super_Strong_Pwd  # NEW: Password required for security
      connectionString: "rpi-executionservice-cache-0.rpi-executionservice-cache.{{ .Release.Namespace }}.svc.cluster.local,password={{ myPassword }},abortConnect=False"
      replicas: 1  # StatefulSet replica count (keep at 1 to avoid split-brain)
      resources:  # NEW: Redis resource configuration
        enabled: true
        requests:
          cpu: 256m
          memory: 3Gi
      volumeClaimTemplates:  # NEW: StatefulSet persistent storage
        enabled: true
        storage: "50Gi"  # Per-replica PVC for data persistence
      podDisruptionBudget:  # NEW: PDB for cache stability
        enabled: true
        maxUnavailable: 0
```

**What Changed:**
- Helm chart now deploys Redis as StatefulSet: 
- StatefulSet ensures data persistence: Cache survives pod restarts and maintains state
- Connection string uses StatefulSet DNS: `rpi-executionservice-cache-0.rpi-executionservice-cache.<namespace>.svc.cluster.local`
- Password-protected: Enhanced security with required authentication
- 50Gi persistent volume: Automatically provisioned PVC per StatefulSet replica

**Required Actions:**
- Set Redis password (used for authentication to internal cache)
- Update connection string to StatefulSet DNS pattern
- Prepare for 50Gi persistent volume - ensure StorageClass can provision PVC
- Keep `replicas: 1` (single Redis instance prevents split-brain scenarios)

---

### 4. Data Warehouse Multi-Tenancy ⚠️

Per tenant DSN (ODBC) configuration for Redshift and BiqQuery Data warehouse providers

This only applies if your datawarehouse is one of ```Redshift``` or ```BigQuery```.  Redshift and BigQuery use ODBC drivers, which require a configuration file to be included in the containers. The details you provide are used to configure the Data Source Name (DSN). After deployment, the connection string for your Redshift or BigQuery data warehouse would look like this: ```dsn=rsh-tenant1``` or ```dsn=gbq-tenant1```

**Old Configuration:**
```yaml
datawarehouse:
  enabled: true
  provider: redshift
  redshift:
    # Single connection configuration
```

**New Configuration:**
```yaml
datawarehouse:
  redshift:
    enabled: true
    connections:  # Array of connections
      - name: rsh-tenant1  # Named DSN
        server: redshift-tenant1.endpoint.aws
        port: 5439
        database: db_tenant1
        username: user1
        password: pass1
      - name: rsh-tenant2
        server: redshift-tenant2.endpoint.aws
        ...
  bigquery:
    enabled: false
    connections:  # Multi-tenant support
      - name: gbq-tenant1
        ...
  databricks:  # NEW
    enabled: true
    connections:
      - name: dbx-tenant1
        host: my-host.2.azuredatabricks.net
        port: 443
        httpPath: /sql/1.0/warehouses/...
  autoCreateSecrets: true  # NEW
```

**Required Actions:**
- Convert single provider to per-provider `enabled` flags
- Migrate to connection arrays with named DSNs
- Update RPI connection strings to use DSN names (e.g., `dsn=rsh-tenant1`)

---
### 5. CallbackAPI Multi-Tenancy

Each RPI client requires its own dedicated CallbackAPI instance. The Chart now enables multitenancy to automatically provision a dedicated instance for each client. 

```yaml
callbackapi:
  multitenancy:
    enabled: true  # Enable multi-tenant mode
  instances:
    - name: "tenant1"
      replicas: 1
    - name: "tenant2"
      replicas: 1
```

### 6. Data Activation Platform (CDP)

**Nine new optional services:**
- `cdp-authservice` - Authentication service
- `cdp-keycloak` - SSO/Identity Management
- `cdp-servicesapi` - Core CDP Services API
- `cdp-ui` - Web UI
- `cdp-socketio` - Real-time communication
- `cdp-maintenance` - Upgrade/Maintenance jobs
- `cdp-init` - Initialization Service
- `cdp-messageq` - Internal message queue (RabbitMQ)
- `cdp-cache` - Redis cache

**Action:** 

- Set `dataactivation.enabled: false` to skip (default)
- Set `dataactivation.enabled: true` to enable (default)

---

### 7. Pod Disruption Budgets

All services now support PDB for controlled disruptions: These are enabled by default for the Execution Service and Internal Redis Cache

**Recommendation:** Enable these PDBs in production after upgrade stabilization.

```yaml
realtimeapi:
  podDisruptionBudget:
    enabled: true  # Enable in production
    maxUnavailable: 0  # Zero-downtime updates
```

### 8. Enhanced Debugging Capabilities

Execution Service now has extensive debugging environment variables to troubleshoot mPulse integration issues

```yaml
executionservice:
  extraEnvs:
    - name: RPI_MPULSE_UPSERT_CONTACT_DEBUG
      enabled: true  # Enable as needed
      value: "1"
    - name: RPI_MPULSE_EVENT_UPLOAD_DEBUG
      enabled: true
      value: "1"
```

## Resource Changes

- Most services show increased memory limits
- CPU limits are now commented out following Kubernetes best practices. Setting CPU requests without limits allows efficient scheduling while preventing CPU starvation

**Why This Change?**
- Without hard CPU limits, pods can burst above requests when CPU is available
- Pods use idle cluster CPU instead of being artificially throttled
- Memory has hard limits to prevent OOM issues

### RPI Authentication AuthMetaHttpHost

This new ```authMetaHttpEnabled``` setting controls how the Interaction and Integration APIs resolve the OpenID discovery metadata.

```yaml
# Old
interactionapi:
  authMetaHttpEnabled: true

# New
integrationapi:
  authMetaHttpEnabled: false  # Changed
```
**Why this Change?**

- When ```authMetaHttpEnabled = true```: The service performs its OpenID discovery calls through the internal Kubernetes DNS service over plain HTTP. This is appropriate for the ```Interaction API```, which only needs to resolve authentication metadata internally and does not rely on the external ingress path.

- When ```authMetaHttpEnabled = false```: The service uses the external HTTPS ingress endpoint for OpenID discovery. This is required for the ```Integration API```, because Swagger UI (accessed via the public ingress) needs to resolve the correct external OpenID metadata endpoints so that the available authorization flows display correctly.

### Integration API Credentials (optional)

- Username and Password are only required if Data Activation is enabled

```yaml
# New feature
integrationapi:
  username: integrationapi
  password: <my-integrationapi-password>
  read_timeout: "300000"
```

### SMTP Sender Name (optional)

- SMTP_SenderName only required if Data Activation is enabled

```yaml
SMTPSettings:
  SMTP_SenderName: "Redpoint Global"  # NEW
```

### Ingress HTTPS Enforcement

These annotations explicitly enforce HTTPS at the NGINX Ingress level to ensure all HTTP requests are automatically redirected to HTTPS.

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"      # NEW
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"  # NEW
```

## Upgrade Procedure

- Backup your Current Configuration
- Review Cluster Capacity
- Create Updated ```values.yaml```
- Upgrade your helm release ```helm upgrade <release_name> redpoint-rpi --values my-values.yaml```

### Known Issue: Upgrade Failure Due to Immutable Deployment Selectors ⚠️

Upgrading to this chart version may fail with an error similar to the following:

```
Error: UPGRADE FAILED: cannot patch "<deployment>" with kind Deployment:
Deployment.apps "<deployment>" is invalid: spec.selector: Invalid value:
field is immutable

```

This occurs because the chart update modifies the ```.spec.selector``` labels of existing Deployments. Kubernetes does not allow changes to spec.selector on existing Deployments, causing Helm to fail during upgrade.

**Impact**: All existing RPI deployments created by previous versions of the chart must be recreated before applying this upgrade. Prior to running helm upgrade, delete the RPI Deployments (pods will be recreated automatically).

```
kubectl delete deployment rpi-callbackapi rpi-deploymentapi rpi-executionservice \
  rpi-integrationapi rpi-interactionapi rpi-nodemanager rpi-queuereader \
  rpi-realtimeapi ingress-nginx-controller

```
Then apply the Upgrade

```
helm upgrade <release_name> redpoint-rpi --values my-values.yaml
```

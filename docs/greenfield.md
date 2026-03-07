![redpoint_logo](../chart/images/logo.png)
# New Installation (Greenfield)

[< Back to main README](../README.md)

This guide walks through deploying RPI from scratch in a new environment — new cluster, new databases, new cache and queue providers.

---

## Overview

1. Clone this repository
2. Create a Kubernetes namespace
3. Create secrets for image pull and TLS
4. Pre-create Kubernetes secrets (optional — only if not using autoCreateSecrets)
5. Configure your operational database and data warehouse connections
6. Create your environment overrides file
7. Deploy with Helm
8. Activate your license and install databases

---

## Quick Start with CLI Scaffolder

For a guided setup, use the interactive scaffolder to generate your overrides file:

```bash
bash deploy/cli/rpi-init.sh
```

This walks you through platform selection, database config, cloud identity, and generates a ready-to-use overrides file plus a prerequisites script. You can then skip directly to [Step 9: Install RPI](#9-install-rpi).

---

## 1. Clone This Repository

```bash
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi
```

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
│   ├── cli/
│   │   └── rpi-init.sh           # Interactive overrides generator
│   ├── terraform/                # IaC modules (Azure, AWS, GCP)
│   └── values/                   # Your environment overrides
│       ├── azure/azure.yaml      # Azure example
│       ├── aws/amazon.yaml       # AWS example
│       └── demo/demo.yaml        # Demo/dev example
├── docs/                         # Deployment guides
│   ├── greenfield.md             # This file
│   ├── migration.md              # v7.6 → v7.7 upgrade guide
│   ├── readme-values.md          # Values & overrides guide
│   ├── readme-argocd.md          # ArgoCD deployment guide
│   └── values-reference.yaml    # Complete reference of all keys
└── README.md
```

You deploy by passing a small overrides file containing only your customizations. Everything else uses chart defaults automatically. See [readme-values.md](readme-values.md) for details.

## 2. Create Kubernetes Namespace

```bash
kubectl create namespace redpoint-rpi
```

## 3. Create Container Registry Secret

Obtain credentials from [Redpoint Support](mailto:support@redpointglobal.com) and create the image pull secret:

```bash
NAMESPACE=redpoint-rpi
DOCKER_SERVER=rg1acrpub.azurecr.io
DOCKER_USERNAME=<your_username>
DOCKER_PASSWORD=<your_password>

kubectl create secret docker-registry redpoint-rpi \
  --namespace $NAMESPACE \
  --docker-server=$DOCKER_SERVER \
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$DOCKER_PASSWORD
```

## 4. Create TLS Certificate Secret

The Helm chart deploys an ingress controller to expose RPI services over HTTPS. Provide your TLS certificate key pair:

```bash
NAMESPACE=redpoint-rpi
CERT_PATH=./your_cert.crt
KEY_PATH=./your_cert.key

kubectl create secret tls ingress-tls \
  --namespace $NAMESPACE \
  --cert=$CERT_PATH \
  --key=$KEY_PATH
```

Then configure the ingress domain in your overrides file. To use your own ingress controller instead of the chart-provided one, set `controller.enabled` to `false`:

```yaml
ingress:
  domain: example.com
  controller:
    enabled: false
```

## 5. Pre-Create Kubernetes Secrets (When Not Using autoCreateSecrets)

By default, the chart auto-generates the `redpoint-rpi-secrets` Kubernetes Secret from the values you provide in your overrides file (`secretsManagement.kubernetes.autoCreateSecrets: true`). This is the simplest path — skip to [Step 6](#6-configure-operational-database).

However, if you prefer to manage secrets externally (e.g., via a CI/CD pipeline, sealed secrets, or security policy), set `autoCreateSecrets: false` and pre-create the secret manually. The examples below show the minimum required keys for each platform.

### Azure Standard (AzureSQL + Service Bus + MongoDB Cache)

```bash
NAMESPACE=redpoint-rpi

# -- Operational Database --
DB_HOST="myserver.database.windows.net"
DB_USER="rpiadmin"
DB_PASS="<my-db-password>"
PULSE_DB="Pulse"
LOGGING_DB="Pulse_Logging"

# -- Connection strings (SQL Server format) --
OPS_CONN="Server=tcp:${DB_HOST},1433;Database=${PULSE_DB};User ID=${DB_USER};Password=${DB_PASS};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
LOG_CONN="Server=tcp:${DB_HOST},1433;Database=${LOGGING_DB};User ID=${DB_USER};Password=${DB_PASS};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"

# -- Realtime API --
RT_AUTH_TOKEN="$(openssl rand -hex 16)"
SERVICEBUS_CONN="Endpoint=sb://<my-servicebus>.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<my-key>"
MONGO_CONN="mongodb+srv://<my-user>:<my-password>@<my-cluster>.mongocluster.cosmos.azure.com/?tls=true&authMechanism=SCRAM-SHA-256"

kubectl create secret generic redpoint-rpi-secrets \
  --namespace $NAMESPACE \
  --from-literal=ConnectionString_Operations_Database="$OPS_CONN" \
  --from-literal=ConnectionString_Logging_Database="$LOG_CONN" \
  --from-literal=Operations_Database_Server_Password="$DB_PASS" \
  --from-literal=Operations_Database_ServerHost="$DB_HOST" \
  --from-literal=Operations_Database_Server_Username="$DB_USER" \
  --from-literal=Operations_Database_Pulse_Database_Name="$PULSE_DB" \
  --from-literal=Operations_Database_Pulse_Logging_Database_Name="$LOGGING_DB" \
  --from-literal=RealtimeAPI_Auth_Token="$RT_AUTH_TOKEN" \
  --from-literal=RealtimeAPI_ServiceBus_ConnectionString="$SERVICEBUS_CONN" \
  --from-literal=RealtimeAPI_MongoCache_ConnectionString="$MONGO_CONN"
```

Then in your overrides file:

```yaml
secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
```

### AWS Standard (RDS SQL Server + SQS + MongoDB Cache)

On AWS with IRSA (IAM Roles for Service Accounts), SQS authentication is handled by the pod's IAM role — no connection string secret is needed for the queue provider. If using SQS with access keys instead of IRSA, add `AWS_Access_Key_ID` and `AWS_Secret_Access_Key` to the secret.

```bash
NAMESPACE=redpoint-rpi

# -- Operational Database --
DB_HOST="myinstance.xxxx.us-east-1.rds.amazonaws.com"
DB_USER="rpiadmin"
DB_PASS="<my-db-password>"
PULSE_DB="Pulse"
LOGGING_DB="Pulse_Logging"

# -- Connection strings (SQL Server format) --
OPS_CONN="Server=tcp:${DB_HOST},1433;Database=${PULSE_DB};User ID=${DB_USER};Password=${DB_PASS};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
LOG_CONN="Server=tcp:${DB_HOST},1433;Database=${LOGGING_DB};User ID=${DB_USER};Password=${DB_PASS};Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"

# -- Realtime API --
RT_AUTH_TOKEN="$(openssl rand -hex 16)"
MONGO_CONN="mongodb+srv://<my-user>:<my-password>@<my-cluster>.mongodb.net/?retryWrites=true&w=majority"

kubectl create secret generic redpoint-rpi-secrets \
  --namespace $NAMESPACE \
  --from-literal=ConnectionString_Operations_Database="$OPS_CONN" \
  --from-literal=ConnectionString_Logging_Database="$LOG_CONN" \
  --from-literal=Operations_Database_Server_Password="$DB_PASS" \
  --from-literal=Operations_Database_ServerHost="$DB_HOST" \
  --from-literal=Operations_Database_Server_Username="$DB_USER" \
  --from-literal=Operations_Database_Pulse_Database_Name="$PULSE_DB" \
  --from-literal=Operations_Database_Pulse_Logging_Database_Name="$LOGGING_DB" \
  --from-literal=RealtimeAPI_Auth_Token="$RT_AUTH_TOKEN" \
  --from-literal=RealtimeAPI_MongoCache_ConnectionString="$MONGO_CONN"
```

### Secret Key Reference

The table below lists all supported secret keys. Only include the keys relevant to your configuration.

| Key | Required | Used By | Notes |
|-----|----------|---------|-------|
| `ConnectionString_Operations_Database` | Always | All services | Full connection string to Pulse database |
| `ConnectionString_Logging_Database` | Always | All services | Full connection string to Pulse_Logging database |
| `Operations_Database_Server_Password` | Always | Deployment API, Keycloak | Database password (standalone) |
| `Operations_Database_ServerHost` | Always | Deployment API | Database server hostname |
| `Operations_Database_Server_Username` | Always | Deployment API | Database username |
| `Operations_Database_Pulse_Database_Name` | Always | Deployment API | Pulse database name |
| `Operations_Database_Pulse_Logging_Database_Name` | Always | Deployment API | Pulse_Logging database name |
| `RealtimeAPI_Auth_Token` | When Realtime enabled (basic auth) | Realtime API | API authentication token |
| `RealtimeAPI_ServiceBus_ConnectionString` | Azure Service Bus queue | Realtime API, Callback API | Service Bus connection string |
| `RealtimeAPI_EventHub_ConnectionString` | Azure Event Hubs queue | Realtime API, Callback API | Event Hubs connection string |
| `RealtimeAPI_AzureStorage_ConnectionString` | Azure Storage queue | Realtime API, Callback API | Storage account connection string |
| `RealtimeAPI_MongoCache_ConnectionString` | MongoDB cache | Realtime API | MongoDB connection string |
| `RealtimeAPI_RedisCache_ConnectionString` | Redis cache | Realtime API | Redis connection string |
| `RealtimeAPI_RedisCache_Password` | Redis cache | Realtime API | Redis password |
| `RealtimeAPI_inMemorySql_ConnectionString` | SQL Server cache | Realtime API | SQL in-memory cache connection string |
| `RealtimeAPI_RabbitMQ_Password` | Internal RabbitMQ queue | Realtime API, Callback API | Auto-generated if internal |
| `ConnectionString_RealtimeApi_OAuth` | Realtime OAuth mode | Realtime API | OAuth database connection string |
| `AWS_Access_Key_ID` | SQS with access keys | Realtime API, Callback API | Not needed when using IRSA |
| `AWS_Secret_Access_Key` | SQS with access keys | Realtime API, Callback API | Not needed when using IRSA |
| `ExecutionService_RedisCache_ConnectionString` | Execution service cache | Execution Service | Auto-generated if internal |
| `ExecutionService_RedisCache_Password` | Execution service cache | Execution Service, Redis | Auto-generated if internal |
| `QueueService_internalCache_ConnectionString` | Distributed queue reader | Queue Reader | Auto-generated if internal |
| `QueueService_RedisCache_Password` | Distributed queue reader | Queue Reader, Redis | Auto-generated if internal |
| `QueueService_RabbitMQ_Password` | Distributed queue reader | Queue Reader, RabbitMQ | Auto-generated if internal |
| `SMTP_Password` | SMTP credentials | Interaction API, Execution Service | Only when `SMTPSettings.UseCredentials: true` |

> **Note:** Keys marked "Auto-generated if internal" are created by the chart when using chart-managed Redis or RabbitMQ. You only need to provide these if you set `autoCreateSecrets: false` and use internal (chart-managed) instances.

---

## 6. Configure Operational Database

> **Quick Start:** To skip external database setup entirely, use **demo mode** instead. Set `global.deployment.mode: demo` and point to the in-cluster databases — see [Demo Database Mode](../README.md#demo-database-mode). Demo mode is for development and evaluation only.

The [operational databases]("https://docs.redpointglobal.com/rpi/"admin-key-concepts) (`Pulse` and `Pulse_Logging`) store information necessary for RPI to function. Add the following to your overrides file:

```yaml
databases:
  operational:
    provider: sqlserver
    server_host: <my-server-host>
    server_username: <my-server-username>
    server_password: <my-server-password>
    pulse_database_name: <my-pulse-database-name>
    pulse_logging_database_name: <my-pulse-logging-database-name>
```

## 7. Configure Data Warehouse

> **Note:** Only required if your [data warehouse]("https://docs.redpointglobal.com/rpi/"supported-connectors#Supportedconnectors-Databaseplatforms) is Redshift or BigQuery. Both use ODBC drivers requiring a DSN configuration. After deployment, use `dsn=redshift` or `dsn=bigquery` as the connection string.

```yaml
datawarehouse:
  provider: redshift
  redshift:
    server: your_redshift_server_endpoint
    port: 5439
    database: my_redshift_db
    username: my_redshift_user
    password: my_redshift_password
```

For the selected provider, complete the appropriate `google` or `amazon` section under `cloudIdentity`.

> **Note:** If you require [RPI Realtime]("https://docs.redpointglobal.com/rpi/"rpi-realtime), complete [Configure Realtime](../README.md#configure-realtime) before proceeding.

## 8. Create Your Overrides File

Start from one of the provided examples in `deploy/values/`:

```bash
# Pick the closest match to your environment
cp deploy/values/azure/azure.yaml my-overrides.yaml   # Azure
cp deploy/values/aws/amazon.yaml my-overrides.yaml     # AWS
cp deploy/values/demo/demo.yaml my-overrides.yaml      # Demo/local
```

Replace all placeholder values with your actual values and remove any sections you don't need. See [readme-values.md](readme-values.md) for details on what each key does.

## 9. Install RPI

```bash
helm upgrade --install rpi ./chart \
  -f my-overrides.yaml \
  -n redpoint-rpi \
  --create-namespace
```

After successful installation, the command outputs release details:

```
╔══════════════════════════════════════════════════════════════════════╗
║                        DEPLOYMENT SUCCESSFUL!                        ║
╠══════════════════════════════════════════════════════════════════════╣
║ RPI 7.7.20260220.1524 has been successfully deployed                 ║
╚══════════════════════════════════════════════════════════════════════╝

• Release:    rpi
• Namespace:  redpoint-rpi
• Platform:   amazon
• Version:    7.7.20260220.1524
```

It may take 5-10 minutes for all services to fully initialize.

---

## Retrieve Client Endpoints

List the ingresses to get the URLs exposed by the load balancer:

```bash
kubectl get ingress --namespace redpoint-rpi
```

Once the load balancer is ready:

```
NAME           HOSTS                                  ADDRESS              PORTS     AGE
redpoint-rpi   rpi-deploymentapi.example.com          <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-interactionapi.example.com         <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-integrationapi.example.com         <Load Balancer IP>   80, 443   32d
redpoint-rpi   rpi-realtimeapi.example.com            <Load Balancer IP>   80, 443   32d
```

Create DNS records mapping each hostname to the load balancer IP, then access:

| Service | URL |
|---------|-----|
| Deployment Service | `https://rpi-deploymentapi.example.com` |
| Client | `https://rpi-interactionapi.example.com` |
| Integration API | `https://rpi-integrationapi.example.com` |
| Realtime API | `https://rpi-realtimeapi.example.com` |
| Callback API | `https://rpi-callbackapi.example.com` |
| Client Download | `https://rpi-interactionapi.example.com/api/deployment/download` |

## Download Client Executable

Download the RPI Client from the Post-release Product Updates section of the [RPI Release Notes]("https://docs.redpointglobal.com/rpi/"rpi-v7-6-release-notes#RPIv7.6releasenotes-Post-releaseproductupdates). Ensure the version matches your deployed RPI version.

---

## Post-Deployment Configuration

### Activate RPI License

```bash
ACTIVATION_KEY=<my-license-activation-key>
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
SYSTEM_NAME=<my-dev-rpi-system>

curl -X POST "https://$DEPLOYMENT_SERVICE_URL/api/licensing/activatelicense" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "ActivationKey": "'"$ACTIVATION_KEY"'",
    "SystemName": "'"$SYSTEM_NAME"'"
  }'
```

A successful activation returns `200 OK`.

### Install Cluster Operational Databases

```bash
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
INITIAL_ADMIN_USERNAME=coreuser
INITIAL_ADMIN_PASSWORD=.Admin123
INITIAL_ADMIN_EMAIL=coreuser@example.com

curl -X 'POST' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/installcluster?waitTimeoutSeconds=360" \
  -H 'accept: text/plain' \
  -H 'Content-Type: application/json' \
  -d '{
  "UseExistingDatabases": false,
  "CoreUserInitialPassword": "'"$INITIAL_ADMIN_PASSWORD"'",
  "SystemAdministrator": {
    "Username": "'"$INITIAL_ADMIN_USERNAME"'",
    "EmailAddress": "'"$INITIAL_ADMIN_EMAIL"'"
  }
}'
```

Check status:

```bash
curl -X 'GET' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/status" \
  -H 'accept: text/plain'
```

Wait for `"Status": "LastRunComplete"` to confirm success.

<details>
<summary>Example response</summary>

```json
{
  "DeploymentInstanceID": "default",
  "Status": "LastRunComplete",
  "PulseDatabaseName": "Pulse",
  "Messages": [
    "[2024-08-06 03:13:50] Install starting",
    "[2024-08-06 03:13:50] Deployment files already unpacked",
    "[2024-08-06 03:13:50] Operational Database Type: AmazonRDSSQL",
    "[2024-08-06 03:13:50] Pulse Database Name: Pulse",
    "[2024-08-06 03:13:50] Logging Database Name: Pulse_Logging",
    "[2024-08-06 03:13:50] Database Host: rpiopsmssqlserver",
    "[2024-08-06 03:13:50] Core user password has been provided",
    "[2024-08-06 03:13:50] Creating the databases",
    "[2024-08-06 03:13:50] Updating cluster details",
    "[2024-08-06 03:13:50] Loading Plugins",
    "[2024-08-06 03:13:55] Adding 'what is new'",
    "[2024-08-06 03:13:55] Setting sys admin details"
  ]
}
```

</details>

### Install Tenant Operational Databases

With the cluster deployed, add your first client. A JSON building tool is available at `https://$DEPLOYMENT_SERVICE_URL/clienteditor.html` to construct the payload.

```bash
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
TENANT_NAME=<my-rpi-client-name>
CLIENT_ID=00000000-0000-0000-0000-000000000000
DATAWAREHOUSE_PROVIDER=SQLServer
DATAWAREHOUSE_SERVER=<my-datawarehouse-server>
DATAWAREHOUSE_NAME=<my-datawarehouse-name>
DATAWAREHOUSE_USERNAME=<my-datawarehouse-username>
DATAWAREHOUSE_PASSWORD=<my-datawarehouse-password>

curl -X 'POST' \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/addclient?waitTimeoutSeconds=360" \
  -H 'accept: text/plain' \
  -H 'Content-Type: application/json' \
  -d "{
  \"Name\": \"$TENANT_NAME\",
  \"Description\": \"My RPI Client X\",
  \"ClientID\": \"$CLIENT_ID\",
  \"UseExistingDatabases\": false,
  \"DatabaseSuffix\": \"$TENANT_NAME\",
  \"DataWarehouse\": {
    \"ConnectionParameters\": {
      \"Provider\": \"$DATAWAREHOUSE_PROVIDER\",
      \"UseDatabaseAgent\": false,
      \"Server\": \"$DATAWAREHOUSE_SERVER\",
      \"DatabaseName\": \"$DATAWAREHOUSE_NAME\",
      \"IsUsingCredentials\": true,
      \"Username\": \"$DATAWAREHOUSE_USERNAME\",
      \"Password\": \"$DATAWAREHOUSE_PASSWORD\",
      \"SQLServerSettings\": {
        \"Encrypt\": true,
        \"TrustServerCertificate\": true
      }
    },
    \"DeploymentSettings\": {
      \"DatabaseMode\": \"SQL\",
      \"DatabaseSchema\": \"dbo\"
    }
  },
  \"TemplateTenant\": \"NoTemplateTenant\",
  \"StartupConfiguration\": {
    \"Users\": [
      \"coreuser\"
    ],
    \"FileOutput\": {
      \"UseGlobalSettings\": true
    }
  }
}"
```

Check status with `curl -X 'GET' "https://$DEPLOYMENT_SERVICE_URL/api/deployment/status"` and wait for `"Status": "LastRunComplete"`.

---

## Automated Post-Install (Alternative)

Instead of running the manual `curl` commands above, you can automate the entire post-install process by enabling the `postInstall` job in your overrides file:

```yaml
postInstall:
  enabled: true
  activationKey: "<my-license-activation-key>"
  systemName: "<my-rpi-system>"
  adminUsername: coreuser
  adminPassword: "<my-admin-password>"
  adminEmail: admin@example.com
  tenant:
    enabled: true
    name: "<my-tenant-name>"
    dataWarehouse:
      provider: SQLServer
      server: "<my-dw-server>"
      database: "<my-dw-database>"
      username: "<my-dw-username>"
      password: "<my-dw-password>"
```

The job runs automatically after `helm install` (and as an ArgoCD PostSync hook). It is idempotent — if the license is already activated or databases are already installed, those steps are skipped.

For production, use `existingSecret` to reference a pre-created Kubernetes Secret instead of inline values:

```yaml
postInstall:
  enabled: true
  existingSecret: rpi-postinstall-secrets   # keys: activation-key, admin-password, admin-username, admin-email
  systemName: "<my-rpi-system>"
```

### Pre-flight Validation

Enable the pre-flight job to validate your configuration (DNS resolution, database connectivity, cloud identity):

```yaml
preflight:
  enabled: true
  mode: test        # runs with `helm test rpi`
  # mode: preInstall  # blocks install on failure
```

After deploying, run:

```bash
helm test rpi -n redpoint-rpi
```

---

## Next Steps

After deployment, configure the optional features that apply to your environment:

- [Automatic Database Upgrades](../README.md#configure-automatic-database-upgrades)
- [Cloud Identity](../README.md#configure-cloud-identity)
- [Storage](../README.md#configure-storage)
- [Realtime](../README.md#configure-realtime)
- [Secrets Management](../README.md#configure-secrets-management)
- [Service Mesh](../README.md#configure-service-mesh)
- [Microsoft Entra ID](../README.md#configure-microsoft-entra-id)
- [Custom Metrics](../README.md#configure-custom-metrics)
- [Autoscaling](../README.md#configure-autoscaling)

See the [main README](../README.md) for all configuration options.

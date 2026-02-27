# New Installation (Greenfield)

[< Back to main README](../README.md)

This guide walks through deploying RPI from scratch in a new environment — new cluster, new databases, new cache and queue providers.

---

## Overview

1. Clone this repository
2. Create a Kubernetes namespace
3. Create secrets for image pull and TLS
4. Configure your operational database and data warehouse connections
5. Create your environment overrides file
6. Deploy with Helm
7. Activate your license and install databases

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
├── deployments/                  # Your environment overrides
│   ├── values-reference.yaml     # Complete reference of all keys
│   ├── dev.yaml
│   ├── staging.yaml
│   └── production.yaml
├── docs/                         # Deployment guides
│   ├── greenfield.md             # This file
│   └── migration.md              # v7.6 → v7.7 upgrade guide
├── readme-values.md              # Values & overrides guide
├── readme-argocd.md              # ArgoCD deployment guide
└── README.md
```

You deploy by passing a small overrides file containing only your customizations. Everything else uses chart defaults automatically. See [readme-values.md](../readme-values.md) for details.

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

## 5. Configure Operational Database

> **Quick Start:** To skip external database setup entirely, use **demo mode** instead. Set `global.deployment.mode: demo` and point to the in-cluster databases — see [Demo Database Mode](../README.md#demo-database-mode). Demo mode is for development and evaluation only.

The [operational databases](https://docs.redpointglobal.com/rpi/admin-key-concepts) (`Pulse` and `Pulse_Logging`) store information necessary for RPI to function. Add the following to your overrides file:

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

## 6. Configure Data Warehouse

> **Note:** Only required if your [data warehouse](https://docs.redpointglobal.com/rpi/supported-connectors#Supportedconnectors-Databaseplatforms) is Redshift or BigQuery. Both use ODBC drivers requiring a DSN configuration. After deployment, use `dsn=redshift` or `dsn=bigquery` as the connection string.

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

For the selected provider, complete the appropriate `googleSettings` or `amazonSettings` section under `cloudIdentity`.

> **Note:** If you require [RPI Realtime](https://docs.redpointglobal.com/rpi/rpi-realtime), complete [Configure Realtime](../README.md#configure-realtime) before proceeding.

## 7. Create Your Overrides File

Start from one of the provided examples in `deployments/`:

```bash
cp deployments/production.yaml my-overrides.yaml
```

Replace all `CHANGE_ME` placeholders with your actual values and remove any sections you don't need. See [readme-values.md](../readme-values.md) for details on what each key does.

## 8. Install RPI

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

Download the RPI Client from the Post-release Product Updates section of the [RPI Release Notes](https://docs.redpointglobal.com/rpi/rpi-v7-6-release-notes#RPIv7.6releasenotes-Post-releaseproductupdates). Ensure the version matches your deployed RPI version.

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

## Next Steps

After deployment, configure the optional features that apply to your environment:

- [Cloud Identity](../README.md#configure-cloud-identity)
- [Storage](../README.md#configure-storage)
- [Realtime](../README.md#configure-realtime)
- [Secrets Management](../README.md#configure-secrets-management)
- [Service Mesh](../README.md#configure-service-mesh)
- [Microsoft Entra ID](../README.md#configure-microsoft-entra-id)
- [Custom Metrics](../README.md#configure-custom-metrics)
- [Autoscaling](../README.md#configure-autoscaling)

See the [main README](../README.md) for all configuration options.

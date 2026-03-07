![redpoint_logo](../chart/images/logo.png)
# New Installation (Greenfield)

[< Back to main README](../README.md)

This guide walks through deploying RPI from scratch in a new environment, meaning new cluster, new databases, new cache and queue providers.

---

## Overview

1. Clone this repository
2. Create a Kubernetes namespace
3. Create the image pull and TLS secrets
4. Create the RPI secrets manifest
5. Create your overrides file
6. Deploy with Helm
7. Activate your license and install databases

---

## Quick Start with CLI Scaffolder

For a guided setup, use the interactive scaffolder:

```bash
bash deploy/cli/rpi-init.sh
```

This generates three files:

| File | Purpose |
|------|---------|
| `my-overrides.yaml` | Helm values overrides (no secrets) |
| `rpi-secrets.yaml` | Kubernetes Secret manifest with all required keys |
| `prereqs.sh` | kubectl commands for namespace, image pull, and TLS secrets |

After generation, review the files and deploy:

```bash
bash prereqs.sh
kubectl apply -f rpi-secrets.yaml
helm upgrade --install rpi ./chart -f my-overrides.yaml -n redpoint-rpi
```

You can skip the rest of this guide if you use the scaffolder.

---

## 1. Clone This Repository

```bash
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi
```

## 2. Create Kubernetes Namespace

```bash
kubectl create namespace redpoint-rpi
```

## 3. Create Image Pull and TLS Secrets

Obtain container registry credentials from [Redpoint Support](mailto:support@redpointglobal.com):

```bash
NAMESPACE=redpoint-rpi

kubectl create secret docker-registry redpoint-rpi \
  --namespace $NAMESPACE \
  --docker-server=rg1acrpub.azurecr.io \
  --docker-username=<your-username> \
  --docker-password=<your-password>

kubectl create secret tls ingress-tls \
  --namespace $NAMESPACE \
  --cert=./your_cert.crt \
  --key=./your_cert.key
```

## 4. Create the RPI Secrets Manifest

RPI reads sensitive values (database credentials, connection strings, API tokens) from a Kubernetes Secret — not from your values file. This keeps secrets out of version control and Helm release metadata.

Use the [CLI scaffolder](#quick-start-with-cli-scaffolder) to generate your `rpi-secrets.yaml` manifest. It prompts for your database credentials, cache and queue connection strings, and automatically generates a secure auth token — no manual YAML editing required.

```bash
bash deploy/cli/rpi-init.sh
```

The scaffolder produces a complete `rpi-secrets.yaml` with correctly formatted connection strings for your platform (Azure SQL, RDS, PostgreSQL). Review the generated file, then apply it:

```bash
kubectl apply -f rpi-secrets.yaml
```

> **Important:** The generated secret includes the `helm.sh/resource-policy: keep` annotation, which prevents Helm from deleting it on `helm uninstall`. This is intentional — secrets persist independently of Helm releases.

> **Warning:** `rpi-secrets.yaml` contains sensitive credentials. Do **not** commit it to version control. The `.gitignore` already excludes `*-secrets.yaml`.

<details>
<summary><strong>Secret Key Reference</strong> — All supported keys (click to expand)</summary>

The table below lists all keys the chart can read from the secret. The scaffolder generates the keys relevant to your platform automatically. Include additional keys only if your configuration requires them.

| Key | When Required | Description |
|-----|---------------|-------------|
| `ConnectionString_Operations_Database` | Always | Full connection string to the Pulse database |
| `ConnectionString_Logging_Database` | Always | Full connection string to the Pulse_Logging database |
| `Operations_Database_Server_Password` | Always | Database password |
| `Operations_Database_ServerHost` | Always | Database server hostname |
| `Operations_Database_Server_Username` | Always | Database username |
| `Operations_Database_Pulse_Database_Name` | Always | Pulse database name |
| `Operations_Database_Pulse_Logging_Database_Name` | Always | Pulse_Logging database name |
| `RealtimeAPI_Auth_Token` | Realtime enabled (basic auth) | API authentication token (auto-generated) |
| `RealtimeAPI_ServiceBus_ConnectionString` | Azure Service Bus queue | Service Bus connection string |
| `RealtimeAPI_EventHub_ConnectionString` | Azure Event Hubs queue | Event Hubs connection string |
| `RealtimeAPI_AzureStorage_ConnectionString` | Azure Storage queue | Storage account connection string |
| `RealtimeAPI_MongoCache_ConnectionString` | MongoDB cache | MongoDB connection string |
| `RealtimeAPI_RedisCache_ConnectionString` | Redis cache (external) | Redis connection string |
| `RealtimeAPI_inMemorySql_ConnectionString` | SQL Server in-memory cache | SQL Server connection string |
| `AWS_Access_Key_ID` | SQS without IRSA | Not needed when using IRSA |
| `AWS_Secret_Access_Key` | SQS without IRSA | Not needed when using IRSA |
| `SMTP_Password` | SMTP email credentials | Only when `SMTPSettings.UseCredentials: true` |

</details>

## 5. Create Your Overrides File

Start from the example that matches your platform:

```bash
cp deploy/values/azure/azure.yaml my-overrides.yaml   # Azure
cp deploy/values/aws/amazon.yaml my-overrides.yaml     # AWS
```

Your overrides file should contain **only non-sensitive configuration** — platform, database provider/host, cloud identity, ingress domain, realtime settings. All sensitive values (passwords, connection strings, tokens) are in the Kubernetes Secret you created in Step 4.

Set the secrets management to use your pre-created secret:

```yaml
secretsManagement:
  provider: kubernetes
  kubernetes:
    autoCreateSecrets: false
    secretName: redpoint-rpi-secrets
```

Replace all remaining `<placeholder>` values. See [readme-values.md](readme-values.md) for details on what each key does.

## 6. Install RPI

```bash
helm upgrade --install rpi ./chart \
  -f my-overrides.yaml \
  -n redpoint-rpi \
  --create-namespace
```

It may take 5-10 minutes for all services to fully initialize.

### Validate the deployment

```bash
# Enable preflight checks in your overrides:
#   preflight:
#     enabled: true
#     mode: test

helm test rpi -n redpoint-rpi
```

---

## Retrieve Client Endpoints

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

## Download Client Executable

Download the RPI Client from the Post-release Product Updates section of the [RPI Release Notes](https://docs.redpointglobal.com/rpi/rpi-v7-6-release-notes#RPIv7.6releasenotes-Post-releaseproductupdates). Ensure the version matches your deployed RPI version.

---

## 7. Post-Deployment: License and Database Setup

### Activate RPI License

```bash
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com
ACTIVATION_KEY=<my-license-activation-key>
SYSTEM_NAME=<my-rpi-system>

curl -X POST "https://$DEPLOYMENT_SERVICE_URL/api/licensing/activatelicense" \
  -H "Content-Type: application/json" \
  -d '{
    "ActivationKey": "'"$ACTIVATION_KEY"'",
    "SystemName": "'"$SYSTEM_NAME"'"
  }'
```

### Install Cluster Databases

```bash
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com

curl -X POST \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/installcluster?waitTimeoutSeconds=360" \
  -H "Content-Type: application/json" \
  -d '{
    "UseExistingDatabases": false,
    "CoreUserInitialPassword": "<my-admin-password>",
    "SystemAdministrator": {
      "Username": "coreuser",
      "EmailAddress": "admin@example.com"
    }
  }'
```

Check status with `curl "https://$DEPLOYMENT_SERVICE_URL/api/deployment/status"` — wait for `"Status": "LastRunComplete"`.

### Add Your First Tenant

A JSON builder is available at `https://$DEPLOYMENT_SERVICE_URL/clienteditor.html` to construct the payload.

```bash
DEPLOYMENT_SERVICE_URL=rpi-deploymentapi.example.com

curl -X POST \
  "https://$DEPLOYMENT_SERVICE_URL/api/deployment/addclient?waitTimeoutSeconds=360" \
  -H "Content-Type: application/json" \
  -d '{
    "Name": "<my-tenant-name>",
    "Description": "My RPI Tenant",
    "ClientID": "00000000-0000-0000-0000-000000000000",
    "UseExistingDatabases": false,
    "DatabaseSuffix": "<my-tenant-name>",
    "DataWarehouse": {
      "ConnectionParameters": {
        "Provider": "SQLServer",
        "Server": "<my-dw-server>",
        "DatabaseName": "<my-dw-database>",
        "IsUsingCredentials": true,
        "Username": "<my-dw-username>",
        "Password": "<my-dw-password>",
        "SQLServerSettings": { "Encrypt": true, "TrustServerCertificate": true }
      },
      "DeploymentSettings": { "DatabaseMode": "SQL", "DatabaseSchema": "dbo" }
    },
    "TemplateTenant": "NoTemplateTenant",
    "StartupConfiguration": {
      "Users": ["coreuser"],
      "FileOutput": { "UseGlobalSettings": true }
    }
  }'
```

---

## Next Steps

- [Cloud Identity](../README.md#configure-cloud-identity)
- [Realtime](../README.md#configure-realtime)
- [Autoscaling](../README.md#configure-autoscaling)
- [Service Mesh](../README.md#configure-service-mesh)
- [Custom Metrics](../README.md#configure-custom-metrics)

See the [main README](../README.md) for all configuration options.

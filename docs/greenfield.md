![redpoint_logo](../chart/images/redpoint.png)
# New Installation (Greenfield)

[< Back to main README](../README.md)

This guide walks through deploying RPI from scratch in a new environment, meaning new cluster, new databases, new cache and queue providers.

---

## Overview

1. Clone this repository
2. Run the Interaction CLI to generate secrets, overrides, and prerequisites
3. Run prerequisites and deploy with Helm
4. Validate the deployment
5. Activate your license and install databases

---

## 1. Clone This Repository

```bash
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi
```

## 2. Quick Start with the Interaction CLI

As a security best practice, the Kubernetes Secret containing sensitive values (database credentials, connection strings, API tokens) is created outside the chart. This keeps secrets out of version control and Helm release metadata.

The **Interaction CLI** generates this Secret manifest for you. It prompts for your database credentials, cache and queue connection strings, and produces a ready to apply `secrets.yaml`. No manual YAML editing required.

```bash
bash deploy/cli/interactioncli.sh
```

```
╔══════════════════════════════════════════════╗
║     ⚡ Redpoint Interaction CLI              ║
║        Deployment Generator for RPI          ║
╚══════════════════════════════════════════════╝

This tool generates the files needed to deploy
Redpoint Interaction (RPI) on Kubernetes.

```
After generation, review the files:

| File | Purpose |
|------|---------|
| 📄 `overrides.yaml` | Helm values overrides (excludes sensitive secret values)    |
| 🔑 `secrets.yaml`   | Kubernetes Secret manifest with all required keys           |
| 🚀 `prereqs.sh`     | kubectl commands for namespace, image pull, and TLS secrets |

And then deploy:

```bash
bash prereqs.sh
helm install redpoint-rpi ./chart -f overrides.yaml -n redpoint-rpi
```

The `prereqs.sh` script handles namespace creation, image pull secret, TLS secret, and applies `secrets.yaml` all in one step.

> **Warning:** `secrets.yaml` contains sensitive credentials. Do **not** commit it to version control. The `.gitignore` already excludes `*-secrets.yaml`.

<details>
<summary><strong>Secret Key Reference</strong>: All supported keys (click to expand)</summary>

The table below lists all keys the chart can read from the secret. The Interaction CLI generates the keys relevant to your platform automatically. Include additional keys only if your configuration requires them.

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

Your overrides file should contain **only non-sensitive configuration** such as platform, database provider/host, cloud identity, ingress domain, realtime settings. All sensitive values (passwords, connection strings, tokens) are in the Kubernetes Secret you created in Step 2

## 3. Validate the deployment

```bash
helm test rpi -n redpoint-rpi
```

---

## Retrieve Client Endpoints

```bash
kubectl get ingress --namespace redpoint-rpi
```

Once the load balancer is ready (where `<prefix>` is your hostname prefix and `<domain>` is your ingress domain):

```
NAME           HOSTS                                       ADDRESS              PORTS     AGE
redpoint-rpi   <prefix>-deploymentapi.<domain>              <Load Balancer IP>   80, 443   32d
redpoint-rpi   <prefix>-interactionapi.<domain>             <Load Balancer IP>   80, 443   32d
redpoint-rpi   <prefix>-integrationapi.<domain>             <Load Balancer IP>   80, 443   32d
redpoint-rpi   <prefix>-realtimeapi.<domain>                <Load Balancer IP>   80, 443   32d
```

Create DNS records mapping each hostname to the load balancer IP, then access:

| Service | URL |
|---------|-----|
| Deployment Service | `https://<prefix>-deploymentapi.<domain>` |
| Client             | `https://<prefix>-interactionapi.<domain>` |
| Integration API    | `https://<prefix>-integrationapi.<domain>` |
| Realtime API       | `https://<prefix>-realtimeapi.<domain>` |
| Callback API       | `https://<prefix>-callbackapi.<domain>` |

## Download Client Executable

Download the RPI Client from the Post-release Product Updates section of the [RPI Release Notes](https://docs.redpointglobal.com/rpi/rpi-v7-6-release-notes#RPIv7.6releasenotes-Post-releaseproductupdates). Ensure the version matches your deployed RPI version.

---

## Post-Deployment: License and Database Setup

###  Activate RPI License

```bash
DEPLOYMENT_SERVICE_URL=<prefix>-deploymentapi.<domain>
ACTIVATION_KEY=<my-license-activation-key>
SYSTEM_NAME=<my-rpi-system>

curl -X POST "https://$DEPLOYMENT_SERVICE_URL/api/licensing/activatelicense" \
  -H "Content-Type: application/json" \
  -d '{
    "ActivationKey": "'"$ACTIVATION_KEY"'",
    "SystemName": "'"$SYSTEM_NAME"'"
  }'
```

### 2. Install Cluster Databases

```bash
DEPLOYMENT_SERVICE_URL=<prefix>-deploymentapi.<domain>

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
DEPLOYMENT_SERVICE_URL=<prefix>-deploymentapi.<domain>

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

## Adding Features

The Interaction CLI offers optional features (SMTP, storage, Redpoint AI, etc.) in two ways:

1. **During initial setup** — after generating your base config, the CLI walks through each available feature and lets you include it in one go.
2. **After deployment** — add features to an existing overrides file at any time:

```bash
bash deploy/cli/interactioncli.sh -a redpoint_ai    # add a specific feature
bash deploy/cli/interactioncli.sh -a menu           # interactive feature picker
```

Either way, the CLI prompts for the required values, appends the configuration block to your `overrides.yaml`, and reminds you of any secret keys to add. Then redeploy:

```bash
helm upgrade rpi ./chart -f overrides.yaml -n redpoint-rpi
```

Available features: `database_upgrade`, `queue_reader`, `autoscaling`, `custom_metrics`, `service_mesh`, `smoke_tests`, `entra_id`, `oidc`, `smtp`, `redpoint_ai`, `storage`, `helm_copilot`, `secrets_management`.

## Next Steps

See the **[Configuration Reference](readme-configuration.md)** for details on each feature, or [values-reference.yaml](values-reference.yaml) for every available key.

![redpoint_logo](../chart/images/redpoint.png)
# New Installation (Greenfield)

[< Back to main README](../README.md)

This guide walks through deploying RPI from scratch in a new environment, meaning new cluster, new databases, new cache and queue providers.

---

<details>
<summary><strong>Step 1: Generate Your Overrides</strong></summary>

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com):

1. Go to the **Generate** tab, select your platform and features, and download `overrides.yaml`
2. Download the **Interaction CLI** from the same page
3. Continue to Step 2

</details>

<details>
<summary><strong>Step 2: Generate Secrets and Deploy</strong></summary>

With your `overrides.yaml` downloaded, use the CLI to generate secrets and deploy.

**Generate secrets** from your overrides file. The CLI reads the configuration, determines which credentials are needed, and prompts only for those:

```bash
bash interactioncli.sh secrets -f overrides.yaml
```

**Deploy** to your cluster. The CLI clones the chart repository automatically, applies secrets, and runs Helm install with live rollout monitoring:

```bash
bash interactioncli.sh deploy -f overrides.yaml
```

To preview the rendered manifests first:

```bash
bash interactioncli.sh deploy -f overrides.yaml --dry-run
```

> **Warning:** `secrets.yaml` contains sensitive credentials. Do **not** commit it to version control. The `.gitignore` already excludes `*-secrets.yaml`.

Your overrides file should contain **only non-sensitive configuration** such as platform, database provider/host, cloud identity, ingress domain, realtime settings. All sensitive values (passwords, connection strings, tokens) are in the Kubernetes Secret.

<details>
<summary><strong>Secret Key Reference</strong>: All supported keys (click to expand)</summary>

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

</details>

<details>
<summary><strong>Step 3: Validate and Retrieve Endpoints</strong></summary>

Run the Helm test suite to verify all services are healthy:

```bash
helm test rpi -n redpoint-rpi
```

### Retrieve Ingress Endpoints

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

### Download Client Executable

Download the RPI Client from the Post-release Product Updates section of the [RPI Release Notes](https://docs.redpointglobal.com/rpi/rpi-v7-6-release-notes#RPIv7.6releasenotes-Post-releaseproductupdates). Ensure the version matches your deployed RPI version.

</details>

---

## Post-Deployment: License and Database Setup

### Activate RPI License

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

### Install Cluster Databases

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

Check status with `curl "https://$DEPLOYMENT_SERVICE_URL/api/deployment/status"`. Wait for `"Status": "LastRunComplete"`.

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

## Adding Features After Deployment

To add features to an existing deployment, update your `overrides.yaml` in the Web UI (or manually) and redeploy:

```bash
bash interactioncli.sh deploy -f overrides.yaml
```

Alternatively, the CLI can add individual features interactively:

```bash
bash interactioncli.sh -a menu           # interactive feature picker
bash interactioncli.sh -a redpoint_ai    # add a specific feature
```

The CLI prompts for the required values, appends the configuration block to your `overrides.yaml`, and reminds you of any secret keys to add.

## Next Steps

See the **[Configuration Reference](readme-configuration.md)** for details on each feature, or [values-reference.yaml](values-reference.yaml) for every available key.

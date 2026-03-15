![redpoint_logo](../chart/images/redpoint.png)
# New Installation (Greenfield)

[< Back to main README](../README.md)

This guide walks through deploying RPI from scratch in a new environment, meaning new cluster, new databases, new cache and queue providers.

---

## System Requirements

| Component | Requirement |
|:----------|:------------|
| **Kubernetes** | Latest stable version from a [certified provider](https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/). Minimum two nodes (8 vCPU, 32 GB RAM each). |
| **Operational DB** | SQL Server or PostgreSQL (cloud-hosted or VM). Minimum 8 GB RAM, 200 GB disk. |
| **CLI Tools** | `kubectl`, `helm` v3, `python3` (with PyYAML), `git`, `bash` |

**Example node SKUs:**

| Azure | AWS | GCP |
|-------|-----|-----|
| D8s_v5 | m5.2xlarge | n2-standard-8 |

## Prerequisites

Before starting, ensure you have:

- **Redpoint Container Registry**: Open a [Support](mailto:support@redpointglobal.com) ticket requesting access to download RPI images.
- **RPI License**: Open a [Support](mailto:support@redpointglobal.com) ticket to obtain your RPI v7 license activation key.

---

## Get Started

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) for a guided deployment experience. The Web UI walks you through the entire process:

| Tab | What it does |
|-----|-------------|
| **Generate** | Select your platform, configure features step by step, and preview your overrides file in real time |
| **Validate** | Review the generated configuration for errors or warnings, then download `overrides.yaml` |
| **Deploy** | Download the CLI, generate secrets, deploy to your cluster, retrieve endpoints, and activate your license |
| **Chat** | Ask questions about RPI features, configuration, or troubleshooting in plain English |

---

## Quick Reference: CLI Commands

After generating your overrides from the Web UI, these are the commands you'll run:

```bash
# Generate secrets (prompts for passwords and connection strings)
bash interactioncli.sh secrets -f overrides.yaml

# Deploy to cluster (clones chart, applies secrets, runs Helm install)
bash interactioncli.sh deploy -f overrides.yaml

# Verify deployment
helm test rpi -n redpoint-rpi

# Check status
bash interactioncli.sh status -n redpoint-rpi
```

<details>
<summary><strong>Secret Key Reference</strong> (click to expand)</summary>

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
| `SMTP_Password` | SMTP email credentials | Only when `SMTPSettings.UseCredentials: true` |

</details>

## Adding Features After Deployment

Update your `overrides.yaml` in the Web UI and redeploy:

```bash
bash interactioncli.sh deploy -f overrides.yaml
```

## Next Steps

See the **[Configuration Reference](readme-configuration.md)** for details on each feature, or [values-reference.yaml](values-reference.yaml) for every available key.

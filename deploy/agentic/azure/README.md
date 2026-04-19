![redpoint_logo](../../../chart/images/redpoint.png)
# Agentic Deployment on Azure

[< Back to Home](../../../README.md)

Deploy Redpoint Interaction (RPI) on Azure using the RPI Deploy Agent. The agent provisions infrastructure, deploys the Helm chart, initializes the cluster, and delivers a running environment.

---

## Prerequisites

| Requirement | Details |
|:------------|:--------|
| **Azure subscription** | Contributor access |
| **VM quota** | Min 16 vCPUs of D-series in the target region (for AKS Automatic) |
| **Container images** | Mirrored to your registry (ACR or other) |
| **Image pull secret** | Created in the target namespace before deploying |
| **TLS certificate** | Uploaded to Key Vault (the agent syncs it to the cluster via CSI) |

If deploying into an existing VNet, you also need:
- AKS subnet (min /16)
- AGC subnet (min /24, delegated to `Microsoft.ServiceNetworking/trafficControllers`)
- PE subnet (min /24)
- Private DNS zones for `privatelink.database.windows.net`, `privatelink.vaultcore.azure.net`, `privatelink.servicebus.windows.net`, `privatelink.file.core.windows.net`

---

<details>
<summary><strong style="font-size:1.25em;">Setup</strong></summary>

### Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude
```

Sign in when prompted. See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for details.

### Connect to the RPI Helm Assistant

Run this once. It saves the connection globally:

```bash
claude mcp add rpi-helm --transport http https://rpi-helm-assistant.redpointcdp.com/mcp --scope user
```

Verify:

```bash
claude mcp list
```

You should see `rpi-helm` with status Connected.

</details>

<details>
<summary><strong style="font-size:1.25em;">Deploy</strong></summary>

Tell the agent what you need:

```bash
/deploy-rpi Deploy RPI on Azure in East US 2, SQL Server, Realtime API with MongoDB cache and Service Bus, private ingress on mycompany.com
```

More examples:

```bash
/deploy-rpi Deploy RPI on Azure with PostgreSQL, existing VNet, private endpoints, and Realtime with Redis cache
```

```bash
/deploy-rpi Deploy RPI on Azure in West Europe, SQL Server, no Realtime, public ingress on example.com
```

The agent works through six phases:

| Phase | What happens |
|:------|:-------------|
| 0. Infrastructure | Provisions AKS Automatic, Azure SQL, Key Vault, Service Bus, Application Gateway for Containers, Storage, and Private Endpoints |
| 1-2. Discover + Pre-check | Gathers requirements, verifies cluster connectivity, identity, vault keys, and ingress readiness |
| 3. Generate | Produces Helm overrides (SDK mode, AGC ingress, no credentials in the file) |
| 4. Deploy | Runs `helm install`, monitors pod startup, diagnoses and fixes failures |
| 5. Validate | Creates databases and schema, initializes admin user, creates the first tenant |
| 6. Handoff | Stores all credentials in Key Vault, generates a branded HTML report with secret names and next steps |

</details>

<details>
<summary><strong style="font-size:1.25em;">Infrastructure Created</strong></summary>

| Resource | Name Pattern | Purpose |
|:---------|:-------------|:--------|
| Resource Group | `rg-rpi-{6char}` | Contains all resources |
| AKS Automatic | `aks-rpi-{6char}` | Kubernetes with Workload Identity and CSI Secret Store |
| Managed Identity | `id-rpi-{6char}` | Pod authentication to Key Vault |
| Azure SQL Server | `sql-rpi-{6char}` | Operational and Logging databases |
| Key Vault | `kv-rpi-{6char}` | All app secrets (SDK mode) |
| Service Bus | `sb-rpi-{6char}` | Standard tier with 6 RPI queues |
| Storage Account | `strpi{6char}` | Azure Files for file output |
| App Gateway for Containers | `agc-rpi-{6char}` | Ingress with TLS termination |
| Private Endpoints | 4 PEs | SQL, Key Vault, Service Bus, Storage |
| VNet (if new) | `vnet-rpi-{6char}` | AKS (/16), AGC (/24), PE (/24) subnets |

The `{6char}` suffix is a deterministic hash from `subscription + location + environmentName`. Same inputs always produce the same names (idempotent).

Existing infrastructure is also supported. Set `useExistingCluster`, `useExistingDatabase`, or `useExistingServiceBus` in the Bicep parameters to skip creation. The agent stores placeholder values in Key Vault for any existing resources. You update the placeholders with your actual connection details after deployment.

</details>

<details>
<summary><strong style="font-size:1.25em;">Security</strong></summary>

| Concern | How it works |
|:--------|:-------------|
| App secrets | Stored in Key Vault. Pods read them at runtime via Workload Identity (SDK mode). |
| Database credentials | Created during infrastructure provisioning and stored in Key Vault. Rotate after deployment. |
| Image pull secret | You create it before deploying. The agent verifies it exists. |
| TLS certificate | Stored in Key Vault. Synced to a K8s Secret (`ingress-tls`) via CSI Secret Store driver. |
| Internal passwords (Redis, RabbitMQ) | Auto-generated by the Helm chart. |
| Admin password | Auto-generated during cluster install. Stored in Key Vault as `RPI-Admin-Password`. |
| Ingress | Application Gateway for Containers. No chart-managed NGINX. |

The agent never asks for, handles, or logs credential values. It verifies Key Vault key names exist without reading their values. All commands execute locally on your machine.

</details>

<details>
<summary><strong style="font-size:1.25em;">Key Vault Secrets</strong></summary>

### Auto-populated by Bicep (infrastructure provisioning)

| Secret | Description |
|:-------|:------------|
| `ConnectionString-Operations-Database` | Operational DB connection string |
| `ConnectionString-Logging-Database` | Logging DB connection string |
| `Operations-Database-Server-Password` | Database password |
| `Operations-Database-ServerHost` | Database server hostname |
| `Operations-Database-Server-Username` | Database username |
| `Operations-Database-Pulse-Database-Name` | Operational database name |
| `Operations-Database-Pulse-Logging-Database-Name` | Logging database name |
| `SMTP-Password` | SMTP password (empty by default) |
| `RealtimeAPI-ServiceBus-ConnectionString` | Service Bus connection string (if created by Bicep) |
| `RealtimeAPI-MongoCache-ConnectionString` | MongoDB connection string (if internal container deployed) |

### Auto-populated by the agent (Phase 5)

| Secret | Description |
|:-------|:------------|
| `RPI-Admin-Username` | Initial admin user (`coreuser`) |
| `RPI-Admin-Password` | Initial admin password. Change after first login. |
| `RealtimeAPI-Auth-Token` | Realtime API auth token (UUID format) |
| `RPI-Tenant-ClientID` | First tenant client ID |
| `RPI-Tenant-Name` | First tenant name |
| `RPI-License-ActivationKey` | Placeholder. Update with your actual key after deployment. |

### You provide after deployment

| Secret | Description |
|:-------|:------------|
| `RPI-License-ActivationKey` | Update with your actual license activation key, then run `/deploy-rpi resume` |

Retrieve credentials:

```bash
az keyvault secret show --vault-name <kv-name> --name RPI-Admin-Password --query value -o tsv
```

</details>

<details>
<summary><strong style="font-size:1.25em;">License Activation (Resume Mode)</strong></summary>

After deployment, the Execution Service and Node Manager will be unhealthy until the license is activated. The agent defers license activation because the key is typically not available at deployment time.

Once you have the license key:

```bash
# Store the key in Key Vault
az keyvault secret set --vault-name <kv-name> --name RPI-License-ActivationKey --value <your-key>

# Run the agent in resume mode
/deploy-rpi resume
```

The agent reads the key from Key Vault, activates the license, and verifies all services become healthy.

Additional resume commands:

```bash
/deploy-rpi resume                     # Activate license
/deploy-rpi resume add-tenant <name>   # Add another tenant
/deploy-rpi resume status              # Check deployment health
```

</details>

---

## Files

```
deploy/agentic/azure/
  main.bicep              Subscription-scoped orchestrator
  identity.bicep          Managed Identity
  resources.bicep         AKS, SQL, KV, SB, AGC, Storage, VNet
  private-endpoints.bicep PEs and DNS zone groups
  dns-records.bicep       A records for ingress (private or public DNS)
  parameters.json         Defaults for Bicep parameters
  README.md               This file
```

## Cleanup

```bash
az group delete --name rg-rpi-<6char> --yes --no-wait
```

---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

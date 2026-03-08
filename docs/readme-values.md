![redpoint_logo](../chart/images/redpoint.png)
# Configuring Redpoint RPI

[< Back to main README](../README.md)

## How It Works

The RPI Helm chart uses a **two-tier values system** that separates what you need to set from what the chart manages internally.

| File | Purpose | You edit? |
|------|---------|-----------|
| `chart/values.yaml` | Chart defaults for user-facing settings | No |
| `chart/templates/_defaults.tpl` | Internal defaults managed by the chart | No |
| `docs/values-reference.yaml` | Complete reference of every possible key and its default | No (read-only reference) |
| `deploy/values/azure/azure.yaml` | Azure environment example | Yes |
| `deploy/values/aws/amazon.yaml` | AWS environment example | Yes |
| `deploy/values/demo/demo.yaml` | Demo/dev environment example | Yes |

You maintain a small per-environment overrides file with only the values you've customized. Everything else uses sensible defaults that the chart manages for you.

## Repository Structure

```
redpoint-rpi/
├── chart/                        # The Helm chart (don't edit)
│   ├── Chart.yaml
│   ├── values.yaml               # User-facing defaults
│   └── templates/
│       ├── _defaults.tpl         # Internal defaults
│       ├── _helpers.tpl          # Merge helpers
│       └── deploy-*.yaml         # Resource templates
├── deploy/
│   └── values/                   # Your environment overrides
│       # Per-platform override examples
│       ├── azure/azure.yaml      # Azure example
│       ├── aws/amazon.yaml       # AWS example
│       └── demo/demo.yaml        # Demo/dev example
├── docs/
│   ├── readme-values.md          # This file
│   └── readme-argocd.md          # ArgoCD deployment guide
└── README.md
```

## Quick Start

1. Copy the appropriate environment file from `deploy/values/` as your starting point.
2. Replace all `CHANGE_ME` placeholders with your actual values.
3. Remove any sections you don't need.
4. Deploy:

```bash
# Demo/Dev
helm upgrade --install rpi ./chart -f deploy/values/demo/demo.yaml -n rpi-dev --create-namespace

# Azure
helm upgrade --install rpi ./chart -f deploy/values/azure/azure.yaml -n redpoint-rpi --create-namespace

# AWS
helm upgrade --install rpi ./chart -f deploy/values/aws/amazon.yaml -n redpoint-rpi --create-namespace
```

### Starting from Scratch

If the example files don't match your setup, create a minimal overrides file. It can be as small as:

```yaml
global:
  deployment:
    platform: azure
    images:
      tag: "7.7.20260220.1524"

databases:
  operational:
    provider: sqlserver
    server_host: mydb.database.windows.net
    server_username: rpi_admin
    server_password: $ecureP@ss
    pulse_database_name: RPIPulse
    pulse_logging_database_name: RPILogging

realtimeapi:
  enabled: true
  replicas: 2
  cacheProvider:
    provider: mongodb
    mongodb:
      connectionString: mongodb+srv://user:pass@cluster.mongodb.net/Pulse

ingress:
  domain: rpi.example.com
```

Health probes, security contexts, logging levels, service ports, rollout strategies, and everything else uses chart defaults automatically.

## Environment Differences

The provided example files demonstrate a typical pattern:

| Setting | `dev.yaml` | `staging.yaml` | `production.yaml` |
|---------|-----------|---------------|-------------------|
| Platform | selfhosted | amazon | amazon |
| Database mode | standard (demo available) | standard | standard |
| Replicas | 1 | 1 | 2-3 |
| Resources | 100m CPU / 512Mi | 500m CPU / 2Gi | 1 CPU / 4Gi |
| Autoscaling | Disabled | Disabled | Enabled |
| Logging | Debug (all services) | Debug (core services) | Default (Error) |
| Probes | Relaxed (slow startup) | Default | Default |
| Queue provider | RabbitMQ (internal) | Amazon SQS | Amazon SQS |
| Node scheduling | Disabled | Disabled | Enabled with taints |
| SMTP | localhost:1025 (MailHog) | SES | SES |
| Swagger | Enabled | Default | Default |

Add more environment files as needed (e.g., `qa.yaml`, `dr.yaml`). Each file is self-contained.

## The `advanced:` Block

Every internal default can be overridden without forking the chart. Use the `advanced:` block at the bottom of your overrides file.

### Finding Available Keys

Open `docs/values-reference.yaml` and scroll to the `advanced:` section at the bottom. Every key is documented with its default value shown as commented-out YAML.

### Examples

**Change liveness probe timing for all services:**

```yaml
advanced:
  livenessProbe:
    periodSeconds: 30
    failureThreshold: 5
```

**Enable debug logging for the realtime API:**

```yaml
advanced:
  realtimeapi:
    logging:
      realtimeapi:
        default: Debug
        endpoint: Debug
```

**Increase data map retention to 2 years:**

```yaml
advanced:
  realtimeapi:
    dataMaps:
      visitorProfile:
        DaysToPersist: 730
      visitorHistory:
        DaysToPersist: 730
```

**Change execution service job timeout and thread count:**

```yaml
advanced:
  executionservice:
    jobExecution:
      taskTimeout: 120
      maxThreadsPerExecutionService: 200
```

**Override security context for a specific component:**

```yaml
advanced:
  authservice:
    securityContext:
      runAsUser: 1000
      fsGroup: 1000
```

**Switch a service to Argo Rollouts blue-green deployment:**

```yaml
advanced:
  realtimeapi:
    type: rollout
    rollout:
      autoPromotionEnabled: false
```

**Enable Prometheus metrics scraping:**

```yaml
advanced:
  realtimeapi:
    customMetrics:
      enabled: true
      prometheus_scrape: true
```

**Add per-service pod annotations (e.g., for Linkerd):**

```yaml
executionservice:
  podAnnotations:
    config.linkerd.io/skip-outbound-ports: "443"
    config.linkerd.io/proxy-outbound-connect-timeout: "240000ms"
interactionapi:
  podAnnotations:
    config.linkerd.io/skip-outbound-ports: "443"
```

**Enable demo database mode for development:**

```yaml
global:
  deployment:
    mode: demo
    platform: selfhosted

databases:
  operational:
    server_host: rpi-demo-mssql
    server_username: sa
    # Password is auto-generated — retrieve from rpi-demo-mode secret
    server_password: RETRIEVE_FROM_SECRET
```

### How Merging Works

Values are resolved in three layers, with later layers winning:

```
Chart defaults  →  Your top-level values  →  advanced overrides
(_defaults.tpl)    (X)                       (advanced.X)
```

The `advanced:` block always takes the highest priority — use it to override any value, including ones set at the top level.

For example, with this overrides file:

```yaml
realtimeapi:
  replicas: 3
  resources:
    requests:
      cpu: 500m
      memory: 3Gi

advanced:
  realtimeapi:
    resources:
      requests:
        cpu: 50m
        memory: 256Mi
    logging:
      realtimeapi:
        default: Debug
```

The resolved realtimeapi config will have:
- `replicas: 3` — from your top-level value
- `resources.requests.cpu: 50m` — from advanced (overrides top-level)
- `resources.requests.memory: 256Mi` — from advanced (overrides top-level)
- `logging.realtimeapi.default: Debug` — from your advanced override
- `service.port: 80` — from chart default
- `terminationGracePeriodSeconds: 120` — from chart default
- Everything else — from chart defaults

You only specify what you change. Unset keys always use the chart's defaults.

## Benefits

### Simpler Upgrades

When you upgrade the chart version, new defaults apply automatically. You don't need to diff a 2,600-line file to find what changed — your overrides file only contains your customizations, and they carry forward cleanly.

### Smaller Configuration

A typical deployment needs 50-100 lines instead of 2,600. Less to read, less to review, less to get wrong.

### No Drift

Because you never copy the full defaults, your configuration can't silently drift from the chart's intended values. Bug fixes to default probe timings, security contexts, or resource settings apply on the next upgrade without any action on your part.

### Safe Escape Hatch

The `advanced:` block gives you full control when you need it, without cluttering your day-to-day configuration. Every internal default is overridable — nothing is locked away.

## Migrating from the Previous values.yaml

If you have an existing deployment with a full copy of the old `values.yaml`:

1. **Identify your customizations.** Diff your current file against the chart's original `values.yaml` to find values you actually changed.

2. **Start from an example.** Copy `deploy/values/azure/azure.yaml` (or the AWS/demo equivalent) and fill in your values.

3. **Move hidden defaults to `advanced:`.** If you customized values that are no longer top-level (like health probes, security contexts, logging levels, or service ports), place them under `advanced:`:

   ```yaml
   # Before (old values.yaml):
   livenessProbe:
     periodSeconds: 30

   securityContext:
     runAsUser: 1000

   # After (new overrides file):
   advanced:
     livenessProbe:
       periodSeconds: 30
     securityContext:
       runAsUser: 1000
   ```

4. **Test with `helm template`** to verify your rendered manifests match the previous deployment:

   ```bash
   helm template rpi ./chart -f my-overrides.yaml > rendered.yaml
   ```

5. **Compare** the rendered output against your current running manifests, then apply with `helm upgrade`.

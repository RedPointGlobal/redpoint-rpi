![redpoint_logo](../chart/images/redpoint.png)
# RPI Observability

[< Back to Home](../README.md)

![RPI Observability dashboard](../chart/images/dashboard_card.jpg)

## Overview

**RPI Observability** is the operations component for RPI. It reads recent error rows from Pulse Logging, groups identical errors together, produces a per-cycle report (what is failing, where, how often), and surfaces it through a dashboard, an HTML email digest, and a Microsoft Teams Adaptive Card. Alongside the cycle reports it provides live system-health (pods + nodes), per-Interaction diagnostics with a downloadable bundle, and an optional auth + capability layer that integrates with the rest of the RPI trust domain.

It is built for SRE and operations teams who want a single operations view of error activity across services, tenants, plugins, and hosts, plus the ability to drill into a specific Interaction for diagnostics. It does not replace your APM, metrics, or paging stack -- it complements them with a scheduled (interval or daily) digest plus a small dashboard for follow-up investigation.

The component runs in the same cluster and namespace as the rest of the RPI services. It connects to Pulse Logging using the chart's existing operational database credentials and writes its own report history to a local SQLite database on a dedicated volume.

---

<details>
<summary><strong style="font-size:1.25em;">Prerequisites</strong></summary>

Provision the model backend before turning on the observability component. Pick one provider. The model is called per cycle (not per error row), so traffic is light, but the resource has to exist and be reachable from the cluster.

### Azure (Azure OpenAI / AI Foundry)

- Azure OpenAI or AI Foundry resource with a model deployment (for example, a `gpt-5` deployment).
- Endpoint, API version, and deployment name. Read via the chart-wide `redpointAI.naturalLanguage` block (`ApiBase`, `ApiVersion`, `ChatGptEngine`).
- API key in `redpoint-rpi-secrets` under `RPI_NLP_API_KEY`.
- Network egress to the OpenAI endpoint. Private Endpoint is supported.

### AWS (Bedrock)

- Bedrock service in the target region (model availability varies by region).
- **Model access approved** for the `modelId` you plan to use.
- `bedrock:InvokeModel` granted on the target model ARN to the IAM role from `cloudIdentity.amazon.roleArn`. The component rides the chart's standard IRSA / EKS Pod Identity binding.
- Network egress to `bedrock-runtime.<region>.amazonaws.com`. PrivateLink is supported.

### GCP (Vertex AI)

- Vertex AI API enabled on the project.
- For Anthropic-on-Vertex: model access enabled.
- `roles/aiplatform.user` (or narrower `aiplatform.endpoints.predict`) on the GCP service account from `cloudIdentity.google.serviceAccountEmail`. The component rides the chart's standard Workload Identity binding.
- Network egress to `<region>-aiplatform.googleapis.com`.

</details>

<details>
<summary><strong style="font-size:1.25em;">What it does</strong></summary>

Each cycle:

1. Queries Pulse Logging for rows logged in the lookback window (60 minutes in interval mode, 24 hours in daily mode).
2. Filters rows below the configured severity floor.
3. Groups errors by their root pattern. Volatile content (timestamps, IDs, IPs, paths) is stripped before grouping so variants of the same underlying error land together.
4. Aggregates totals by service, tenant, plugin, and host.
5. For each cluster, asks the configured model to produce a short explanation and a suggested fix; also asks for a 2-4 sentence summary of the cycle as a whole.
6. Persists the full report to a local SQLite store.
7. Marks each error type as `new`, `recurring`, or `resolved`. An error is `new` the first time it ever appears in any report; after that it is `recurring`. An error is `resolved` if it was in the previous report but is not in the current one.
8. Sends an HTML email digest and a Teams Adaptive Card if either channel is enabled and the trigger gates pass.

Outside the cycle the component also serves:

- **System Health** -- live pod and node state from the Kubernetes API (and metrics-server when present), so operators can correlate workload health with error activity.
- **Diagnostics** -- per-Interaction lookup with SQL trace timeline, audit timeline, application logs, and a downloadable bundle (parity with the on-prem "Download Diagnostics" zip).
- **Authentication and capability-based authorization** -- opt-in trust-domain participation that gates sensitive surfaces by capability (see "Authentication" below).

The dashboard at `https://<your-ingress>/` is the primary entry point.

</details>

<details>
<summary><strong style="font-size:1.25em;">How it works</strong></summary>

### Schedule modes

Two scheduling modes:

| Mode | When it fires | Use case |
|:-----|:--------------|:---------|
| **Interval** (default) | Every `intervalMinutes` after pod startup | Active monitoring, short reaction time |
| **Daily** | Once a day at `dailyAtUtc` (`HH:MM` UTC) | Operations digest at a fixed time |

In daily mode the lookback window auto-defaults to 24 hours so consecutive cycles cover the full day. Daily mode also bypasses `onlyOnNewErrors` on email and Teams: if you opted into a daily summary, you get it every day even on quiet days.

The **Run analysis now** button in the sidebar (and `POST /api/analyze`) fires an off-schedule cycle. Same downstream code path. When auth is enabled, this requires the `analyzer.admin` capability.

### Single-instance deployment contract

RPI Observability is **single-instance by design**. The component is one StatefulSet with `replicas: 1` and the chart rejects any attempt to override this. The single-instance shape is the architectural contract, not an accidental limitation.

What lives in the pod:

| In-pod state | Why it is single-instance |
|:-------------|:--------------------------|
| Local SQLite report store at `/data/reports.db` | One filesystem, one writer; no shared-state coordination. |
| In-process cycle scheduler | One scheduler per deployment; coordination would be required across replicas. |
| In-process authorization cache | TTL-based; per-pod is fine because there is one pod. |
| In-process token-budget bucket | Hourly cap is enforced per-pod because there is one pod. |
| Namespace-scoped K8s collectors | Bound to `Release.Namespace` via downward API. |

The chart will fail to render if `observability.replicas` is set. Multi-replica deployments are a v2 concern; do not set `replicas` in your overrides.

### Storage

Report history lives in SQLite at `/data/reports.db`. This path is canonical: it is the same in-cluster and out-of-cluster, and it is not environment-dependent. The chart mounts a persistent volume at `/data` (StatefulSet `volumeClaimTemplates` named `rpi-observability-data`, or `storage.existingClaim` if you bring your own PVC). The application reads `OBSERVABILITY__SQLITE_PATH` only as an explicit override; if you do not set the override, both the chart and the application agree on `/data/reports.db`.

SQLite needs a filesystem that honors POSIX byte-range locks, so `/data` must be backed by block storage (Azure Disk, AWS EBS, GCP PD). Network shares (Azure Files, NFS) will not work -- their lock semantics break SQLite.

When `diagnostics.fileOutput.enabled` is true and the chart-wide `storage.persistentVolumeClaims.FileOutputDirectory` PVC exists, that PVC is also mounted read-only at `/rpifileoutputdir` so diagnostic bundles can include the workflow's output files.

### AI deployment postures

AI inference is a deployment-posture decision: where inference runs, who operates it, where log data lives. The user experience is identical across postures; only the deployment architecture differs.

| Posture | What it is | Privacy boundary | Operational ownership |
|:--------|:-----------|:-----------------|:----------------------|
| **`helmAssistant`** (default, turnkey) | Inference runs on the Redpoint-hosted control plane. Redacted, clustered error data is shipped over HTTPS; structured AI summaries come back. Zero customer AI infrastructure required. | redacted samples leave the cluster | Redpoint-managed |
| **`localLlm`** (private, packaged) | Inference runs in-cluster via the chart-shipped Ollama deployment. No log data leaves the customer network. | nothing leaves the cluster | customer (in-cluster) |
| **`byo`** (customer-managed) | Inference runs on a customer-managed AI platform (`anthropic`, `azureFoundry`, `bedrock`, `vertex`). Auth piggybacks on the chart's existing `cloudIdentity` helpers. | customer-managed | customer |

For `byo`:

| `byo.platform` | Configuration |
|:---------------|:--------------|
| `anthropic` | API key in the cloud vault under `Observability-AnthropicApiKey`. |
| `azureFoundry` | Reuses chart-wide `redpointAI.naturalLanguage` (`ApiBase`, `ApiVersion`, `ChatGptEngine`). |
| `bedrock` | Auth via `cloudIdentity.amazon` (IRSA / EKS Pod Identity). Permission: `bedrock:InvokeModel`. |
| `vertex` | Auth via `cloudIdentity.google` (Workload Identity). Permission: `aiplatform.endpoints.predict`. |

The model is called per cycle, not per row. Rate limits are enforced via `budget.maxTokensPerHour` and `budget.maxRequestsPerHour`. When a budget is exceeded the next cycle is skipped and the budget event is logged.

### Authentication and authorization (opt-in)

When `auth.enabled=true`, RPI Observability participates in the RPI trust domain as a peer service. Authentication is delegated to the IDP your RPI deployment already uses (native RPI auth via OpenIddict, Microsoft Entra ID, Keycloak, or Okta). Authorization is resolved through RPI's normalized user / group / permission model in the operational database -- no parallel identity store.

Above the auth layer, the dashboard and the API consume **capabilities** (`observability.view`, `diagnostics.view`, `diagnostics.viewSql`, `diagnostics.viewStackTrace`, `diagnostics.exportBundle`, `analyzer.admin`), not raw groups or roles. The capability map is configurable via chart values; defaults are shipped.

The login surface is rendered inside the dashboard shell as one of two states (authenticated vs. unauthenticated) -- there is no separate login page. FastAPI sets the session cookie and 303-redirects back to `/`; the browser holds the cookie and the dashboard reads identity via `/auth/whoami` on every render.

When `auth.enabled=false` (default), the dashboard remains anonymous and the legacy unauthenticated path is preserved. See the chart's `observability.auth` block for the full set of values.

### Dashboard tabs

The Streamlit UI surfaces four top-level tabs:

| Tab | What it shows | Required capability |
|:----|:--------------|:--------------------|
| **Overview** | Latest cycle summary (NEW / RECURRING / RESOLVED pills), four breakdown pies (service, tenant, plugin, host), 24-hour trend per service, per-cluster cards (count, source, headline, explanation, suggested fix), and a downloads list for recent reports. | `observability.view` |
| **System Health** | Live pod state and node state from the Kubernetes API + metrics-server (CPU, memory, restart counts, recent events). RBAC: namespace-scoped Role for pods, optional cluster-scoped ClusterRole for nodes (gated by `nodeHealth.enabled`). | `observability.view` |
| **Log Analysis** | Per-cluster incident-intelligence cards with the model's explanation + suggested fix, drill-down into raw rows, and a per-cluster log download. | `observability.view` |
| **Diagnostics** | Per-Interaction lookup. SQL trace clusters, audit timeline, application logs, and a downloadable diagnostic bundle (mirrors the on-prem "Download Diagnostics" zip). Some sub-views require additional capabilities (`diagnostics.viewSql`, `diagnostics.viewStackTrace`, `diagnostics.exportBundle`). | `diagnostics.view` |

The sidebar carries the token-budget bar, the **Run analysis now** button (gated by `analyzer.admin`), and the signed-in identity strip when auth is on.

</details>

<details>
<summary><strong style="font-size:1.25em;">Configuration</strong></summary>

The component is opt-in. Add the following block to your overrides.

### Example A: `helmAssistant` (default, turnkey)

Best out-of-the-box experience. Zero AI infrastructure required.

```yaml
observability:
  enabled: true
  schedule:
    dailyAtUtc: "00:00"             # daily mode, 24 h lookback (auto)
  email:
    enabled: true
    recipients:
      - sre@example.com
  teams:
    enabled: true                   # webhookSecretKey defaults to Observability_Teams_Webhook
  storage:
    volumeClaimTemplates:
      enabled: true
      accessModes: ReadWriteOnce
      storage: 5Gi
      storageClassName: ""          # empty = cluster default storage class
```

The Helm Assistant API key drops into `redpoint-rpi-secrets` under `Observability_HelmAssistant_ApiKey` (format: `<username>:<password>`).

### Example B: `localLlm` (private, packaged in-cluster)

Inference runs in-cluster via Ollama; no log data leaves the network.

```yaml
observability:
  enabled: true
  model:
    provider: localLlm
    llmName: phi3:mini              # any tag from https://ollama.com/library
  localLlm:
    enabled: true
  schedule:
    intervalMinutes: 30
    lookbackMinutes: 60
```

### Example C: `byo` + AWS Bedrock (customer-managed)

Customer-managed inference; auth via `cloudIdentity.amazon`.

```yaml
observability:
  enabled: true
  model:
    provider: byo
    llmName: anthropic.claude-sonnet-4-20250514-v1:0
    byo:
      platform: bedrock
      bedrock:
        region: us-east-1
  email:
    enabled: true
    recipients:
      - sre@example.com
    onlyOnNewErrors: true

cloudIdentity:
  amazon:
    roleArn: arn:aws:iam::123456789012:role/rpi-observability
```

For other `byo` platforms: `byo.platform: anthropic` + `byo.anthropic.apiKeyVaultEntry`; `byo.platform: vertex` + `byo.vertex.{projectId, region}`; `byo.platform: azureFoundry` (uses chart-wide `redpointAI.naturalLanguage`).

### Reference

| Key | Default | Description |
|:----|:--------|:------------|
| `enabled` | `false` | Master switch. |
| `replicas` | `1` | StatefulSet replica count. |
| `model.provider` | `helmAssistant` | AI deployment posture: `helmAssistant`, `localLlm`, or `byo`. |
| `model.llmName` | `""` | Model identifier for the active posture. Ignored for `helmAssistant` and for `byo.platform=azureFoundry`. |
| `model.helmAssistant.url` | `https://rpi-helm-assistant.redpointcdp.com` | Helm Assistant control-plane URL. |
| `model.byo.platform` | _(unset)_ | Required when `provider=byo`. One of `anthropic`, `azureFoundry`, `bedrock`, `vertex`. |
| `localLlm.enabled` | `false` | Deploy the in-cluster Ollama backend. Required when `provider=localLlm`. |
| `schedule.intervalMinutes` | `30` | Interval mode period. Ignored when `dailyAtUtc` is set. |
| `schedule.dailyAtUtc` | `""` | Daily mode time as `HH:MM` UTC. Empty = interval mode. |
| `schedule.lookbackMinutes` | auto | Defaults to 60 in interval mode, 1440 in daily mode. |
| `schedule.onDemandEnabled` | `true` | Exposes `POST /api/analyze`. |
| `budget.maxTokensPerHour` | `200000` | Hard cap; exceeding skips the next cycle. |
| `budget.maxRequestsPerHour` | `60` | Hard cap; exceeding skips the next cycle. |
| `nodeHealth.enabled` | `true` | Powers the Node Health panel; binds a cluster-scoped ClusterRole. Set `false` if cluster-scoped RBAC is not allowed. |
| `logSources.interaction` | `""` | Interaction DB name; required for the Diagnostics tab's per-Interaction drill-down. |
| `logSources.sqlTrace` | `""` | InteractionAudit DB name; required for SQL trace clusters. |
| `logSources.audit` | `""` | InteractionAudit DB name; required for the audit timeline (often same as `sqlTrace`). |
| `logSources.clientServer` | `""` | Informational; the actual Pulse_Logging connection comes from the chart secret. |
| `diagnostics.fileOutput.enabled` | `false` | Mounts the chart-wide FileOutputDirectory PVC read-only at `/rpifileoutputdir` so diagnostic bundles can include workflow output files. |
| `auth.enabled` | `false` | Opt-in trust-domain participation. |
| `auth.tenantId` | `""` | Required when `auth.enabled=true`. |
| `auth.anonymous` | `deny` | Anonymous-access posture: `deny`, `observabilityViewOnly`, or `allowAnonymous`. |
| `auth.cookieSecure` | `true` | Set `false` only for local dev without TLS. |
| `auth.sessionLifetimeSeconds` | `28800` | 8 hours. |
| `auth.ingressHost` | auto | Auto-derived from `ingress.hosts.observability` + `ingress.domain` when empty. |
| `email.enabled` | `false` | Send the cycle digest as HTML email. |
| `email.recipients` | `[]` | List of email addresses. |
| `email.onlyOnNewErrors` | `true` | Skip cycles with no first-seen error types. Bypassed in daily mode. |
| `teams.enabled` | `false` | Post the cycle digest to a Teams channel. |
| `teams.webhookSecretKey` | `Observability_Teams_Webhook` | Key in `redpoint-rpi-secrets` holding the webhook URL. |
| `teams.onlyOnNewErrors` | `true` | Same semantics as `email.onlyOnNewErrors`. Bypassed in daily mode. |
| `storage.existingClaim` | `""` | Mount an existing PVC instead of provisioning a new one. |
| `storage.volumeClaimTemplates.enabled` | `true` | Provision via StatefulSet `volumeClaimTemplates`. |
| `storage.volumeClaimTemplates.storage` | `5Gi` | Volume size. |
| `storage.volumeClaimTemplates.storageClassName` | `""` | Empty = cluster default. |

The full set of `auth.*` keys (capability map, native + federated provider blocks, signing-key secret, etc.) is documented in the chart's `observability.auth` comments.

</details>

<details>
<summary><strong style="font-size:1.25em;">Notifications</strong></summary>

### Email

The component reuses the chart-wide `SMTPSettings` block (the same SMTP server, sender address, and credentials the .NET RPI services already use). No component-specific SMTP configuration is required.

The HTML body shows total errors, the new / recurring / resolved breakdown pills, four breakdown pies (service, tenant, plugin, host), the cycle summary, and a button that links back to the dashboard.

![Email digest](../chart/images/email_card.jpg)

### Microsoft Teams

The Teams card is posted to a Workflow incoming webhook. To get the URL:

1. In the target Teams channel, click `...` -> `Workflows`.
2. Pick the template `Post to a channel when a webhook request is received`.
3. Copy the URL the workflow generates.
4. Store it in `redpoint-rpi-secrets` under `Observability_Teams_Webhook` (override with `teams.webhookSecretKey` if you use a different key).

The card mirrors the email content. The Redpoint logo and the four breakdown pies are inlined into the card payload as base64 data URIs, so the card renders correctly even when the dashboard's ingress is private.

![Teams card](../chart/images/teams_card.jpg)

### Trigger gates

A digest fires only when all of these are true:

| Channel | Gates |
|:--------|:------|
| Email | `email.enabled`, recipients list non-empty, SMTP address and sender address configured. |
| Teams | `teams.enabled`, webhook URL present in the secret. |
| Both | Cycle has at least one `new` (first-seen) error type, **unless** `onlyOnNewErrors: false` or daily mode is on. |

</details>

<details>
<summary><strong style="font-size:1.25em;">Access and operations</strong></summary>

### Ingress

Add a host entry under your existing `ingress.hosts` block:

```yaml
ingress:
  domain: example.com
  hosts:
    observability: rpi-observability        # final URL: https://rpi-observability.example.com
```

The chart wires this into `OBSERVABILITY__EMAIL__INGRESS_URL` so the email and Teams CTA buttons link back to a working dashboard URL. When `auth.enabled=true`, the same host is used to construct the OIDC redirect URI advertised to the IDP (override with `auth.ingressHost` if you front the dashboard with a different external hostname).

### Internal API

Two processes run inside the pod:

| Process | Port | Reachable from |
|:--------|:-----|:---------------|
| Streamlit UI | `8501` | The public ingress (this is what operators see). |
| FastAPI | `8080` | Inside the pod only. The Streamlit UI calls it on `localhost`. Kubelet hits it for probes. The chart's ingress also routes `/auth/*` to FastAPI when auth is enabled. |

For ad-hoc inspection of the FastAPI surface, use a port-forward:

```bash
kubectl port-forward -n <namespace> pod/rpi-observability-0 8080:8080
curl http://localhost:8080/api/budget
```

Available endpoints (capability gating applies when `auth.enabled=true`):

| Endpoint | Purpose | Capability |
|:---------|:--------|:-----------|
| `GET /health/live` | Liveness probe. | (none) |
| `GET /health/ready` | Readiness probe. | (none) |
| `GET /api/reports` | List recent reports. | `observability.view` |
| `GET /api/reports/{id}` | Single report payload. | `observability.view` |
| `GET /api/reports/{id}/export.txt` | Plain-text dump of every row in every cluster. | `diagnostics.exportBundle` |
| `GET /api/trend` | Per-cycle time series for the last 24 hours. | `observability.view` |
| `GET /api/budget` | Current token / request budget status. | `observability.view` |
| `GET /api/spend` | Lifetime spend summary. | `observability.view` |
| `GET /api/settings` | Read-only summary of the active configuration. | `observability.view` |
| `POST /api/analyze` | Fire an off-schedule cycle. Disable via `schedule.onDemandEnabled: false`. | `analyzer.admin` |
| `GET /api/pods/health` | Pod state for the System Health tab. | `observability.view` |
| `GET /api/nodes/health` | Node state for the System Health tab. | `observability.view` |
| `GET /api/infra/pods` | Pod-level infra rollup. | `observability.view` |
| `GET /api/infra/events` | Recent K8s events. | `observability.view` |
| `GET /api/telemetry/snapshot` | Combined live telemetry snapshot. | `observability.view` |
| `GET /api/diagnostics/recent` | Recent Interactions for the Diagnostics tab. | `diagnostics.view` |
| `GET /api/diagnostics/lookup/{id}` | Per-Interaction detail. | `diagnostics.view` |
| `GET /api/diagnostics/{id}/bundle` | Downloadable diagnostic bundle. | `diagnostics.exportBundle` |
| `GET /auth/whoami` | Current session identity + capabilities. | (auth) |
| `POST /auth/native/exchange` | Native-posture credential exchange (browser form POST). | (none) |
| `GET /auth/sso/start` | Federated-posture OAuth start (302 to IDP). | (none) |
| `GET /auth/callback` | Federated-posture OAuth callback. | (none) |
| `GET`/`POST /auth/logout` | Clear session, 303 to `/`. | (auth) |
| `GET /auth/health` | Auth backend health (issuer, JWKS, authorization provider). | (none) |

### Logs and probes

The pod logs cycle results, scheduling decisions, and notification outcomes. Sample lines:

```
INFO  app.scheduler scheduler running in daily mode at 00:00 UTC
INFO  app.scheduler next cycle in 32400 s (daily at 00:00 UTC)
INFO  app.analyze.pipeline cycle complete: report_id=42 errors=511 clusters=8
INFO  app.email_sender email digest sent: report=#42 recipients=1
INFO  app.teams_sender Teams notification sent: report=#42
INFO  app.teams_sender Teams notification skipped: no first-seen errors this cycle
INFO  rpi-observability.audit auth.login.success identity_email=alice@example.com idp=native
INFO  rpi-observability.audit authz.denied capability_required=diagnostics.viewSql route=/api/diagnostics/lookup/...
```

</details>

---

## Day-2 operations

For operators running RPI Observability in production, see the **[RPI Observability Operations Guide](observability-ops.md)**. It covers what every dashboard label means, how schedule and lookback windows work (including how long it takes a fix to show as `Resolved`), notification trigger gates, the token budget, and troubleshooting the most common failure modes.

---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

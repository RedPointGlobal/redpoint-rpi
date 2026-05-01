![redpoint_logo](../chart/images/redpoint.png)
# Log Analyzer

[< Back to Home](../README.md)

## Overview

The **Log Analyzer** is an operations component for RPI that reads recent error rows from the `Pulse_Logging` database, groups them into clusters by signature, and produces a per-cycle report showing what is failing, where, and how often. The same report is sent to email and Microsoft Teams.

It is built for SRE teams who want a single operations view of error activity across services, tenants, plugins, and hosts without having to query `Pulse_Logging` by hand or watch a dashboard. It does not replace your APM, metrics, or paging stack. It complements them by giving you a scheduled (daily or interval) operations digest with a small dashboard for follow-up investigation.

The component runs in the same cluster as the rest of RPI. It connects to `Pulse_Logging` using the chart's existing operational database credentials. It writes its own report history to a local SQLite database on a dedicated volume.

---

<details>
<summary><strong style="font-size:1.25em;">What it does</strong></summary>

Each cycle:

1. Queries `Pulse_Logging` for rows logged in the lookback window (60 minutes in interval mode, 24 hours in daily mode).
2. Filters out rows below the configured severity floor.
3. Groups rows by signature. The fingerprint strips volatile content (timestamps, IDs, IP addresses, paths) so multiple variants of the same underlying error land in one cluster.
4. Aggregates totals by service, tenant, plugin, and host.
5. For each cluster, asks the configured model to produce a short explanation of what the error means and a suggested fix. Also asks for a 2 to 4 sentence summary of the cycle as a whole.
6. Persists the full report to a local SQLite store.
7. Marks each cluster as `new`, `recurring`, or `resolved` relative to the previous cycle. A cluster is `new` if its signature has never been seen in any prior cycle.
8. Sends an HTML email digest and a Teams Adaptive Card if either channel is enabled and the trigger gates pass.

The dashboard at `https://<your-ingress>/` shows the latest report at the top, four breakdown pies, a 24-hour trend chart per service, and per-cluster cards with the explanation and suggested fix.

</details>

<details>
<summary><strong style="font-size:1.25em;">How it works</strong></summary>

### Architecture

| Component | Role |
|:----------|:-----|
| Streamlit UI (port 8501) | Operator-facing dashboard. Calls the local API. |
| FastAPI app (port 8080) | Health probes, report queries, on-demand analysis trigger. |
| Background scheduler | Triggers the analysis cycle on the configured cadence. |
| SQLite report store | Local database at `/data/reports.db`. Holds the report history. |
| `Pulse_Logging` client | Read-only `pyodbc` connection to the operational database. |
| Email sender | SMTP transport. Reuses the chart-wide `SMTPSettings` block. |
| Teams sender | HTTPS POST to a Workflow incoming webhook (URL stored as a Kubernetes secret). |

### Schedule modes

The analyzer supports two scheduling modes.

| Mode | When it fires | Use case |
|:-----|:--------------|:---------|
| **Interval** (default) | Every `intervalMinutes` after pod startup | Active monitoring, short reaction time |
| **Daily** | Once a day at `dailyAtUtc` (`HH:MM` in UTC) | Operations digest at a fixed time |

In daily mode the lookback window auto-defaults to 24 hours so consecutive cycles cover the full day. Daily mode also bypasses the `onlyOnNewErrors` gate on both email and Teams: the assumption is that if you opted into a daily summary, you want it every day even on quiet days.

The **Run analysis now** button in the sidebar (and `POST /api/analyze`) fires an off-schedule cycle. Same downstream code path, so it produces a real report and triggers the email and Teams senders.

### Storage

The analyzer keeps its report history in SQLite at `/data/reports.db`. SQLite needs a filesystem that honors POSIX byte-range locks, so `/data` must be backed by block storage (Azure Disk, AWS EBS, GCP PD). Network file shares such as Azure Files or NFS will not work for this volume because their lock semantics break SQLite.

The chart uses a `volumeClaimTemplates` block on a single-replica StatefulSet. This is the same pattern Redis and RabbitMQ use. By default the StorageClass is left empty so the cluster default is used. You can also bring your own PVC via `storage.existingClaim`.

### Model providers

The analyzer can call any of:

| Provider | Configuration |
|:---------|:--------------|
| Azure OpenAI / Foundry | Reuses the chart-wide `redpointAI.naturalLanguage` block (`ApiBase`, `ApiVersion`, `ChatGptEngine`). |
| Direct Anthropic API | API key stored in the cloud vault. |
| AWS Bedrock | Authentication via `cloudIdentity.amazon` (IRSA / EKS Pod Identity). Permission needed: `bedrock:InvokeModel` on the target model. |
| GCP Vertex AI | Authentication via `cloudIdentity.google` (Workload Identity). Permission needed: `aiplatform.endpoints.predict`. |

The model is called per cycle, not per row. Token and request rate limits are enforced inside the analyzer via `budget.maxTokensPerHour` and `budget.maxRequestsPerHour`. When a budget is exceeded the next cycle is skipped and the budget event is logged.

</details>

<details>
<summary><strong style="font-size:1.25em;">Configuration</strong></summary>

The analyzer is opt-in. Add the following block to your overrides.

### Example A: Daily summary at midnight UTC, Azure OpenAI, email + Teams

```yaml
logAnalyzer:
  enabled: true
  model:
    provider: azureFoundry          # reuses the chart-wide redpointAI block
  schedule:
    dailyAtUtc: "00:00"             # daily mode, 24 h lookback (auto)
  email:
    enabled: true
    recipients:
      - sre@example.com
  teams:
    enabled: true                   # webhookSecretKey defaults to LogAnalyzer_Teams_Webhook
  storage:
    volumeClaimTemplates:
      enabled: true
      accessModes: ReadWriteOnce
      storage: 5Gi
      storageClassName: ""          # empty = cluster default storage class
```

### Example B: Interval mode (every 30 minutes), Anthropic, email-only on new errors

```yaml
logAnalyzer:
  enabled: true
  model:
    provider: anthropic
    anthropic:
      modelName: claude-sonnet-4-6
      apiKeyVaultEntry: LogAnalyzer-AnthropicApiKey
  schedule:
    intervalMinutes: 30
    lookbackMinutes: 60
  email:
    enabled: true
    recipients:
      - sre@example.com
    onlyOnNewErrors: true           # only when at least one cluster is first-seen
```

### Reference

| Key | Default | Description |
|:----|:--------|:------------|
| `enabled` | `false` | Master switch. |
| `model.provider` | `anthropic` | One of: `anthropic`, `azureFoundry`, `bedrock`, `vertex`. |
| `schedule.intervalMinutes` | `30` | Interval mode period. Ignored when `dailyAtUtc` is set. |
| `schedule.dailyAtUtc` | `""` | Daily mode time as `HH:MM` UTC. Empty = interval mode. |
| `schedule.lookbackMinutes` | auto | How far back each cycle queries. Defaults to 60 in interval mode, 1440 in daily mode. Override with an integer if needed. |
| `schedule.onDemandEnabled` | `true` | Exposes `POST /api/analyze`. Set `false` to disable the Run-now button and on-demand endpoint. |
| `budget.maxTokensPerHour` | `200000` | Hard cap. Exceeding skips the next cycle. |
| `budget.maxRequestsPerHour` | `60` | Hard cap. Exceeding skips the next cycle. |
| `email.enabled` | `false` | Send the cycle digest as HTML email. |
| `email.recipients` | `[]` | List of email addresses. |
| `email.onlyOnNewErrors` | `true` | If true, skip cycles with no first-seen error types. Bypassed in daily mode. |
| `teams.enabled` | `false` | Post the cycle digest to a Teams channel. |
| `teams.webhookSecretKey` | `LogAnalyzer_Teams_Webhook` | Key in `redpoint-rpi-secrets` holding the webhook URL. |
| `teams.onlyOnNewErrors` | `true` | Same semantics as `email.onlyOnNewErrors`. Bypassed in daily mode. |
| `storage.existingClaim` | `""` | Mount an existing PVC instead of provisioning a new one. |
| `storage.volumeClaimTemplates.enabled` | `true` | Provision the volume via StatefulSet `volumeClaimTemplates`. |
| `storage.volumeClaimTemplates.storage` | `5Gi` | Volume size. |
| `storage.volumeClaimTemplates.storageClassName` | `""` | Empty = use cluster default. |

</details>

<details>
<summary><strong style="font-size:1.25em;">Notifications</strong></summary>

### Email

The analyzer reuses the chart-wide `SMTPSettings` block (the same SMTP server, sender address, and credentials the .NET RPI services already use). No analyzer-specific SMTP configuration is required.

The HTML body shows total errors, the new / recurring / resolved breakdown pills, four breakdown pies (service, tenant, plugin, host), the cycle summary, and a button that links back to the dashboard.

### Microsoft Teams

The Teams card is posted to a Workflow incoming webhook. To get the URL:

1. In the target Teams channel, click `...` -> `Workflows`.
2. Pick the template `Post to a channel when a webhook request is received`.
3. Copy the URL the workflow generates.
4. Store it in `redpoint-rpi-secrets` under the key `LogAnalyzer_Teams_Webhook` (override with `teams.webhookSecretKey` if you use a different key).

The card mirrors the email content. The Redpoint logo and the four breakdown pies are inlined into the card payload as base64 data URIs. This means the card renders correctly even when the analyzer's ingress is private. Teams' image renderers run on Microsoft's public infrastructure and would not be able to fetch images from a private host, but data URIs do not require a network fetch.

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
    loganalyzer: rpi-loganalyzer        # final URL: https://rpi-loganalyzer.example.com
```

The chart wires this into the analyzer's `LOG_ANALYZER__EMAIL__INGRESS_URL` env so the email and Teams CTA buttons link back to a working dashboard URL.

### Dashboard

The Streamlit UI at the ingress URL has these sections:

| Section | What it shows |
|:--------|:--------------|
| Summary | Status pills (NEW / RECURRING / RESOLVED), the cycle's prose summary, and the comparison report ID. |
| Breakdown pies | Four pies: errors by service, tenant, plugin, host. Top 5 each, with the rest grouped under `(other)`. |
| 24-hour trend | One line per service across the last 24 hours of cycles. |
| Error details | Per-cluster cards. Each card shows the count, source, headline message, a short explanation, and a suggested fix. Cards are color-coded by severity. |
| Downloads | Recent reports with a per-cycle log download. The download contains every persisted row from every cluster (raw, untruncated). Hand off to dev for deeper analysis. |

### API endpoints

The analyzer exposes a small JSON API on the same ingress:

| Endpoint | Purpose |
|:---------|:--------|
| `GET /health/live` | Liveness probe. |
| `GET /health/ready` | Readiness probe. Fails if the report store is not initialized. |
| `GET /api/reports` | List recent reports (id, started_at, error_count, token usage). |
| `GET /api/reports/{id}` | Single report payload. |
| `GET /api/reports/{id}/export.txt` | Plain-text dump of every row in every cluster for that report. |
| `GET /api/trend` | Per-cycle time series for the last 24 hours. Used by the trend chart. |
| `GET /api/budget` | Current token / request budget status. |
| `GET /api/settings` | Read-only summary of the active configuration. |
| `POST /api/analyze` | Fire an off-schedule cycle. Returns the new report. Disable via `schedule.onDemandEnabled: false`. |

### Logs and probes

The analyzer pod logs cycle results, scheduling decisions, and notification outcomes. Sample lines worth knowing:

```
INFO  app.scheduler scheduler running in daily mode at 00:00 UTC
INFO  app.scheduler next cycle in 32400 s (daily at 00:00 UTC)
INFO  app.analyze.pipeline cycle complete: report_id=42 errors=511 clusters=8
INFO  app.email_sender email digest sent: report=#42 recipients=1
INFO  app.teams_sender Teams notification sent: report=#42
INFO  app.teams_sender Teams notification skipped: no first-seen errors this cycle
```

</details>

---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

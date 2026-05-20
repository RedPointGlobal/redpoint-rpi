![redpoint_logo](../chart/images/redpoint.png)
# RPI Observability Operations Guide

[< Back to Home](../README.md)

## Overview

This is the day-2 operations playbook for the RPI Observability. It explains what every label on the dashboard means, when notifications fire, how the schedule works, and the most common questions operators hit when something does not look right. For installation, configuration, and prerequisites see the [RPI Observability setup guide](observability.md).

The aim is that an operator landing here at 2am with a paged-out RPI environment can find the answer in one section without having to read source code.

---

<details>
<summary><strong style="font-size:1.25em;">Reading the dashboard</strong></summary>

### API operational posture rail

The first row on the System Health page. Five fixed rail items: an **Execution Capacity** tile in the leftmost slot (Execution Service thread-pool ceiling + current utilization), followed by four customer-facing Interaction API journeys (Workflows/Start, Authentication/Token, Pulse/Retrieve, ClientJobs/Status). Each item carries a headline value, a posture badge, a micro telemetry sparkline, and a chip row of operational signals.

```
WORKFLOWS/START              AUTHENTICATION/TOKEN          PULSE/RETRIEVE              CLIENTJOBS/STATUS
4,550 req   healthy           2 req   idle                  46k req   healthy           136k req   healthy
∿∿∿∿∿∿∿                       _______ (baseline hairline)   ∿∿∿∿∿∿∿                     ∿∿∿∿∿∿∿
[p95 45ms] [4xx 0] [5xx 0]   [no traffic]                  [p95 28ms] [4xx 0] [5xx 0]  [p95 22ms] [4xx 0] [5xx 0]
```

The five rail items are **fixed and operator-centric** -- they always appear in the same position and in the same order so an operator scanning the rail knows where each signal lives without recalibrating. The rail is not dynamic and does not reorder or substitute items based on traffic patterns.

The Execution Capacity tile uses a slightly different chip vocabulary from the four routes: `[util N%] [executing N] [headroom N]` rather than `[p95 N ms] [4xx N] [5xx N]`. The composition shape (eyebrow + headline + badge + sparkline + chip row) is identical; only the values carried in each slot reflect the tile's capacity-posture role rather than the routes' latency-posture role. The Capacity tile's badge vocabulary is also capacity-flavored: `headroom` (util < 70%), `under load` (70-80%), `saturated` (>= 80%), `idle` (no samples). Brand-red on the sparkline + chip is reserved for current util >= 80% (matches the Execution Service card's 80% scaling-concern threshold directly below the rail).

#### Rail layout

| Element | What it shows |
|:---|:---|
| **Eyebrow** (e.g. `WORKFLOWS/START`) | The customer journey. The label is the operator-facing name; the actual API route the pod emits is mapped internally (see the route-mapping table below). |
| **Headline value** (e.g. `4,550 req` or `136k req`) | Cumulative request count for that route since the Interaction API pod last started, with a subtle `req` unit so the number is self-describing. See "cumulative vs windowed timescales" below. |
| **Badge** (e.g. `healthy` / `under load` / `slow` / `degraded` / `idle`) | Qualitative latency posture derived from the windowed p95. When 5xx > 0 in the window, the badge becomes `N 5xx` (1-5 5xx) or `degraded` (>5 5xx) regardless of latency. |
| **Sparkline** (thin micro waveform) | Per-tick request-volume sparkline across the last 15 minutes. Single-tone slate baseline at every posture; only shifts to brand-red when the route is in `degraded` posture (sustained 5xx). No fill, no glow, no severity colour ramp. Idle routes render a faint baseline hairline so the row's vertical rhythm stays intact. |
| **Chip row** (e.g. `[p95 22ms] [4xx 0] [5xx 0]`) | Three tiny chips with the operational metrics. Each chip has a lowercase key + tabular value. Tone discipline: `p95` is neutral slate until thresholds cross (>=100ms = amber, >=200ms = brand red); `4xx` stays muted while zero and shifts to amber when non-zero; `5xx` stays muted while zero and shifts to brand red when non-zero. Idle routes collapse to a single `[no traffic]` chip rather than a prose sentence so the row keeps its scan rhythm. |

#### Route mapping

The rail uses operator-facing labels. The mapping to the literal API route emitted by the Interaction API pod is:

| Rail label | Emitted route |
|:---|:---|
| `Workflows/Start` | `api/Workflows/Interactions/Interaction` |
| `Authentication/Token` | `connect/token` (OpenIddict standard) |
| `Pulse/Retrieve` | `api/Pulses/Retrieve` |
| `ClientJobs/Status` | `api/ClientJobs/{jobID}/Status` |

#### Cumulative vs windowed timescales

The rail deliberately mixes two timescales. Different metrics answer different questions, so they're measured on different windows:

| Signal | Timescale | Why |
|:---|:---|:---|
| **Headline request count** | Cumulative since the Interaction API pod started | "Scale of work this endpoint has handled." A stable identifier of which routes carry the load. Survives quiet periods (a route between heavy traffic still shows its lifetime total instead of `0`). |
| **P95 latency** | Last 15 minutes | "How is the endpoint responding right now?" If p95 were cumulative, a current latency spike would be averaged across hours of lifetime data and barely register. Windowed surfaces it immediately. |
| **4xx count** | Last 15 minutes | Active client-side error pressure. Windowed so a current incident is visible without being diluted by historical bad client behaviour. |
| **5xx count** | Last 15 minutes | Active server-side failures. Same reasoning as 4xx -- windowed for incident sensitivity. |

The cumulative headline is held in the Interaction API pod's memory (via the .NET metrics SDK). It resets to `0` only on a pod restart -- e.g. `helm upgrade` rolling the deployment, a pod crash, an OOM kill, eviction, or `kubectl rollout restart`. If you see `ClientJobs/Status: 1,200` when you expected `136k`, the Interaction API pod has been recently restarted; check `kubectl get pod -n <namespace> rpi-interactionapi-<hash> -o jsonpath='{.status.startTime}'`.

#### Posture badge meaning

The vocabulary stays operational rather than alarmist. `degraded` is reserved for genuine platform-failure shape (sustained 5xx); latency-only postures use `under load` and `slow` so the badge tells operators what they're actually seeing.

| Badge | Trigger | Reading |
|:---|:---|:---|
| `healthy` | P95 < 100ms, no 5xx | Latency within typical tolerance. Steady state. |
| `under load` | P95 100-200ms, no 5xx | Latency above baseline but not yet critical. Worth keeping an eye on if sustained. |
| `slow` | P95 >=200ms, no 5xx | Latency-only degradation. The route is responding but slowly; users feel it. |
| `degraded` | 5xx > 5 in window | Sustained server-side failures. Platform issue, not a latency issue. Active operator attention. |
| `N 5xx` | 1-5 5xx in window | The badge shows the 5xx count directly when fewer than the `degraded` threshold; the meter and signal strip pick up the amber tone. |
| `idle` | No samples in the 15-min window | The route is quiet (no traffic, not a failure). The headline still shows the cumulative count (muted) so the rail item stays visible. |

#### What to do when

| State | Action |
|:---|:---|
| Everything `healthy` | Steady state. Nothing to do. |
| One route shows `under load` | Note it; check if it correlates with workflow load or known maintenance. If sustained for multiple 15-min windows, drill into Custom Metrics tab for the per-route histogram detail. |
| One route shows `slow` | Latency has crossed 200ms but the platform itself is responding. Check the Workflow Activity hero for correlated workload spikes; if the platform is otherwise healthy, the route may be queuing behind a slow downstream dependency. |
| Any route shows `degraded` or non-zero 5xx | Brand-red is earned. Customers are seeing failures. Check the Failure Analysis tab for the corresponding cluster, then Diagnostics for individual request traces. |
| Any route shows non-zero 4xx (amber, softer weight) | Client-side errors -- often indicates RPI Client misconfiguration, expired tokens, or unauthorized access attempts. Worth checking if the rate is unusual; not always an operator-side issue. The softer amber signals "warning, not failure". |
| All routes show `idle` | Either no users are active (off-hours, weekend) or the Interaction API is unreachable from clients. Check the platform-health pill on the right of the page and the Service Availability ribbon. |

### Status pills (Overview row)

| Pill | What it means |
|:-----|:--------------|
| **NEW N** | Number of distinct errors **firing for the first time**. Once an error has been seen in any prior report, it stops being NEW even if it goes quiet for weeks and returns. |
| **RECURRING N** | Number of distinct errors in this report that have **fired before** at some point. NEW + RECURRING is the total error types in the current report. |
| **RESOLVED N** | Number of errors that were in the **previous report** but are no longer firing. This is the only pill compared against the previous report rather than the full history. |

### Count and severity badge

Each cluster card carries a coloured pill of the form `555× HIGH`:

- The number is the **hit count** for this error type in the current cycle's lookback window.
- The `×` is a multiplication sign, read as "times". `555×` means the error fired 555 times.
- The bucket label and the card colour come from the count:

| Count range | Bucket | Pill colour | Card rail colour |
|:---|:---|:---|:---|
| `≥ 50` | **HIGH** | red | red |
| `10 – 49` | **ELEVATED** | amber | amber |
| `1 – 9` | **LOW** | blue | blue |
| `0` | **CLEAR** | green | green |

### Sparkline

A small 72×18 SVG line on each cluster card showing the **count history across the last 7 cycles** (oldest left, newest right). The stroke colour signals the trend:

| Colour | Meaning |
|:---|:---|
| **Red** | Last cycle's count is materially higher than the average of the priors. Regression signal. |
| **Green** | Last cycle's count is materially lower than the average. Recovery signal. |
| **Slate** | Steady state. |

The sparkline is hidden when there is only one data point (a single dot is not informative). With daily mode the sparkline gives you a "last week" view; with interval mode it is the last 7 cycles (about 3.5h on the default 30-min cadence).

### Blast radius badge

When a cluster's errors are part of incidents that touched more than one service, an indigo pill appears:

```
4-svc blast · 12 incidents
```

- **`4-svc blast`**: across all incidents this cluster participated in, the worst one touched 4 distinct services. This is the maximum blast radius. It is a "this cluster is part of a cascade" signal.
- **`12 incidents`**: the count of distinct CorrelationIds this error appeared in during this cycle. Standalone rows with no CorrelationId are also counted as one incident each.

The badge is hidden when the cluster only ever appeared in single-service incidents.

### Tenant attribution

A line under the headline message of each cluster card lists the **ClientID(s)** generating the errors:

```
Tenant: a1b2c3d4… (87%)
Tenants: a1b2…, b2c3…, c4d5… + 2 more
```

- Single tenant: shows the percentage share of this cluster's rows.
- Multiple tenants: lists up to 3 UUID prefixes; the rest roll into `+ N more`.
- Each prefix's full UUID is in the HTML `title` attribute. Hover to see the complete value.
- Hidden when no rows in the cluster carry a ClientID (system-level errors that fire before tenant context is established).

### Multi-service Correlation tab

Lists every CorrelationId in this cycle that touched 2 or more services, sorted by blast radius. Each card shows:

- Blast pill (`N services · M rows`)
- Correlation prefix (first 8 chars)
- Root timestamp and root service (the service that logged the earliest row in the correlation)
- Sample message (the root row's first line)
- Comma list of services touched

Use this tab to spot cascading failures where one logical request fanned out into errors across the platform.

</details>

<details>
<summary><strong style="font-size:1.25em;">Schedule and timing</strong></summary>

### Interval mode (default)

Cycles fire every `intervalMinutes` after pod startup. The lookback window is `lookbackMinutes` and defaults to 60. The first cycle runs once readiness probe passes; subsequent cycles fire on the interval clock from there.

### Daily mode

Set `schedule.dailyAtUtc: "00:00"` to fire once a day at that wall-clock UTC time. Daily mode auto-defaults the lookback to 1440 min (24h) so consecutive cycles cover the full day.

When the pod starts, the scheduler computes seconds until the next future occurrence of `dailyAtUtc` and sleeps until then. So if you set `dailyAtUtc: "00:00"` and roll out at 14:00, the first scheduled cycle is 10 hours away. Use **Run analysis now** to fire an off-schedule cycle if you need an immediate report.

### How long until a fix shows as RESOLVED

This is the most asked question. The answer depends on where in the cycle window the fix landed:

In daily mode at `00:00 UTC` with the default 1440-min lookback, an error you fixed today will:

| Cycle date | Lookback window | Behaviour |
|:---|:---|:---|
| Tomorrow 00:00 | yesterday 00:00 → tomorrow 00:00 | Window covers pre-fix and post-fix periods. Cluster still appears, likely as **Recurring** with a smaller count. |
| Day after tomorrow 00:00 | tomorrow 00:00 → day after tomorrow 00:00 | Window is entirely post-fix. Cluster does not appear. The previous report still had it, so this report shows **Resolved**. |

So the formal "Resolved" tag lags **two cycles** (~48 h) behind the actual fix in daily mode. In interval mode the same logic applies but compressed: with 30-min cycles and 60-min lookback it takes ~2 hours.

**Faster confirmation**: the cluster's sparkline drops to zero on the right edge as soon as the next cycle runs. That is the recovery signal you want at 2am, not the "Resolved" pill which is the formal cycle-over-cycle confirmation.

### Run analysis now

Sidebar button on the dashboard. Triggers an off-schedule cycle through the same code path as the scheduler. Email and Teams gates apply (so you may or may not see notifications; depends on your `onlyOnNewErrors` settings and whether the cycle has new error types). The off-schedule cycle still uses the configured `lookbackMinutes`.

Use it when:
- You just deployed a fix and want to verify the analyzer sees the change immediately.
- You want a fresh report before a stand-up or incident review.

Avoid using it:
- More than a few times per hour. The token budget caps cycles at `budget.maxRequestsPerHour`. Manual fires count against that bucket.

### Custom lookback for a single cycle

```
POST /api/analyze?lookback_minutes=30
```

Only the on-demand endpoint accepts the override. Useful when you have just fixed something and want a 30-min look-back to confirm "no new errors since then" without waiting for the scheduled window.

</details>

<details>
<summary><strong style="font-size:1.25em;">Notifications: when do they fire?</strong></summary>

Both email and Teams send the same per-cycle digest. They share the same trigger gates and run concurrently after each cycle.

### Email trigger gates

A digest is sent only when **all** of these are true:

| Gate | Source |
|:---|:---|
| `email.enabled: true` | Helm values |
| `email.recipients` is non-empty | Helm values |
| SMTP `address` and `sender_address` are set | Chart-wide `SMTPSettings` block |
| Cycle has at least one **NEW (first-ever)** cluster, **OR** `email.onlyOnNewErrors: false`, **OR** daily mode is on | Helm values + cycle output |

If any gate fails, the analyzer logs `email digest skipped: <reason>` and moves on.

### Teams trigger gates

| Gate | Source |
|:---|:---|
| `teams.enabled: true` | Helm values |
| `teams.webhookSecretKey` (default `Observability_Teams_Webhook`) resolves to a non-empty webhook URL in the K8s Secret | Helm values + cluster Secret |
| Cycle has at least one **NEW** cluster, **OR** `teams.onlyOnNewErrors: false`, **OR** daily mode is on | Helm values + cycle output |

### Why daily mode bypasses `onlyOnNewErrors`

When you opt into a daily summary, the assumption is that you want the digest every day, even on quiet days. So daily mode flips the `onlyOnNewErrors` gate to a no-op. If you set `dailyAtUtc` you should expect a digest every cycle regardless of whether new error types appeared.

### Why Teams renders the logo and pies via data URIs

Adaptive Cards do not support `cid:` inline images. Many RPI deployments sit behind a private ingress, so Microsoft's Teams image-proxy infrastructure cannot reach the analyzer's `/api/...` endpoints. Embedding the logo and pies as base64 `data:image/png` URIs in the card payload sidesteps the network fetch entirely, so the card renders correctly on private ingress.

</details>

<details>
<summary><strong style="font-size:1.25em;">Token budget and cycle skipping</strong></summary>

The analyzer enforces hard caps on LLM calls so a runaway cycle cannot spend the budget for the whole day:

| Knob | Default | Behaviour when exceeded |
|:---|:---|:---|
| `budget.maxTokensPerHour` | `200000` | Next cycle is skipped. Logged: `budget exceeded; skipping LLM call`. |
| `budget.maxRequestsPerHour` | `60` | Same. |

The model is called **once per cycle**, not per row. So the request budget is only an issue if you trigger many on-demand cycles in a short window.

### Reading the sidebar budget bar

The dashboard sidebar shows a thin bar with the current hourly token usage. The bar fills as cycles consume tokens. When it reaches 100%, cycles will start skipping until the rolling window slides forward.

### What to do when cycles are skipping

```
budget exceeded; skipping LLM call
```

Two options:
- Wait for the rolling-hour window to age out. The budget is a sliding window, not a fixed reset time.
- Bump `maxTokensPerHour` in your overrides if your cycle is consistently larger than the cap. A cycle with many high-cluster reports can run 8 to 15K tokens.

</details>

<details>
<summary><strong style="font-size:1.25em;">Storage and persistence</strong></summary>

### Where the data lives

| Path | Contents | Survives pod restart? |
|:---|:---|:---|
| `/data/reports.db` (SQLite) | Report history, error groups, incidents, persisted rows, recurrence history | Yes (PVC) |
| `/tmp` (container fs) | Nothing important | No |

The `/data` volume is provisioned via `volumeClaimTemplates` on a StatefulSet. The default StorageClass is whatever the cluster default is (Azure Disk on AKS, EBS on EKS, PD on GKE). All of those honour POSIX byte-range locks, which SQLite needs.

### Why not Azure Files (or any SMB / NFS)

SQLite uses byte-range locks for all its file locking. Azure Files (SMB) does not implement these properly, so SQLite returns `database is locked` on a 0-byte file the first time `init` runs `executescript`. We learned this the hard way on a deployment whose FileOutputDirectory PVC didn't carry the `nobrl` mount option. The fix is **block storage** (Azure Disk / EBS / PD), which the chart now does by default.

If you ever see `database is locked` in the analyzer's startup logs, it almost certainly means `/data` is mounted on a network file share. Check the StorageClass.

### Inspecting the SQLite store

The analyzer pod does not ship with `sqlite3` CLI. To inspect, use Python (which is in the image):

```bash
kubectl exec -n <ns> rpi-observability-0 -- python3 -c "
import sqlite3
cn = sqlite3.connect('/data/reports.db')
for r in cn.execute('SELECT id, started_at, error_count, incident_count FROM reports ORDER BY id DESC LIMIT 10'):
    print(r)"
```

### Backing it up

The analyzer is a StatefulSet with `persistentVolumeClaimRetentionPolicy: Retain`. Deleting the pod (or the StatefulSet) does not delete the PVC. The data persists.

To take a snapshot of the report store at a point in time:

```bash
kubectl exec -n <ns> rpi-observability-0 -- python3 -c "
import sqlite3, sys
cn = sqlite3.connect('/data/reports.db')
sys.stdout.buffer.write(b''.join(cn.iterdump()).encode() if False else b'')
" > /tmp/reports-backup.sql
```

(Or use `cp` from inside the pod and `kubectl cp` it out.)

</details>

<details>
<summary><strong style="font-size:1.25em;">Common operator questions</strong></summary>

| Question | Answer |
|:---|:---|
| The cycle says **555 errors** but I only fixed one thing. Why? | One root cause can produce many error rows. The 555 is the row count, not the unique-error count. Look at the cluster count and the **incident count** (`X errors across Y incidents`). One incident often covers many rows from the same correlation. |
| Why does the same error appear as **multiple cards**? | Errors are grouped by the first sentence of the message after stripping volatile content (UUIDs, IPs, timestamps). If your application logs the same root cause with different first-sentence phrasing, they end up in separate cards. Have your dev team standardise the message format if this is a frequent issue. |
| How do I find **which tenant** is generating these errors? | The Tenant line on each cluster card shows the ClientID UUID prefix. Hover for the full UUID. Grep your tenant config for the prefix to find the matching customer / environment. |
| Why isn't my **email** arriving? | Walk the gate checklist: `email.enabled: true`, recipients non-empty, SMTPSettings populated, and either the cycle has new error types OR `onlyOnNewErrors: false` / daily mode. Look in the analyzer logs for `email digest skipped: <reason>`. |
| Why is no **Teams card** posting? | Same gate walk plus the webhook URL must be present in `redpoint-rpi-secrets` under the configured key (default `Observability_Teams_Webhook`). Check `kubectl get secret redpoint-rpi-secrets -o jsonpath='{.data.Observability_Teams_Webhook}' \| base64 -d`. |
| How long until my fix shows as **Resolved**? | Two cycles after the fix. See [Schedule and timing](#schedule-and-timing) above. The sparkline will drop to zero on the right edge faster, that's the practical recovery signal. |
| What does **NEW** mean? Is it forever? | An error is NEW the first time it ever shows up in any report. After that it is RECURRING forever, even if it goes quiet for weeks and returns. |
| How do I get the **raw rows** for a cluster? | Logs tab. Each report has a per-cycle .txt download with every persisted row from every cluster (capped at 500 rows per cluster). |
| Why is the **trend chart** flat? | The chart needs at least 2 cycles of data. With one cycle in the window it stays flat or shows a caption. Wait for the next cycle. |
| Why are my **pies empty**? | The cycle had no rows in that dimension (e.g. `by_plugin` is empty when no logged errors carried a Plugin tag). Empty pies render as "No data" placeholders. |

</details>


---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

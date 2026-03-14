![redpoint_logo](../chart/images/redpoint.png)
# Interaction Helm Assistant

[< Back to main README](../README.md)

## Overview

The **Interaction Helm Assistant** is an AI-powered assistant that helps you configure, deploy, and troubleshoot your RPI installation. It provides two ways to interact with the same set of tools:

- **MCP (Claude Code / Claude Desktop):** Connect via the Model Context Protocol for a terminal-based AI experience powered by Claude.
- **Web UI:** A browser-based interface with form-based tools, file management, and an AI chat assistant.

Both interfaces access the same underlying tools and search the official [RPI documentation](https://docs.redpointglobal.com/rpi) for content covering features, administration, external configuration, channels, realtime decisions, and more.

---

## Option A: MCP (Claude Code)

Use this option if you have Claude Code or another MCP-compatible client (Claude Desktop, Cursor, Windsurf, etc.).

### Prerequisites

- [Node.js](https://nodejs.org/) v18 or later

### Install Claude Code

Claude Code is a CLI tool from Anthropic that runs in your terminal. Install it with npm:

```bash
npm install -g @anthropic-ai/claude-code
```

Then launch it:

```bash
claude
```

On first run, you'll be prompted to sign in with your Anthropic account. If you don't have one, you can [sign up for a free account at claude.ai](https://claude.ai/signup). Follow the on-screen instructions to authenticate. See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for more details.

### Connect the Assistant

The Assistant is hosted by Redpoint as a public MCP endpoint. There is nothing to deploy or run in your cluster. Just run:

```bash
claude mcp add rpi-helm --transport http https://rpi-helm-assistant.redpointcdp.com/mcp --scope user
```

This only needs to be done once. The `--scope user` flag saves the server globally so it's available in every project and every future conversation. You can verify it's registered by running:

```bash
claude mcp list
```

You should see the Assistant listed with a connected status:

```
rpi-helm: https://rpi-helm-assistant.redpointcdp.com/mcp (HTTP) - ✓ Connected
```

For Claude Desktop, add the following to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "rpi-helm": {
      "type": "http",
      "url": "https://rpi-helm-assistant.redpointcdp.com/mcp"
    }
  }
}
```

---

## Option B: Web UI

Use this option for a browser-based experience with forms, file uploads/downloads, and AI chat. No MCP client required.

### Features

The Web UI includes six tabs:

| Tab | Description |
|-----|-------------|
| **AI Chat** | Natural language assistant. Ask questions, generate configs, and troubleshoot in plain English. |
| **Generate** | Form-based overrides builder. Select your platform, mode, and features from dropdowns and checkboxes. Download the generated YAML. |
| **Validate** | Upload or paste a values file. See color-coded results (errors, warnings, info) with fix suggestions. |
| **Migrate** | Upload a v7.6 values file and get a v7.7 overrides file with a summary of detected customizations. |
| **Explain** | Look up any values.yaml key path to see its type, description, defaults, and usage context. |
| **Docs** | Search the official RPI documentation and browse results inline. |

### Access

The Web UI is hosted by Redpoint. Navigate to:

```
https://rpi-helm-assistant.redpointcdp.com
```

No installation, API keys, or setup required.

---

## Available Tools

Both the MCP server and the Web UI expose the same set of tools:

| Tool | Description |
|------|-------------|
| `rpi_validate` | Validates a values file against the chart schema and RPI-specific rules |
| `rpi_generate` | Generates an overrides file for a given platform, identity provider, and feature set |
| `rpi_explain` | Explains what a setting controls, its valid values, defaults, and related keys |
| `rpi_template` | Renders Helm templates with a given values file and returns the Kubernetes manifests |
| `rpi_status` | Shows deployment health, pod status, and recent events from the cluster |
| `rpi_troubleshoot` | Diagnoses issues using pod logs, events, secrets, and ingress configuration |
| `rpi_docs_search` | Searches the official RPI product documentation by keyword |
| `rpi_docs_fetch` | Fetches a specific page from the RPI documentation site |
| `rpi_migrate` | Migrates a v7.6 values file to v7.7 format |
| `rpi_migrate_templates` | Analyzes a v7.6 templates directory for customizations to carry forward |

---

## Usage Examples

In Claude Code or the Web UI's AI Chat tab, just ask questions in plain English. In the Web UI's form tabs, use the structured inputs directly. Here are examples organized by what you're trying to do.

<details>
<summary><strong>Validate Configuration</strong></summary>

Checks your values file against the chart schema and RPI-specific rules. Returns errors with fix suggestions.

> "Validate my values file at /path/to/values.yaml"
>
> "Check my RPI config for errors"
>
> "Is my values file valid for a production deployment?"

</details>

<details>
<summary><strong>Generate Overrides</strong></summary>

Produces a ready-to-use YAML overrides file tailored to your platform, identity provider, and optional features.

> "Generate an RPI overrides file for AWS with IRSA and MongoDB cache"
>
> "Generate a values file for Azure with managed identity and Redis cache"
>
> "Generate an overrides file for GCP with Workload Identity and Bigtable cache"
>
> "Generate a minimal dev config for AWS with in-memory cache"
>
> "Generate an overrides file with Smart Activation and Realtime API enabled"

</details>

<details>
<summary><strong>Explain Settings</strong></summary>

Returns what a setting controls, its valid values, defaults, and related settings you may need to configure.

> "What does realtimeapi.cacheProvider.provider do?"
>
> "Explain cloudIdentity.enabled"
>
> "What are the valid values for secretsManagement.provider?"
>
> "What does smartActivation.enabled control?"
>
> "Explain global.deployment.platform"

</details>

<details>
<summary><strong>Render Templates</strong></summary>

Runs `helm template` and returns the rendered Kubernetes manifests so you can inspect what will be deployed.

> "Render the realtimeapi deployment template with my values file"
>
> "Show me what Kubernetes manifests my values file will produce"
>
> "Render the ingress template using my values at /path/to/values.yaml"

</details>

<details>
<summary><strong>Check Deployment Health</strong></summary>

Shows pod health, service endpoints, and recent events from your cluster.

> "What's the status of my RPI deployment in the redpoint-rpi namespace?"
>
> "Are all RPI pods healthy?"
>
> "Show me the current state of my RPI deployment"

</details>

<details>
<summary><strong>Troubleshoot Issues</strong></summary>

Analyzes pod logs, events, secrets, and ingress configuration to diagnose issues and suggest fixes.

> "Why are my RPI pods crash-looping?"
>
> "The Realtime API isn't responding, help me diagnose"
>
> "My RPI deployment is stuck in pending, what's wrong?"
>
> "Help me troubleshoot ingress issues in the redpoint-rpi namespace"

</details>

<details>
<summary><strong>Search Documentation</strong></summary>

Searches the official RPI product documentation and returns relevant content.

> "How do I configure MongoDB as a realtime cache provider?"
>
> "What are the supported queue providers in RPI?"
>
> "How do I set up Smart Activation?"
>
> "What channels does RPI support?"
>
> "How do I configure audience selection rules?"

</details>

<details>
<summary><strong>Migrate from v7.6 to v7.7</strong></summary>

Analyzes your existing configuration, remaps renamed keys, and generates a v7.7 overrides file. See the [Migration Guide](migration.md) for details.

**Values only** (use when you have not modified any Helm template files):

> "Migrate my v7.6 values file at /path/to/values.yaml to v7.7"
>
> "What changed between v7.6 and v7.7?"

**Values and templates** (use when you have added or modified Helm template files):

> "Analyze my v7.6 templates at /path/to/templates for migration to v7.7"

</details>

---

## IDE Autocomplete

The chart also includes `values.schema.json` which provides autocomplete in any YAML-aware editor (VS Code, IntelliJ, etc.) and automatic validation during `helm install` and `helm upgrade`. This works out of the box with no setup required.

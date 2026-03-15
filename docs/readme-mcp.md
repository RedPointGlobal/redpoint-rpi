![redpoint_logo](../chart/images/redpoint.png)
# Interaction Helm Assistant

[< Back to main README](../README.md)

## Overview

The **Interaction Helm Assistant** is an AI-powered assistant that helps you configure, deploy, and troubleshoot your RPI installation. It provides two ways to interact with the same set of tools:

- **Web UI:** A browser-based interface with form-based tools, AI chat, and file management. No installation required.
- **MCP (Claude Code / Claude Desktop):** Connect via the Model Context Protocol for a terminal-based AI experience powered by Claude.

Both interfaces access the same underlying tools and search the official [RPI documentation](https://docs.redpointglobal.com/rpi) and the local chart documentation.

---

## Option A: Web UI

Use this option for a browser-based experience with forms, file uploads/downloads, and AI chat. No MCP client required.

### Access

The Web UI is hosted by Redpoint. Navigate to:

```
https://rpi-helm-assistant.redpointcdp.com
```

No installation, API keys, or setup required.

### Features

The Web UI includes four tabs:

| Tab | Description |
|-----|-------------|
| **Generate** | Guided overrides builder. Walk through 9 configuration steps with a live YAML preview. |
| **Validate** | Review the generated config for errors and warnings, then download `overrides.yaml`. Also supports uploading existing files. |
| **Deploy** | Step-by-step deployment instructions: download CLI, generate secrets, deploy, verify, retrieve endpoints, activate license. |
| **Chat** | Natural language assistant. Ask questions about RPI features, chart configuration, deployment, and troubleshooting. |

---

## Option B: MCP (Claude Code)

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
rpi-helm: https://rpi-helm-assistant.redpointcdp.com/mcp (HTTP) - Connected
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

---

## Usage Examples

In Claude Code or the Web UI's Chat tab, just ask questions in plain English. In the Web UI's form tabs, use the structured inputs directly.

<details>
<summary><strong>Generate Overrides</strong></summary>

Use the Web UI Generate tab to build your overrides visually, or ask the Chat/MCP assistant:

> "Generate an RPI overrides file for Azure with MongoDB cache and Azure Service Bus"
>
> "Generate overrides for AWS with SQS queue provider and CSI secrets"
>
> "Generate a config for GCP with Workload Identity and Pub/Sub"

</details>

<details>
<summary><strong>Validate Configuration</strong></summary>

Upload your values file on the Validate tab, or ask the assistant:

> "Validate my values file"
>
> "Check my RPI config for errors"
>
> "Is my overrides file valid for a production deployment?"

</details>

<details>
<summary><strong>Explain Settings</strong></summary>

Browse the Explain tab tree, or ask:

> "What does realtimeapi.cacheProvider.provider do?"
>
> "What are the valid values for secretsManagement.provider?"
>
> "Explain the difference between shared and per-service service accounts"

</details>

<details>
<summary><strong>Search Documentation</strong></summary>

The assistant searches both the RPI product documentation and the chart documentation:

> "What are the system requirements for RPI on Kubernetes?"
>
> "How do I configure MongoDB as a realtime cache provider?"
>
> "What channels does RPI support?"
>
> "What changed between v7.6 and v7.7?"
>
> "How do I configure secrets management with Azure Key Vault?"

</details>

<details>
<summary><strong>Cluster Operations (requires cluster access)</strong></summary>

These tools require `kubectl` access to your cluster. They work when running the assistant locally or with a configured kubeconfig. On the hosted endpoint, they will report that no cluster is reachable.

**Check deployment health:**

> "What's the status of my RPI deployment?"
>
> "Are all RPI pods healthy?"

**Troubleshoot issues:**

> "Why are my RPI pods crash-looping?"
>
> "The Realtime API isn't responding, help me diagnose"

**Render templates:**

> "Show me what Kubernetes manifests my values file will produce"
>
> "Render the ingress template with my values"

</details>

---

## IDE Autocomplete

The chart also includes `values.schema.json` which provides autocomplete in any YAML-aware editor (VS Code, IntelliJ, etc.) and automatic validation during `helm install` and `helm upgrade`. This works out of the box with no setup required.

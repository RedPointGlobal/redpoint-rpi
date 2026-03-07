# AI-Assisted Operations with MCP

[< Back to main README](../README.md)

## Overview

RPI includes an [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server that lets AI assistants help you configure, deploy, and troubleshoot your RPI installation. Ask questions in plain English and the assistant will validate your configuration, generate overrides files, explain settings, and diagnose issues.

## Prerequisites

- **Node.js 18+** — Required to run the MCP server. [Download](https://nodejs.org/)
- **Helm** (optional) — Required only if you want the assistant to render templates
- **kubectl** (optional) — Required only if you want the assistant to check deployment health

## Setup

Choose the MCP client you use and add the configuration below.

### Claude Desktop

Edit your `claude_desktop_config.json`:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "rpi-helm": {
      "command": "npx",
      "args": ["-y", "@redpoint-rpi/helm-mcp"],
      "env": {
        "CHART_DIR": "/path/to/redpoint-rpi/chart"
      }
    }
  }
}
```

Restart Claude Desktop after saving.

### Claude Code

Add a `.mcp.json` file to the root of your RPI chart repository:

```json
{
  "mcpServers": {
    "rpi-helm": {
      "command": "npx",
      "args": ["-y", "@redpoint-rpi/helm-mcp"],
      "env": {
        "CHART_DIR": "./chart"
      }
    }
  }
}
```

### Other MCP Clients (Cursor, Windsurf, etc.)

Configure your client to run the following command using stdio transport:

```bash
npx -y @redpoint-rpi/helm-mcp
```

Set the `CHART_DIR` environment variable to the path to your `chart/` directory.

## Configuration

| Environment Variable | Purpose | Default |
|---------------------|---------|---------|
| `CHART_DIR` | Path to the RPI `chart/` directory | Auto-detected if run from the repo root |
| `KUBECONFIG` | Path to kubeconfig for cluster operations | Default kubectl config |

## What You Can Do

Once connected, ask your AI assistant questions like these:

### Validate a values file

> "Validate my values file at deploy/values/azure/azure.yaml"

Checks your configuration against the schema and RPI-specific rules. Returns errors with fix suggestions — catches typos, missing fields, placeholder values, and invalid provider combinations.

### Generate an overrides file

> "Generate an RPI overrides file for AWS with IRSA and MongoDB cache"

Produces a ready-to-use YAML overrides file tailored to your platform, identity provider, and optional features.

### Explain a setting

> "What does realtimeapi.cacheProvider.provider do?"

Returns what the setting controls, valid values, defaults, and related settings you may also need to configure.

### Render templates

> "Render the realtimeapi deployment template with my values file"

Runs `helm template` and returns the rendered Kubernetes manifests so you can inspect what will be deployed.

### Check deployment health

> "What's the status of my RPI deployment in the redpoint-rpi namespace?"

Shows pod health, service endpoints, and recent events from your cluster.

### Troubleshoot issues

> "Why are my RPI pods crash-looping?"

Analyzes pod logs, events, secrets, and ingress configuration to diagnose the issue and suggest specific fixes.

### Search RPI product documentation

> "How do I configure MongoDB as a realtime cache provider?"

> "What are the supported queue providers in RPI?"

Searches the official [RPI documentation](https://docs.redpointglobal.com/rpi) and returns relevant content — covering features, administration, external configuration, channels, realtime decisions, and more. You can also ask it to fetch a specific documentation page by name.

## IDE Autocomplete

The chart also includes `values.schema.json` which provides autocomplete in any YAML-aware editor (VS Code, IntelliJ, etc.) and automatic validation during `helm install` and `helm upgrade`. This works out of the box — no setup required.

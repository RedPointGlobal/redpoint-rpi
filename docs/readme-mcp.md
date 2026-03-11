![redpoint_logo](../chart/images/redpoint.png)
# Interaction Helm Copilot

[< Back to main README](../README.md)

## Overview

The **Interaction Helm Copilot** is an AI-powered assistant that helps you configure, deploy, and troubleshoot your RPI installation. Built on the [Model Context Protocol (MCP)](https://modelcontextprotocol.io), it connects to your AI assistant of choice and lets you work in plain English to validate configurations, generate overrides, explain settings, and diagnose issues.

It also searches the official [RPI documentation](https://docs.redpointglobal.com/rpi) and returns relevant content covering features, administration, external configuration, channels, realtime decisions, and more.

## Prerequisites

- An RPI deployment with `helmcopilot.enabled: true`
- An MCP-compatible AI client (Claude Code, Claude Desktop, Cursor, Windsurf, etc.)

## Setup

### 1. Enable in your overrides file

```yaml
helmcopilot:
  enabled: true
```

The chart creates a Deployment, Service, and ingress route alongside your other RPI services. The image is tagged and versioned with the rest of the RPI images.

### 2. Configure ingress hostname (optional)

The default hostname is `rpi-helmcopilot`. Override it in your overrides file if needed:

```yaml
ingress:
  hosts:
    helmcopilot: rpi-helmcopilot    # becomes rpi-helmcopilot.yourdomain.com
```

### 3. Deploy

```bash
helm upgrade --install rpi ./chart -f my-overrides.yaml -n redpoint-rpi
```

### 4. Connect your MCP client

Once deployed, the MCP server is available at `https://<helmcopilot-host>.<domain>/mcp`.

**Claude Code:**

```bash
claude mcp add rpi-helm --transport http https://rpi-helmcopilot.yourdomain.com/mcp
```

**Claude Desktop** (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "rpi-helm": {
      "type": "http",
      "url": "https://rpi-helmcopilot.yourdomain.com/mcp"
    }
  }
}
```

**Other MCP Clients (Cursor, Windsurf, etc.):**

Configure HTTP transport pointing to `https://rpi-helmcopilot.yourdomain.com/mcp`.

## What You Can Do

Once connected, ask your AI assistant questions like these:

### Validate a values file

> "Validate my values file at deploy/values/azure/azure.yaml"

Checks your configuration against the schema and RPI-specific rules. Returns errors with fix suggestions. Catches typos, missing fields, placeholder values, and invalid provider combinations.

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

### Migrate from v7.6 to v7.7 (simple)

> "Migrate my v7.6 values file at /path/to/values.yaml to v7.7"

Analyzes your existing v7.6 values configuration, identifies customizations vs defaults, remaps renamed keys, and generates a minimal v7.7 overrides file. Warns about breaking changes that need manual attention. Use this when you have not modified any Helm template files.

### Migrate from v7.6 to v7.7 (advanced)

> "Analyze my v7.6 templates at /path/to/chart/templates for migration to v7.7"

Compares your v7.6 template files against the stock v7.6 templates to find custom files you added and stock templates you modified. For modified files, shows a diff and provides guidance on how to carry the changes forward to v7.7. Use this when you have added or modified Helm template files beyond just values.yaml.

See the [Migration Guide](migration.md) for details.

### Search RPI product documentation

> "How do I configure MongoDB as a realtime cache provider?"

> "What are the supported queue providers in RPI?"

## IDE Autocomplete

The chart also includes `values.schema.json` which provides autocomplete in any YAML-aware editor (VS Code, IntelliJ, etc.) and automatic validation during `helm install` and `helm upgrade`. This works out of the box with no setup required.

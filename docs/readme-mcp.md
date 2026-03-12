![redpoint_logo](../chart/images/redpoint.png)
# Interaction Helm Copilot

[< Back to main README](../README.md)

## Overview

The **Interaction Helm Copilot** is an AI-powered assistant that helps you configure, deploy, and troubleshoot your RPI installation. Built on the [Model Context Protocol (MCP)](https://modelcontextprotocol.io), it connects to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and lets you validate configurations, generate overrides, explain settings, and diagnose issues in plain English.

It also searches the official [RPI documentation](https://docs.redpointglobal.com/rpi) and returns relevant content covering features, administration, external configuration, channels, realtime decisions, and more.

## Prerequisites

- [Node.js](https://nodejs.org/) v18 or later

## Install Claude Code

Claude Code is a CLI tool from Anthropic that runs in your terminal. Install it with npm:

```bash
npm install -g @anthropic-ai/claude-code
```

Then launch it:

```bash
claude
```

On first run, you'll be prompted to sign in with your Anthropic account. Follow the on-screen instructions to authenticate. See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for more details.

## Connect the Copilot

The Copilot is hosted by Redpoint as a public MCP endpoint. There is nothing to deploy or run in your cluster. Just run:

```bash
claude mcp add rpi-helm --transport http https://helmcopilot.redpointcdp.com/mcp
```

That's it. Start a new conversation and the Copilot tools are available immediately.

## Available Tools

The Copilot exposes the following tools:

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

## Usage Examples

Once connected, ask questions like these:

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

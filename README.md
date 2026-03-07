# @redpoint-rpi/helm-mcp

MCP (Model Context Protocol) server for the Redpoint RPI Helm chart. Enables AI assistants to validate configurations, generate overrides files, render templates, explain settings, diagnose deployments, and search the RPI product documentation.

## Quick Start

```bash
npm install
npm run build
```

## Usage

This package is intended to be run via `npx` from an MCP client. See the [setup guide](https://github.com/redpoint/redpoint-rpi/docs/readme-mcp.md) in the Helm chart repo for client configuration (Claude Desktop, Claude Code, Cursor, etc.).

```bash
npx -y @redpoint-rpi/helm-mcp
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CHART_DIR` | Path to the RPI `chart/` directory | Auto-detected relative to package |
| `DOCS_DIR` | Path to the RPI `docs/` directory | Auto-detected relative to package |
| `KUBECONFIG` | Path to kubeconfig for cluster operations | Default kubectl config |

## Tools

| Tool | Purpose | Requires |
|------|---------|----------|
| `rpi_validate` | Validate a values file against the JSON Schema and heuristic rules | — |
| `rpi_generate` | Generate a valid overrides file from parameters | — |
| `rpi_template` | Render Helm templates from a values file | Helm CLI |
| `rpi_explain` | Explain what a configuration key does | — |
| `rpi_status` | Check deployment health (pods, services, ingress) | kubectl |
| `rpi_troubleshoot` | Diagnose common deployment issues | kubectl |
| `rpi_docs_search` | Search the official RPI documentation site | Internet |
| `rpi_docs_fetch` | Fetch a specific RPI documentation page | Internet |

## Resources

| URI | Content |
|-----|---------|
| `rpi://schema` | JSON Schema for values.yaml |
| `rpi://reference` | Complete values reference |
| `rpi://docs/greenfield` | New installation guide |
| `rpi://docs/migration` | v7.6 to v7.7 migration guide |
| `rpi://docs/argocd` | ArgoCD deployment guide |
| `rpi://docs/values` | Values & overrides guide |
| `rpi://docs/terraform` | Terraform deployment guide |

## License

Proprietary — Redpoint Global Inc.

# CLAUDE.md — RPI Helm Chart

## Project Overview

This is the Helm chart for Redpoint Interaction (RPI), a multi-service platform deployed on Kubernetes. The chart supports Azure, AWS, Google Cloud, and self-hosted environments.

## Architecture

The chart uses a **three-tier merge** system for configuration:

1. `chart/templates/_defaults.tpl` — Internal defaults (never edit)
2. `advanced:` block in user's overrides file — Overrides internal defaults
3. Top-level keys in user's overrides file — Highest priority

Merging happens via `mustMergeOverwrite` in `_helpers.tpl`. Each component has a named template (e.g., `rpi.defaults.realtimeapi`) and a merge helper (e.g., `rpi.merged.realtimeapi`).

## Key Directories

```
chart/                    # The Helm chart
  Chart.yaml              # Chart metadata
  values.yaml             # User-facing defaults (only set what you customize)
  values.schema.json      # JSON Schema for validation
  templates/
    _defaults.tpl          # All internal defaults
    _helpers.tpl           # Merge helpers, validation, cloud identity helpers
    deploy-*.yaml          # Service deployment templates
    job-*.yaml             # Automation jobs (postinstall, preflight, upgrade)
deploy/
  cli/rpi-init.sh          # Interactive overrides generator
  terraform/modules/       # IaC modules (azure, aws, google)
  values/                  # Example overrides files
    azure/azure.yaml
    aws/amazon.yaml
    demo/demo.yaml
docs/                      # Documentation
  values-reference.yaml    # Complete reference of every key
```

## How to Test Changes

Always validate with helm template after any chart change:

```bash
# Test with demo values (fastest, no external dependencies)
helm template rpi ./chart -f deploy/values/demo/demo.yaml

# Test with all three platform values
helm template rpi ./chart -f deploy/values/azure/azure.yaml
helm template rpi ./chart -f deploy/values/aws/amazon.yaml
```

## Common Patterns

### Adding a new value to a service

1. Add the default in `_defaults.tpl` inside the service's `define` block
2. Reference it in the deploy template via `$cfg.yourNewKey`
3. Document it in `docs/values-reference.yaml`
4. If it should be user-facing, add it to `chart/values.yaml`
5. Add it to `chart/values.schema.json`

### Adding a new service

1. Create defaults block in `_defaults.tpl`
2. Create merge helper in `_helpers.tpl`
3. Create deploy template `chart/templates/deploy-yourservice.yaml`
4. Add to `values.yaml` and `values.schema.json`

### Cloud Identity

All cloud identity logic is in shared helpers in `_helpers.tpl`:
- `rpi.cloudidentity.saAnnotations` — ServiceAccount annotations per platform
- `rpi.cloudidentity.podLabels` — Pod labels (Azure Workload Identity)
- `rpi.cloudidentity.envvars` — IRSA env vars (Amazon) / Google credentials
- `rpi.secrets.sdk.envvars` — KeyVault env vars for SDK vault mode
- `rpi.validateConfig` — Fails early if sdk/csi without cloudIdentity

Do NOT duplicate cloud identity logic in individual deploy templates — use the helpers.

### Empty annotations bug

When using `{{- with .Values.customAnnotations }}` to conditionally render annotations, always guard the `annotations:` key itself:

```yaml
# WRONG — produces empty "annotations:" when customAnnotations is {}
  annotations:
    {{- with .Values.customAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}

# RIGHT — only emits "annotations:" when there are values
  {{- with .Values.customAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
```

## Conventions

- Branch: `release/v7.7`, main branch: `main`
- Image tag format: `major.minor.YYYYMMDD.HHMM` (e.g., `7.7.20260220.1524`)
- Service naming: `rpi-<servicename>` (e.g., `rpi-realtimeapi`)
- All .NET services listen on port 8080 internally, exposed as port 80 via Service
- Security context: runAsUser/runAsGroup 7777, drop ALL capabilities
- Demo mode: `global.deployment.mode: demo` deploys embedded MSSQL + MongoDB

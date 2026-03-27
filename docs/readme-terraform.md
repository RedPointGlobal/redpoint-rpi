![redpoint_logo](../chart/images/redpoint.png)
# Automation Guide

[< Back to main README](../README.md)

## Overview

The [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab generates cloud-native CLI scripts and CI/CD pipeline files tailored to your configuration.

<details>
<summary><strong style="font-size:1.25em;">CI/CD Pipelines</strong></summary>

The [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab generates ready-to-use CI/CD pipeline files for deploying RPI via Helm. Pipelines are built from your Generate tab configuration.

### Supported Pipeline Tools

| Tool | File generated |
|:-----|:---------------|
| **GitHub Actions** | `.github/workflows/rpi-deploy.yml` |
| **Azure DevOps** | `azure-pipelines.yml` |
| **GitLab CI** | `.gitlab-ci.yml` |

### What the Pipeline Does

Each generated pipeline includes:

1. **Checkout** the chart repository
2. **Configure** cloud credentials (Azure, AWS, or GCP)
3. **Helm upgrade/install** with your overrides file
4. **Rollout monitoring** to verify pods are healthy

### Optional: Image Mirroring

When enabled, the pipeline adds a step to mirror RPI container images from the Redpoint Container Registry into your own registry before deploying. This is useful for air-gapped environments or organizations that require all images to come from an internal registry.

### Getting Started

1. Go to the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com)
2. Configure your deployment in the **Generate** tab
3. Switch to the **Automate** tab and select **CI/CD Pipeline**
4. Choose your pipeline tool and download the generated file
5. Add your overrides file and the pipeline to your repository

</details>

<details>
<summary><strong style="font-size:1.25em;">Vault Secrets Setup</strong></summary>

The **Automate** tab generates cloud-native CLI scripts for creating vault secrets and configuring identity for your platform:

| Platform | What it generates |
|:---------|:------------------|
| **Azure** | `az keyvault secret set` commands, managed identity creation, workload identity federation |
| **Amazon** | `aws secretsmanager` commands, IAM role creation, IRSA trust policy |
| **Google** | `gcloud secrets create` commands, service account creation, workload identity binding |

Each script creates all required vault secrets (database, realtime, SMTP, callback, Redpoint AI, Rebrandly) with the correct naming convention for your secrets provider (SDK or CSI).

### Getting Started

1. Go to the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com)
2. Switch to the **Automate** tab
3. Expand your cloud platform (Azure, Amazon, or Google)
4. Select **Vault Secrets Setup**
5. Fill in your environment details and download the script

</details>

<details>
<summary><strong style="font-size:1.25em;">Entra ID Setup</strong></summary>

The **Automate** tab > **Azure** > **Entra ID Setup** generates an `az` CLI script for configuring Microsoft Entra ID (formerly Azure AD) authentication for the RPI Interaction API. The script creates the required app registrations, API permissions, and redirect URIs.

</details>

<details>
<summary><strong style="font-size:1.25em;">GitOps (ArgoCD / Flux)</strong></summary>

GitOps is an operational model where your deployment state is declared in Git. A controller (ArgoCD, Flux) watches your repository and automatically reconciles the cluster to match.

### Why GitOps for RPI

- Every change is a Git commit with author, timestamp, and diff
- Rollback by reverting a commit
- Dev, staging, and production deploy the same way
- Self-healing: manual cluster changes are reverted automatically

### Repository Setup

Keep the chart and your overrides in separate repositories:

```
# Chart source (clean import of upstream, no edits)
https://git.yourorg.com/platform/redpoint-rpi.git

# Config repo (overrides per environment)
https://git.yourorg.com/platform/rpi-config.git
  rpi/
    dev.yaml
    staging.yaml
    production.yaml
```

Import the upstream chart into your internal repository for security scanning and change control:

```bash
git clone https://github.com/RedPointGlobal/redpoint-rpi.git
cd redpoint-rpi && git checkout main
git remote add internal https://git.yourorg.com/platform/redpoint-rpi.git
git push internal main
```

### ArgoCD Application (Multi-Source)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rpi-production
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://git.yourorg.com/platform/redpoint-rpi.git
      targetRevision: main
      path: chart
      helm:
        valueFiles:
          - $config/rpi/production.yaml
    - repoURL: https://git.yourorg.com/platform/rpi-config.git
      targetRevision: main
      ref: config
  destination:
    server: https://kubernetes.default.svc
    namespace: rpi-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  ignoreDifferences:
    - group: ""
      kind: Secret
      jsonPointers:
        - /data
```

### ApplicationSet (Multi-Environment)

Manage all environments from a single definition:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: rpi
  namespace: argocd
spec:
  generators:
    - list:
        elements:
        - env: dev
          namespace: rpi-dev
          valuesFile: rpi/dev.yaml
        - env: staging
          namespace: rpi-staging
          valuesFile: rpi/staging.yaml
        - env: production
          namespace: rpi-production
          valuesFile: rpi/production.yaml
  template:
    metadata:
      name: rpi-{{env}}
    spec:
      project: default
      sources:
        - repoURL: https://git.yourorg.com/platform/redpoint-rpi.git
          targetRevision: main
          path: chart
          helm:
            valueFiles:
              - $config/{{valuesFile}}
        - repoURL: https://git.yourorg.com/platform/rpi-config.git
          targetRevision: main
          ref: config
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Version Pinning

| Strategy | `targetRevision` | When to use |
|:---------|:-----------------|:------------|
| Track latest | `main` | Dev/staging |
| Pin to a tag | `v7.7.1` | Production |
| Pin to a commit | `abc123def` | Maximum stability |

### Pulling Chart Updates

```bash
cd redpoint-rpi
git fetch origin
git push internal main
```

No merge conflicts since you don't edit the chart. Your overrides stay in the config repo.

### Troubleshooting

- **"helm template failed"**: Ensure `path` points to `chart` (where `Chart.yaml` lives), not the repo root.
- **Values file not found**: When using multi-source, the `$config` ref must match the `ref:` name on the config source.
- **Secrets diff on every sync**: Add `ignoreDifferences` for Secrets (see Application example above).

</details>

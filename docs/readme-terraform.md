# CI/CD & Automation Guide

This guide covers automating RPI deployments with CI/CD pipelines, plus pointers to the cloud setup and GitOps options. RPI installs with a single `helm upgrade --install`; automation simply runs that for you on every change to your configuration.

## CI/CD Pipelines

Run `helm upgrade --install` from your pipeline so every commit to your overrides deploys RPI. The same flow works on any runner.

### Pipeline definitions

| Tool | File path |
|:-----|:----------|
| GitHub Actions | `.github/workflows/rpi-deploy.yml` |
| Azure DevOps | `azure-pipelines.yml` |
| GitLab CI | `.gitlab-ci.yml` |

### What the pipeline does

Each pipeline performs the same four steps:

1. **Checkout** the chart repository (or your internal mirror) and your overrides file
2. **Authenticate** to your cloud (Azure, AWS, or GCP) and to the cluster
3. **Helm upgrade/install** with your overrides file
4. **Verify** the rollout completes and pods are healthy

### Example: GitHub Actions

```yaml
name: Deploy RPI
on:
  push:
    paths:
      - "overrides/**"
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - name: Authenticate to the cluster
        run: az aks get-credentials --resource-group <rg> --name <cluster>
      - name: Deploy
        run: |
          helm upgrade --install rpi ./chart \
            -f overrides/production.yaml \
            -n redpoint-rpi --create-namespace
      - name: Wait for rollout
        run: kubectl rollout status deploy -n redpoint-rpi --timeout=10m
```

Store the cluster credentials and any cloud service-principal secrets in your CI system's secret store - never commit them to the repository.

### Optional: image mirroring

For air-gapped environments or organizations that require all images to come from an internal registry, add a step that mirrors the RPI container images from the Redpoint Container Registry into your own registry before the Helm step, and set `global.deployment.images.registry` in your overrides to that registry.

## Cloud secrets & identity

A pipeline needs the deployment's secrets in place before it installs. Create them once per environment:

- **Application secrets** (database, realtime cache, SMTP, callback, and so on): see the Secrets Management guide. With the `kubernetes` provider you apply a generated `secrets.yaml`; with `sdk` or `csi` the secrets come from your cloud vault.
- **Cloud identity** (Azure Workload Identity, AWS IRSA, GCP Workload Identity Federation): see the Cloud Identity section of the Values Reference.

## Authentication (Entra ID / SSO)

For Microsoft Entra ID or OpenID Connect (Okta, Keycloak) authentication on the Interaction API, see the Single Sign-On guide.

## GitOps (ArgoCD)

For a declarative, continuously-reconciled alternative to pipeline-driven `helm upgrade`, deploy RPI with ArgoCD: store your overrides in Git and let the controller reconcile the cluster to match. See the ArgoCD / GitOps guide for Application and ApplicationSet examples, repository layout, and version-pinning strategies.

![redpoint_logo](../chart/images/redpoint.png)
# Deploying Redpoint RPI with ArgoCD

[< Back to main README](../README.md)

## What is GitOps?

GitOps is an operational model where your entire deployment state — application configuration, infrastructure, and release versions — is declared in Git. Instead of running `helm upgrade` manually, a GitOps controller watches your repository and automatically reconciles the cluster to match what's committed.

**Benefits for RPI deployments:**

- **Audit trail** — every change is a Git commit with author, timestamp, and diff
- **Rollback** — revert a deployment by reverting a commit
- **Consistency** — dev, staging, and production all deploy the same way
- **Self-healing** — if someone manually changes a resource in the cluster, the controller reverts it

## What is ArgoCD?

[ArgoCD](https://argo-cd.readthedocs.io/en/stable/) is a Kubernetes-native GitOps controller. It watches one or more Git repositories, renders Helm charts (or plain YAML), and applies the result to your cluster. It provides a web UI for visualizing deployments, a CLI for scripting, and built-in health monitoring.

For full documentation, see the [ArgoCD Getting Started Guide](https://argo-cd.readthedocs.io/en/stable/getting_started/).

## Repository Access

ArgoCD needs read access to the Git repository containing the Helm chart. You have two options:

### Option 1: Use the public repository directly

Point ArgoCD to the public GitHub repository. This is the simplest setup — ArgoCD pulls the chart on each sync.

```yaml
source:
  repoURL: https://github.com/RedPointGlobal/redpoint-rpi.git
  targetRevision: main
  path: chart
```

### Option 2: Import into your internal repository (recommended for production)

Fork or mirror the RPI repository into your organization's internal Git server (GitHub Enterprise, GitLab, Bitbucket, Azure DevOps, etc.). This gives you:

- **No external dependency** — syncs work even if GitHub is unreachable
- **Change control** — review upstream updates before they reach your clusters
- **Network compliance** — ArgoCD never reaches outside your network

To set this up:

1. Create an internal repository (e.g., `https://git.yourorg.com/platform/redpoint-rpi.git`)
2. Mirror the public repo:
   ```bash
   git clone --mirror https://github.com/RedPointGlobal/redpoint-rpi.git
   cd redpoint-rpi.git
   git remote set-url origin https://git.yourorg.com/platform/redpoint-rpi.git
   git push --mirror
   ```
3. To pull upstream updates periodically:
   ```bash
   git remote add upstream https://github.com/RedPointGlobal/redpoint-rpi.git
   git fetch upstream
   git push origin --all
   git push origin --tags
   ```
4. Update your ArgoCD Application to point to the internal URL:
   ```yaml
   source:
     repoURL: https://git.yourorg.com/platform/redpoint-rpi.git
     targetRevision: main
     path: chart
   ```

Register the internal repository in ArgoCD:

```bash
argocd repo add https://git.yourorg.com/platform/redpoint-rpi.git \
  --username <user> --password <token>
```

## Repository Layout

ArgoCD needs to know two things: where the chart lives and where your values file lives.

```
redpoint-rpi/               (this repo)
├── chart/                   <- ArgoCD Application path
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── deploy/
    └── values/               <- Your overrides
        ├── azure/azure.yaml
        ├── aws/amazon.yaml
        └── demo/demo.yaml
```

## Single-Environment Application

The simplest setup — one ArgoCD Application per environment.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rpi-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/RedPointGlobal/redpoint-rpi.git
    targetRevision: main
    path: chart
    helm:
      valueFiles:
        - ../deploy/values/azure/azure.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: rpi-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Multiple Environments

Create one Application per environment, changing only the values file and namespace:

```yaml
# rpi-dev
spec:
  source:
    path: chart
    helm:
      valueFiles:
        - ../deploy/values/demo/demo.yaml
  destination:
    namespace: rpi-dev

# rpi-staging
spec:
  source:
    path: chart
    helm:
      valueFiles:
        - ../deploy/values/azure/azure.yaml
  destination:
    namespace: rpi-staging
```

## ApplicationSet (Recommended for Multi-Environment)

Use an ApplicationSet to manage all environments from a single definition:

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
            valuesFile: demo/demo.yaml
          - env: staging
            namespace: rpi-staging
            valuesFile: azure/azure.yaml
          - env: production
            namespace: rpi-production
            valuesFile: azure/azure.yaml
  template:
    metadata:
      name: rpi-{{env}}
    spec:
      project: default
      source:
        repoURL: https://github.com/RedPointGlobal/redpoint-rpi.git
        targetRevision: main
        path: chart
        helm:
          valueFiles:
            - ../deploy/values/{{valuesFile}}
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

## Separate Config Repository

If you keep your deployment overrides in a separate Git repo (recommended for production), use multiple sources:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rpi-production
  namespace: argocd
spec:
  project: default
  sources:
    # Source 1: The chart
    - repoURL: https://github.com/RedPointGlobal/redpoint-rpi.git
      targetRevision: main
      path: chart
      helm:
        valueFiles:
          - $values/rpi/production.yaml

    # Source 2: Your config repo
    - repoURL: https://github.com/your-org/platform-config.git
      targetRevision: main
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: rpi-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Your config repo would contain:

```
platform-config/
└── rpi/
    ├── dev.yaml
    ├── staging.yaml
    └── production.yaml
```

This pattern keeps secrets and environment config separate from the chart source.

## Version Pinning

### Staying on v7.6

Set `targetRevision` to the maintenance branch:

```yaml
source:
  repoURL: https://github.com/RedPointGlobal/redpoint-rpi.git
  targetRevision: release/v7.6
  path: chart
```

### Pinning to a Specific Commit

For maximum stability, pin to a Git tag or commit SHA:

```yaml
source:
  targetRevision: v7.7.0             # Git tag
  # or
  targetRevision: abc123def456       # Commit SHA
```

### Upgrading from v7.6 to v7.7

1. Prepare your new overrides file following the [migration guide](readme-values.md#migrating-from-the-previous-valuesyaml).
2. Test with a dry run:
   ```bash
   argocd app diff rpi-staging --local chart --values ../deploy/values/azure/azure.yaml
   ```
3. Update `targetRevision` from `release/v7.6` to `main` (or a v7.7 tag).
4. Update `valueFiles` to point to your new overrides file.
5. Sync staging first, verify, then promote to production.

## Troubleshooting

### "helm template failed" on sync

Ensure `path` points to `chart` (where `Chart.yaml` lives), not the repo root.

### Values file not found

When using `valueFiles: [../deploy/values/azure/azure.yaml]`, the path is relative to the chart directory. The `../` prefix navigates up to the repo root and then into `deploy/values/`.

### Out of sync after chart upgrade

This is expected when upgrading from v7.6 to v7.7. The new defaults in `_defaults.tpl` may change rendered manifests even if your overrides haven't changed. Review the diff, verify it matches expectations, then sync.

### Secrets appearing in ArgoCD diff

ArgoCD shows diffs for all managed resources. If secrets show as changed on every sync, add them to the ignore list:

```yaml
spec:
  ignoreDifferences:
    - group: ""
      kind: Secret
      jsonPointers:
        - /data
```

![redpoint_logo](../chart/images/redpoint.png)
# Automation Guide

[< Back to main README](../README.md)

## Overview

RPI deployment can be automated with Terraform for infrastructure provisioning and CI/CD pipelines for continuous delivery. The [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Automate** tab generates both Terraform modules and CI/CD pipeline files tailored to your configuration.

| Tool | What it generates |
|:-----|:------------------|
| **Terraform** | Infrastructure modules (identity, database, secrets store) + Helm release |
| **CI/CD Pipelines** | GitHub Actions, Azure DevOps, or GitLab CI workflows for Helm deploy with optional image mirroring |

---

## Terraform

The Terraform modules in `deploy/terraform/modules/` provision cloud infrastructure and generate a valid Helm overrides file from the provisioned resource outputs. This gives you a single `terraform apply` that creates everything needed for RPI: database, identity, secrets store, and a ready-to-use values file.

## Available Modules

| Module | Cloud | Resources |
|--------|-------|-----------|
| `modules/azure` | Azure | Managed Identity, Federated Credential, Azure SQL, Key Vault (optional) |
| `modules/aws` | AWS | IRSA Role, RDS SQL Server, Secrets Manager (optional) |
| `modules/google` | GCP | GCP Service Account, WI Binding, Cloud SQL, Secret Manager (optional) |

Each module outputs a `helm_values_path` pointing to the generated overrides YAML.

## Quick Start

### Azure Example

```hcl
module "rpi" {
  source = "github.com/RedPointGlobal/redpoint-rpi//deploy/terraform/modules/azure?ref=main"

  resource_group_name = "rg-rpi-production"
  location            = "eastus"
  ingress_domain      = "rpi.example.com"
  sql_admin_password  = var.sql_password
  aks_oidc_issuer_url = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

# Deploy with Helm
resource "helm_release" "rpi" {
  name       = "rpi"
  chart      = "${path.root}/../../chart"
  namespace  = "redpoint-rpi"
  values     = [file(module.rpi.helm_values_path)]
}

```

### AWS Example

```hcl
module "rpi" {
  source = "github.com/RedPointGlobal/redpoint-rpi//deploy/terraform/modules/aws?ref=main"

  vpc_id                = "vpc-abc123"
  subnet_ids            = ["subnet-1", "subnet-2"]
  ingress_domain        = "rpi.example.com"
  rds_admin_password    = var.rds_password
  eks_cluster_name      = "my-eks-cluster"
  eks_oidc_provider_arn = data.aws_iam_openid_connect_provider.eks.arn
  eks_oidc_provider_url = data.aws_iam_openid_connect_provider.eks.url
}
```

### Google Cloud Example

```hcl
module "rpi" {
  source = "github.com/RedPointGlobal/redpoint-rpi//deploy/terraform/modules/google?ref=main"

  project_id         = "my-gcp-project"
  ingress_domain     = "rpi.example.com"
  sql_admin_password = var.sql_password
}
```

## What Gets Created

Each module creates:

1. **Identity:** A cloud identity (Managed Identity / IAM Role / GCP Service Account) configured for Kubernetes workload identity federation
2. **Database:** An operational database (Azure SQL / RDS SQL Server / Cloud SQL) with two databases: `Pulse` and `Pulse_Logging`
3. **Secrets** (optional): A cloud secrets store (Key Vault / Secrets Manager / Secret Manager) when `enable_keyvault` / `enable_secrets_manager` / `enable_secret_manager` is set
4. **Helm Values:** A generated `rpi-values.yaml` file with all connection details populated from Terraform outputs

## Generated Values File

The generated file is minimal. It contains only the values derived from provisioned resources. You can extend it by merging with additional overrides:

```hcl
resource "helm_release" "rpi" {
  name      = "rpi"
  chart     = "${path.root}/../../chart"
  namespace = "redpoint-rpi"

  # Base values from Terraform
  values = [file(module.rpi.helm_values_path)]

  # Additional overrides
  set {
    name  = "realtimeapi.replicas"
    value = "3"
  }

}
```

Or use multiple values files:

```bash
helm upgrade --install rpi ./chart \
  -f $(terraform output -raw helm_values_path) \
  -f my-additional-overrides.yaml \
  -n redpoint-rpi
```

## Customization

All modules accept common variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `name_prefix` | Prefix for resource names | `rpi` |
| `kubernetes_namespace` | Target K8s namespace | `redpoint-rpi` |
| `rpi_image_tag` | RPI image version | `7.7.20260220.1524` |
| `ingress_domain` | Ingress domain | (required) |
| `tags` / `labels` | Resource tags | `{}` |

See each module's `variables.tf` for the full list.

## Prerequisites

- Terraform >= 1.5
- An existing Kubernetes cluster (AKS / EKS / GKE) with OIDC enabled
- Appropriate cloud provider configured (`azurerm` >= 3.0, `aws` >= 5.0, `google` >= 5.0)

## Examples

Complete usage examples are in `deploy/terraform/examples/`:

```
deploy/terraform/examples/
├── azure-complete/main.tf
├── aws-complete/main.tf
└── google-complete/main.tf
```

Each example shows a full module invocation with provider configuration and optional Helm deployment.

---

## CI/CD Pipelines

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

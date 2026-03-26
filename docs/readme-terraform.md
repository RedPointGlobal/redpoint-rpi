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

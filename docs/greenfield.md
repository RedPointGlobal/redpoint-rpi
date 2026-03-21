![redpoint_logo](../chart/images/redpoint.png)
# New Installation (Greenfield)

[< Back to main README](../README.md)

This guide walks through deploying RPI from scratch in a new environment, meaning new cluster, new databases, new cache and queue providers.

---

## System Requirements

| Component | Requirement |
|:----------|:------------|
| **Kubernetes** | Latest stable version from a [certified provider](https://kubernetes.io/docs/setup/production-environment/turnkey-solutions/). Minimum two nodes (8 vCPU, 32 GB RAM each). |
| **Operational DB** | SQL Server or PostgreSQL (cloud-hosted or VM). Minimum 8 GB RAM, 200 GB disk. |
| **CLI Tools** | `kubectl`, `helm` v3, `python3` (with PyYAML), `git`, `bash` |

**Example node SKUs:**

| Azure | AWS | GCP |
|-------|-----|-----|
| D8s_v5 | m5.2xlarge | n2-standard-8 |

## Prerequisites

Before starting, ensure you have:

- **Redpoint Container Registry**: Open a [Support](mailto:support@redpointglobal.com) ticket requesting access to download RPI images.
- **RPI License**: Open a [Support](mailto:support@redpointglobal.com) ticket to obtain your RPI v7 license activation key.
- **Single Sign-On** (optional): If using Microsoft Entra ID or an OIDC provider (Keycloak, Okta), complete the identity provider setup before deploying. See the [Single Sign-On Guide](single-sign-on.md).

---

## Get Started

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) for a guided deployment experience. The Web UI walks you through the entire process:

| Tab | What it does |
|-----|-------------|
| **Generate** | Select your platform, configure features step by step, and preview your overrides file in real time |
| **Validate** | Review the generated configuration for errors or warnings, then download `overrides.yaml` |
| **Deploy** | Download the CLI, generate secrets, deploy to your cluster, retrieve endpoints, and activate your license |
| **Reference** | Search and browse every configurable key in the Helm chart |
| **Chat** | Ask questions about RPI features, configuration, or troubleshooting in plain English |

---

## Next Steps

Use the [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com) **Reference** tab to browse every available key, or ask the **Chat** for help with specific features.

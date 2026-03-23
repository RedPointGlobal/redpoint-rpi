![redpoint_logo](chart/images/redpoint.png)
## Interaction (RPI) | Deployment on Kubernetes

With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

This chart deploys RPI on Kubernetes using Helm.

![architecture](chart/images/diagram.png)

## Choose Your Path

| | New Installation | Upgrading from v7.6 | AI-Assisted |
|:---|:---|:---|:---|
| **Guide** | [Greenfield Installation](docs/greenfield.md) | [Migration Guide](docs/migration.md) | [Helm Assistant](docs/readme-mcp.md) |
| **When to use** | New cluster, databases, cache, and queue providers | Existing v7.6 deployment with existing infrastructure | Any scenario. Validates configs, generates overrides, diagnoses issues, and answers questions in plain English |
| **Databases** | Created from scratch | Existing databases are reused | Generates the correct database configuration for your platform |

---

## Additional Guides

| Guide | Description |
|:------|:------------|
| [Helm Assistant](docs/readme-mcp.md) | Web UI and MCP endpoint for AI-assisted configuration and troubleshooting |
| [Values Guide](docs/readme-values.md) | How the two-tier values system works, override patterns, and complete values reference |
| [Secrets Management](docs/secrets-management.md) | Providers (Kubernetes, CSI, SDK), required vault keys, and image pull secrets |
| [Single Sign-On](docs/single-sign-on.md) | Microsoft Entra ID and OpenID Connect (Keycloak, Okta) authentication setup |
| [RPI Helm CLI](docs/readme-cli.md) | Pre-flight checks, secrets generation, deployment, status, and troubleshooting |
| [Automation Guide](docs/readme-terraform.md) | Infrastructure-as-code modules for Azure, AWS, and GCP |
| [GitOps Guide](docs/readme-argocd.md) | Deploying with ArgoCD or Flux |

## Resources

- [RPI Product Documentation](https://docs.redpointglobal.com/rpi/)
- [Support](mailto:support@redpointglobal.com) (RPI application issues)
- [www.redpointglobal.com](https://www.redpointglobal.com)

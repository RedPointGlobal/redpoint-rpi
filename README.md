![redpoint_logo](chart/images/redpoint.png)
## Interaction (RPI) | Deployment on Kubernetes

With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

This chart deploys RPI on Kubernetes using Helm.

![architecture](chart/images/diagram.png)

## Choose Your Path

| | New Installation | Upgrading from v7.6 | AI-Assisted |
|:---|:---|:---|:---|
| **Guide** | [Greenfield Installation](docs/greenfield.md) | [Upgrade Guide](docs/migration.md) | [Helm Assistant](docs/readme-mcp.md) |
| **When to use** | New cluster, databases, cache, and queue providers | Existing v7.6 deployment with existing infrastructure | Any scenario. Validates configs, generates overrides, diagnoses issues, and answers questions in plain English |
| **Databases** | Created from scratch | Existing databases are reused | Generates the correct database configuration for your platform |

---

## Additional Guides

| Guide | Description |
|:------|:------------|
| [Values Guide](docs/readme-values.md) | Two-tier values system and complete values reference |
| [Secrets Management](docs/secrets-management.md) | Kubernetes, CSI, and SDK providers with required vault keys |
| [Single Sign-On](docs/single-sign-on.md) | Microsoft Entra ID and OpenID Connect (Okta) setup |
| [Ingress](docs/ingress.md) | Chart-managed nginx, BYO controller, and AWS ALB |
| [Storage](docs/storage.md) | Static and dynamic provisioning across platforms |
| [RPI Helm CLI](docs/readme-cli.md) | Pre-flight, secrets, deployment, and troubleshooting |
| [Automation](docs/readme-terraform.md) | CI/CD pipelines and vault secrets setup scripts |
| [GitOps](docs/readme-argocd.md) | Deploying with ArgoCD or Flux |

## Resources

- [RPI Product Documentation](https://docs.redpointglobal.com/rpi/)
- [Support](mailto:support@redpointglobal.com) (RPI application issues)
- [www.redpointglobal.com](https://www.redpointglobal.com)

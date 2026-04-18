![redpoint_logo](chart/images/redpoint.png)
## Interaction (RPI) | Deployment on Kubernetes

With Redpoint® Interaction you can define your audience and execute highly personalized, cross-channel campaigns – all from a single visual interface. This simplified environment frees you up to create the compelling experiences that will keep your customers actively engaged with your brand.

This chart deploys RPI on Kubernetes using Helm.

![architecture](chart/images/diagram.png)

## Choose Your Path

| | New Installation | Upgrading from v7.6 | AI-Assisted | Agentic (Azure) |
|:---|:---|:---|:---|:---|
| **Guide** | [Greenfield](docs/greenfield.md) | [Upgrade](docs/migration.md) | [Helm Assistant](docs/readme-mcp.md) | [Agentic Deployment](deploy/agentic/azure/README.md) |
| **When to use** | New cluster, databases, cache, and queue providers | Existing v7.6 deployment | Any scenario -- validates configs, generates overrides, diagnoses issues | Fully automated -- agent provisions Azure infrastructure and deploys RPI end-to-end |
| **Infrastructure** | You provision | Existing | Guides you | Agent creates AKS, SQL, Key Vault, Service Bus, AGC, Private Endpoints |

---

## Additional Guides

| Guide | Description |
|:------|:------------|
| [Secrets Management](docs/secrets-management.md) | Kubernetes, CSI, and SDK providers - vault keys, CSI setup, image pull secrets |
| [Single Sign-On](docs/single-sign-on.md) | Microsoft Entra ID, Okta, Keycloak |
| [Ingress](docs/ingress.md) | Chart-managed nginx, BYO controller, AWS ALB, Azure AGC |
| [Storage](docs/storage.md) | Static and dynamic provisioning - EFS, Azure Files, Filestore |
| [RPI Helm CLI](docs/readme-cli.md) | Pre-flight checks, secrets generation, deployment, troubleshooting |
| [Custom Plugins](docs/plugins.md) | Realtime API plugins: decision, event, form, visitor profile, geolocation |
| [Automation](docs/readme-terraform.md) | CI/CD, vault setup, ArgoCD, Flux |

## Resources

- [RPI Product Documentation](https://docs.redpointglobal.com/rpi/)
- [Support](mailto:support@redpointglobal.com) (RPI application issues)
- [www.redpointglobal.com](https://www.redpointglobal.com)

---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

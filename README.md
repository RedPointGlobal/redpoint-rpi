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

## Repository Structure

```
redpoint-rpi/
├── deploy/
│   ├── cli/
│   │   └── interactioncli.sh     # Interaction CLI (secrets, deploy, status)
│   ├── terraform/modules/        # IaC modules (Azure, AWS, GCP)
│   └── values/                   # Example overrides
│       ├── azure/azure.yaml
│       ├── aws/amazon.yaml
│       └── demo/demo.yaml
├── docs/
│   ├── greenfield.md             # New installation guide
│   ├── migration.md              # v7.6 to v7.7 upgrade guide
│   ├── readme-configuration.md   # Configuration reference
│   ├── readme-values.md          # Values and overrides guide
│   ├── readme-mcp.md             # Helm Assistant guide
│   ├── readme-terraform.md       # Terraform guide
│   └── values-reference.yaml     # Complete reference of all keys
├── chart/                        # Managed by Redpoint (do not edit)
└── README.md
```

---

## Additional Guides

| Guide | Description |
|:------|:------------|
| [Helm Assistant](docs/readme-mcp.md) | Web UI and MCP endpoint for AI-assisted configuration and troubleshooting |
| [Configuration Reference](docs/readme-configuration.md) | Cloud identity, secrets management, storage, Realtime API, autoscaling, service mesh, SSO, and more |
| [Values Guide](docs/readme-values.md) | How the two-tier values system works and how to customize defaults |
| [Terraform Guide](docs/readme-terraform.md) | Infrastructure-as-code modules for Azure, AWS, and GCP |
| [GitOps Guide](docs/readme-argocd.md) | Deploying with ArgoCD or Flux |

## Resources

- [RPI Product Documentation](https://docs.redpointglobal.com/rpi/)
- [Helm Assistant Web UI](https://rpi-helm-assistant.redpointcdp.com)
- [Support](mailto:support@redpointglobal.com) (RPI application issues)
- [www.redpointglobal.com](https://www.redpointglobal.com)

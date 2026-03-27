![redpoint_logo](../chart/images/redpoint.png)
# Ingress

[< Back to Home](../README.md)

RPI services are exposed to external traffic through Kubernetes Ingress resources. The chart supports three ingress approaches depending on your infrastructure.

---

## Approaches

| Approach | When to use | TLS termination |
|:---------|:------------|:----------------|
| **Chart-managed nginx** | Simplest setup. The chart deploys its own nginx ingress controller. | At the nginx controller (K8s TLS Secret) |
| **BYO ingress controller** | You already have an ingress controller (nginx, Traefik, HAProxy, etc.) | At your controller |
| **AWS ALB** | AWS environments using Application Load Balancer with the AWS Load Balancer Controller | At the ALB (ACM certificate) |

---

<details>
<summary><strong style="font-size:1.25em;">Chart-Managed Nginx</strong></summary>

The chart deploys an nginx ingress controller as a Deployment + Service + IngressClass. On AWS, the Service gets NLB annotations. On Azure, it gets an internal or public load balancer.

### Prerequisites

- No external ingress controller needed
- A TLS certificate (K8s Secret or synced from vault via CSI)

### Overrides

```yaml
ingress:
  controller:
    enabled: true
  className: <your-ingress-class-name>
  domain: example.com
  mode: public                            # public | private
  # subnetName: <subnet-name>            # required for Azure private mode
  tls:
  - secretName: ingress-tls
    hosts:
    - rpi-interactionapi.example.com
    - rpi-deploymentapi.example.com
    - rpi-realtimeapi.example.com
  hosts:
    config: rpi-deploymentapi
    client: rpi-interactionapi
    integration: rpi-integrationapi
    realtime: rpi-realtimeapi
    callbackapi: rpi-callbackapi
    queuereader: rpi-queuereader
```

### What the chart creates

- `IngressClass` with `controller: k8s.io/ingress-nginx`
- nginx `Deployment` + `Service` (type: LoadBalancer)
- `ConfigMap` for nginx configuration
- `Ingress` resource with TLS and host routing rules

### AWS specifics

On Amazon, the chart adds NLB annotations to the nginx Service:

| Mode | Annotations |
|:-----|:------------|
| `public` | `aws-load-balancer-scheme: internet-facing` |
| `private` | `aws-load-balancer-internal: "true"` |

For ACM certificates (TLS terminated at the NLB instead of nginx):

```yaml
ingress:
  controller:
    enabled: true
  certificateSource: acm
  certificateArn: arn:aws:acm:<region>:<account>:certificate/<cert-id>
```

### Azure specifics

On Azure with `mode: private`, the chart adds internal load balancer annotations. Set `subnetName` for the subnet:

```yaml
ingress:
  controller:
    enabled: true
  mode: private
  subnetName: <your-subnet-name>
```

</details>

<details>
<summary><strong style="font-size:1.25em;">BYO Ingress Controller</strong></summary>

Disable the chart's nginx controller and use your own. The chart still creates the Ingress resource with host routing rules.

### Prerequisites

- An ingress controller already installed on the cluster (nginx, Traefik, HAProxy, Istio, etc.)
- The `IngressClass` name for your controller

### Overrides

```yaml
ingress:
  controller:
    enabled: false
  className: <your-ingress-class-name>     # must match your installed IngressClass
  domain: example.com
  annotations:                              # annotations specific to your controller
    nginx.org/proxy-read-timeout: "3600"
    nginx.org/proxy-send-timeout: "3600"
  tls:
  - secretName: ingress-tls
    hosts:
    - rpi-interactionapi.example.com
    - rpi-deploymentapi.example.com
  hosts:
    config: rpi-deploymentapi
    client: rpi-interactionapi
    integration: rpi-integrationapi
    realtime: rpi-realtimeapi
    callbackapi: rpi-callbackapi
    queuereader: rpi-queuereader
```

### What the chart creates

- `Ingress` resource with your class name, annotations, TLS, and host routing rules

### What the chart does NOT create

- No IngressClass
- No controller Deployment/Service
- No ConfigMap

### Annotations

When `ingress.annotations` is set in the overrides, it completely replaces the chart's default nginx annotations. Provide all the annotations your controller needs.

</details>

<details>
<summary><strong style="font-size:1.25em;">AWS Application Load Balancer (ALB)</strong></summary>

Use the AWS Load Balancer Controller to create an ALB from the Ingress resource. TLS is terminated at the ALB using an ACM certificate.

### Prerequisites

**On the EKS cluster:**

1. **AWS Load Balancer Controller** installed (EKS addon or Helm):
   ```bash
   helm repo add eks https://aws.github.io/eks-charts
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     --set clusterName=<your-cluster> \
     --set serviceAccount.create=true \
     --set serviceAccount.name=aws-load-balancer-controller \
     -n kube-system
   ```

2. **IAM role** for the controller with the [required policy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json), configured via IRSA

3. **OIDC provider** enabled on the EKS cluster (required for IRSA)

**On AWS:**

4. **ACM certificate** for your domain (must be in the same region as the cluster, validated via DNS or email)

5. **Subnet tags** for ALB auto-discovery:

   | Subnet type | Tag |
   |:------------|:----|
   | Private (for `scheme: internal`) | `kubernetes.io/role/internal-elb: 1` |
   | Public (for `scheme: internet-facing`) | `kubernetes.io/role/elb: 1` |
   | All | `kubernetes.io/cluster/<cluster-name>: owned` |

6. **Security groups** - the controller creates ALB security groups automatically. Pod security groups must allow inbound traffic from the ALB on port 8080 (when using `target-type: ip`).

### Overrides

```yaml
ingress:
  controller:
    enabled: false                          # do not deploy nginx
  className: alb
  certificateSource: acm                    # skip TLS block on Ingress (ALB handles TLS)
  certificateArn: arn:aws:acm:<region>:<account>:certificate/<cert-id>
  domain: example.com
  annotations:
    alb.ingress.kubernetes.io/scheme: internal              # internal | internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/group.name: rpi               # groups all services under one ALB
    alb.ingress.kubernetes.io/healthcheck-path: /health/ready
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "10"
    alb.ingress.kubernetes.io/success-codes: "200"
  hosts:
    config: <prefix>-deploymentapi
    client: <prefix>-interactionapi
    integration: <prefix>-integrationapi
    callbackapi: <prefix>-callbackapi
    queuereader: <prefix>-queuereader
```

### What the chart creates

- `Ingress` resource with `ingressClassName: alb` and ALB annotations
- No TLS block on the Ingress (TLS is handled at the ALB via ACM)

### What the AWS Load Balancer Controller creates

- Application Load Balancer
- Target groups (one per service, using pod IPs with `target-type: ip`)
- HTTPS listener on port 443 with the ACM certificate
- Routing rules based on host headers

### Public vs Private ALB

| Access | Annotation |
|:-------|:-----------|
| Internal only (VPC) | `alb.ingress.kubernetes.io/scheme: internal` |
| Internet-facing | `alb.ingress.kubernetes.io/scheme: internet-facing` |

### Single ALB for all services

The `group.name` annotation groups all Ingress rules under one ALB. Without it, the controller would create a separate ALB for each Ingress resource. Set the same `group.name` across all environments if you want consistent naming.

### Services not exposed via ALB

Execution service and node manager do not have ingress rules by default (they are internal services). If you also want to exclude the queue reader from the ALB, you can disable it in the overrides (`queuereader.enabled: false`) or remove `queuereader` from the hosts map.

</details>

---

## Host Routing

The chart creates one Ingress rule per service listed in `ingress.hosts`. Each host is constructed as `{host-value}.{domain}` unless the host value contains a dot, in which case it's used as a FQDN.

| hosts key | Value | Resulting host |
|:----------|:------|:---------------|
| `config` | `rpi-deploymentapi` | `rpi-deploymentapi.example.com` |
| `client` | `rpi-interactionapi` | `rpi-interactionapi.example.com` |
| `callbackapi` | `custom.mydomain.com` | `custom.mydomain.com` (FQDN) |

Services that have host entries:

| hosts key | Service | Notes |
|:----------|:--------|:------|
| `config` | Deployment API | Database schema management, licensing |
| `client` | Interaction API | Client-facing API |
| `integration` | Integration API | Third-party integrations |
| `realtime` | Realtime API | Realtime decisioning |
| `callbackapi` | Callback API | Async callbacks |
| `queuereader` | Queue Reader | Queue management UI |
| `rabbitmqconsole` | RabbitMQ Console | Internal queue monitoring (if distributed) |

Services without ingress rules (internal only): Execution Service, Node Manager.

---

## TLS Options

| Method | When to use | Configuration |
|:-------|:------------|:--------------|
| K8s TLS Secret | Most common. Create manually or sync from vault. | `certificateSource: kubernetes` + `tls[].secretName` |
| ACM (AWS) | TLS at the NLB or ALB. No K8s Secret needed. | `certificateSource: acm` + `certificateArn` |
| cert-manager | Auto-provisioned from Let's Encrypt or internal CA. | Add cert-manager annotations to `ingress.annotations` |

### K8s TLS Secret

```yaml
ingress:
  certificateSource: kubernetes
  tls:
  - secretName: ingress-tls
    hosts:
    - rpi-interactionapi.example.com
```

Create the secret before deploying:
```bash
kubectl create secret tls ingress-tls --cert=tls.crt --key=tls.key -n <namespace>
```

Or sync from vault via CSI SecretProviderClass (see [Secrets Management Guide](secrets-management.md)).

### ACM Certificate (AWS)

```yaml
ingress:
  certificateSource: acm
  certificateArn: arn:aws:acm:<region>:<account>:certificate/<cert-id>
```

No TLS block is rendered on the Ingress. TLS is handled at the load balancer.

### cert-manager

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
  - secretName: ingress-tls
    hosts:
    - rpi-interactionapi.example.com
```

cert-manager watches the Ingress, provisions the certificate, and stores it in the `ingress-tls` Secret automatically.

---

## Resources

- [Secrets Management Guide](secrets-management.md) - TLS certificate configuration per secrets provider
- [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) - Generate ingress configuration
- [AWS Load Balancer Controller docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) - ALB controller installation and configuration
- [cert-manager docs](https://cert-manager.io/docs/) - Automated certificate management

---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

![redpoint_logo](assets/images/logo.png)

# Helm Chart Release Notes

## Overview

This release introduces several enhancements, including AWS Secrets Manager support, Argo Rollouts integration for GitOps workflows, and the renaming of Data Activation to Smart Activation. The update also includes configuration refinements, resource optimization improvements, and enhanced documentation.

<div style="background-color:#ffe5e5; padding:16px; border-left:6px solid #cc0000;">
  <strong style="color:#cc0000; font-size: 1.1em;">NOTE</strong>
  <p>You are <strong>not required</strong> to pull in these chart changes immediately. Existing Helm deployments can continue running with the new release <strong>image tag</strong>. The latest Helm chart can be updated and applied at a later time that is convenient for your environment.</p>
</div>

## What's New

### AWS Secrets Manager

Added support for AWS Secrets Manager as a secrets management provider, complementing existing **Kubernetes Secrets** and **Azure Key Vault** options.

A complete setup guide has been added to the README ```Configure Secrets Management``` section

### Argo Rollouts

Added support for **Argo Rollouts** for GitOps deployments. You can now enable rollouts by setting `type: rollout` on any service. While RPI does **not currently support full Blue/Green deployments**, enabling this feature still provides benefits through the Argo Rollouts dashboard.  

For example, you can:
- Visualize your Rollouts.
- Restart services in a controlled manner

![redpoint_logo](assets/images/rollouts.png)

```yaml
<service>:
  type: rollout  # or deployment (default)
  rollout:
    autoPromotionEnabled: true
    revisionHistoryLimit: 3
```

### Smart Activation

Data Activation has been renamed to Smart Activation. Updated setup documentation has been moved to `/assets/docs/smartActivation.md` 

**Important:** Smart Activation requires a valid license. Do **not** enable this feature without consulting your Redpoint representative.

### Service Names

We’ve removed support for changing service names, as there’s no functional need for admins to modify them. This change will make log review and troubleshooting faster, and help our development teams quickly identify which service is generating log entries eliminating any confusion caused by custom naming.

If you previously overrode these values, please remove them from your configuration.

Service port configuration has also been standardized across all services using a nested `service.port` structure. This change improves consistency across charts, aligns with common Helm conventions, and simplifies future extensibility (for example, adding service type or additional ports).

**Example**

```yaml
# Previous structure
keycloak:
  port: 80

# New standardized structure
keycloak:
  service:
    port: 80
```

## Resource and Configuration Enhancements

**Standardized CPU and Memory**

CPU and memory configurations have been standardized across all services to align with Kubernetes best practices.

- CPU Requests set to `500m` and no limits defined
- Memory Requests set equal to limits

**Debug Environment Variables**

Debug-related environment variables have been centralized under the `extraEnvs` section for the **Execution Service**. These settings are intended for **internal Dev/QA use only**. Do not enable unless instructed by Redpoint Support.

**Debug Options include**

- SendGrid sandbox mode
- Twilio SMS campaign control
- LuxSci sandbox mode

## Execution Service Updates

Changed the default from `enabled: true` to `enabled: false`. If you need autoscaling for the execution service, explicitly enable it:

```yaml
executionservice:
  autoscaling:
    enabled: true
```

- **`maxThreadsPerExecutionService`** increased from `50` to `100` to improve concurrent job execution capacity
- Redis persistent volume size increased from `50Gi` to `100Gi`to provides additional capacity for Redis cache usage

## Pod Disruption Budgets

Disabled by default and can be enabled on demand. This provides more flexible and lenient behavior during rolling updates and cluster maintenance operations.

```
podDisruptionBudget:
  enabled: false
```

### Prometheus Metrics

Changed default for `prometheus_scrape` from `false` to `true`. When custom metrics are enabled, Prometheus scraping is now active by default when ```customMetrics.enabled=true```.

### Termination Grace Period

Added configurable `terminationGracePeriodSeconds: 120` to 8 services (realtimeapi, callbackapi, executionservice, interactionapi, integrationapi, nodemanager, deploymentapi, queuereader). This gives pods more time for graceful shutdown.

### Ingress Routes

Updated queue reader and socketio ingress routes to use configurable ports instead of hardcoded values:
- Queue Reader: Now uses `{{ .Values.queuereader.service.port }}`
- Socket.IO: Now uses `{{ .Values.socketio.service.port }}`

## Removed Configuration 

The following configuration options have been removed or disabled for **Smart Activation** components to align with current support.

- Sigma Reporting: Disabled by default
- Autoscaling: Disabled for Init and Cache services (not supported at this time)
- Custom Metrics: Configuration removed (not supported at this time)
- Node Selector and Tolerations: Standardized to match RPI service defaults

## Documentation

- Added dedicated Smart Activation documentation at `/assets/docs/smartActivation.md` 
- Main README has been updated covering AWS Secrets Manager setup
- Enhanced inline comments throughout values.yaml with better formatting and clearer examples

## Template Changes

Modified 23 out of 24 template files. The largest change is `hpa.yaml` which grew 81% to support targeting both Deployments and Rollouts. Other significant updates:
- `deploy-redis.yaml`: +17% for enhanced configuration options
- `deploy-realtimeapi.yaml`: +3% for rollout support
- `deploy-interactionapi.yaml`: +6% for rollout support

All deployment templates now conditionally render either Deployment or Rollout resources based on the `type` configuration.

## Upgrading

**Before upgrading:**

- Pull the latest helm chart and ensure you update and reconcile your current chart with the new version.
- Make sure your cluster has adequate CPU, Memory and Storage capacity before upgrading.
- Test in non-production first, especially given the significant resource changes.

**After upgrading:**

1. Verify all pods start with new resource limits
3. Confirm ingress routes are working with new paths


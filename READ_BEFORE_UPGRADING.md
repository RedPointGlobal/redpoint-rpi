![redpoint_logo](assets/images/logo.png)
## Read Before Upgrading

This version introduces significant changes including new StatefulSets for the default Redis and RabbitMQ dependencies, multi-tenantancy for the Callback API, new optional Data Activation services, and several structural changes. 


-----------------------------------------------------------------------
**Because this is a breaking upgrade, a clean reconciliation of several Deployments and the introduction of new StatefulSets are required.**

Before proceeding, be sure to review the full change log in the release notes:
https://docs.redpointglobal.com/rpi/rpi-v7-6-release-notes#RPIv7.6releasenotes-Post-releaseproductupdates
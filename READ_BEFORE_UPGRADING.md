![redpoint_logo](assets/images/logo.png)
## Read Before Upgrading

This release introduces several enhancements, including AWS Secrets Manager support, Argo Rollouts integration for GitOps workflows, and the renaming of Data Activation to Smart Activation. The update also includes configuration refinements, resource optimization improvements, and enhanced documentation.

<div style="background-color:#ffe5e5; padding:16px; border-left:6px solid #cc0000;">
  <strong style="color:#cc0000; font-size: 1.1em;">NOTE</strong>
  <p>You are <strong>not required</strong> to pull in these chart changes immediately. Existing Helm deployments can continue running with the new release <strong>image tag</strong>. The latest Helm chart can be updated and applied at a later time that is convenient for your environment.</p>
</div>

Before proceeding, be sure to review the full change log in the release notes: https://docs.redpointglobal.com/rpi/rpi-7-6-20251107-936-upgrade
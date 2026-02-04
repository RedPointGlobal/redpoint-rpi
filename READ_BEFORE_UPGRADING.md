![redpoint_logo](assets/images/logo.png)
## Read Before Upgrading

This release includes enhancements, such as support for NetworkPolicy, seccomp profiles using RuntimeDefault, and an improved NOTES.txt with dynamic templating that surfaces release-specific information, connection details, and post-installation next steps.

<div style="background-color:#ffe5e5; padding:16px; border-left:6px solid #cc0000;">
  <strong style="color:#cc0000; font-size: 1.1em;">NOTE</strong>
  <p>You are <strong>not required</strong> to pull in these chart changes immediately. Existing Helm deployments can continue running with the new release <strong>image tag</strong>. The latest Helm chart can be updated and applied at a later time that is convenient for your environment.</p>
</div>

Before proceeding, be sure to review the full change log in the release notes: https://docs.redpointglobal.com/rpi/rpi-7-6-20251107-936-upgrade
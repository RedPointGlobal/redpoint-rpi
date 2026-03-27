![redpoint_logo](../chart/images/redpoint.png)
# Storage

[< Back to main README](../README.md)

RPI uses persistent storage for shared file output and optionally for internal Redis and RabbitMQ caches when distributed queue processing is enabled.

---

## Provisioning Modes

The chart supports two approaches for provisioning storage:

| Mode | How it works | When to use |
|:-----|:-------------|:------------|
| **Static** | You define both PVs and PVCs in the overrides under `storage.persistentVolumes`. The chart creates the PV + PVC pair pointing to your pre-existing volumes (EFS access points, Azure Blob containers, etc.). | Existing infrastructure, strict control over volume handles, or when access points are pre-created with specific UID/GID ownership. |
| **Dynamic** | You define only PVCs under `storage.persistentVolumeClaims` (or `volumeClaimTemplates` for StatefulSets) with a StorageClass. The CSI driver auto-provisions the underlying volumes and access points. No `storage.persistentVolumes` entries needed. | New deployments, simpler setup, or when the CSI driver supports auto-provisioning (e.g., EFS with `provisioningMode: efs-ap`). |

### Platform Reference

Both modes work on all platforms. The CSI driver and volume handle format differ by platform:

| Platform | CSI Driver | Static volumeHandle | Dynamic StorageClass Parameters |
|:---------|:-----------|:--------------------|:-------------------------------|
| **AWS** | `efs.csi.aws.com` | `<efs-id>::<access-point-id>` | `provisioningMode: efs-ap`, `fileSystemId`, `uid: "7777"`, `gid: "7777"` |
| **Azure (Blob)** | `blob.csi.azure.com` | `<resourcegroup>_<storageaccount>_<container>` | Not typically used for Blob Fuse |
| **Azure (Files)** | `file.csi.azure.com` | `<storageaccount>_<sharename>` | `skuName: Standard_LRS`, `shareName` |
| **Google** | `filestore.csi.storage.gke.io` | `modeInstance/<zone>/<instance>/<share>` | `tier: standard`, `network` |

> RPI containers run as UID 7777. For static provisioning, create access points or file shares with ownership set to UID/GID 7777. For dynamic provisioning, set `uid` and `gid` in the StorageClass parameters.

### Static provisioning

Define PVs and PVCs explicitly. You control the volume handles and access points:

```yaml
storage:
  storageClass:
    enabled: true
    name: efs-sc
    provisioner: efs.csi.aws.com
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: pvc-fileoutputdir
      mountPath: /rpifileoutputdir
  persistentVolumes:
  - name: pv-fileoutputdir
    capacity: 50Gi
    accessModes: [ReadWriteMany]
    storageClassName: efs-sc
    reclaimPolicy: Retain
    csi:
      driver: efs.csi.aws.com
      volumeHandle: <efs-id>::<access-point-id>
    pvc:
      claimName: pvc-fileoutputdir
```

### Dynamic provisioning

Define only PVCs and a StorageClass with provisioning parameters. The CSI driver creates the volumes automatically:

```yaml
storage:
  storageClass:
    enabled: true
    name: efs-sc
    provisioner: efs.csi.aws.com
    parameters:
      provisioningMode: efs-ap
      fileSystemId: <your-efs-id>
      directoryPerms: "755"
      uid: "7777"
      gid: "7777"
      basePath: /rpi
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: pvc-fileoutputdir
      mountPath: /rpifileoutputdir
  # No persistentVolumes needed - the CSI driver creates them
```

> For EFS dynamic provisioning, use `uid: "7777"` and `gid: "7777"` to match the UID that RPI containers run as. This ensures the auto-created access points have correct file ownership.

---

<details>
<summary><strong style="font-size:1.25em;">FileOutputDirectory</strong></summary>

A shared volume mounted by execution service, node manager, and queue reader pods for file-based processing output (CSV exports, reports, data imports).

| Platform | Recommended driver |
|:---------|:------------------|
| Azure | `file.csi.azure.com` |
| AWS | `efs.csi.aws.com` |
| Google | `filestore.csi.storage.gke.io` |

### Using the Generate tab

The [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) **Generate** tab > **Step 5: Storage** lets you configure PVCs and PVs. The chart creates the PersistentVolume and PersistentVolumeClaim resources from your overrides.

### Example: AWS EFS

```yaml
storage:
  storageClass:
    enabled: true
    name: sc-rpi-efs
    provisioner: efs.csi.aws.com
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
  persistentVolumes:
  - name: pv-rpi-efs
    capacity: 10Gi
    accessModes:
    - ReadWriteMany
    storageClassName: sc-rpi-efs
    reclaimPolicy: Retain
    csi:
      driver: efs.csi.aws.com
      volumeHandle: <your-efs-filesystem-id>
    pvc:
      claimName: rpifileoutputdir
```

### Example: Azure Files

```yaml
storage:
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
  persistentVolumes:
  - name: pv-rpi-files
    capacity: 10Gi
    accessModes:
    - ReadWriteMany
    storageClassName: azurefile-csi
    reclaimPolicy: Retain
    csi:
      driver: file.csi.azure.com
      volumeHandle: <storageAccount>-<shareName>
      volumeAttributes:
        storageaccount: <your-storage-account>
        shareName: <your-file-share>
        clientID: <managed-identity-client-id>
        resourcegroup: <resource-group>
        subscriptionid: <subscription-id>
    pvc:
      claimName: rpifileoutputdir
```

</details>

<details>
<summary><strong style="font-size:1.25em;">Internal Redis and RabbitMQ</strong></summary>

When `queuereader.realtimeConfiguration.isDistributed: true`, the chart deploys internal Redis and RabbitMQ StatefulSets. These need writable storage. Three options:

<details>
<summary><strong>Dynamic provisioning (recommended for AWS EFS)</strong></summary>

Create a StorageClass that auto-provisions EFS access points with correct permissions:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sc-rpi-efs
parameters:
  directoryPerms: "755"
  ensureUniqueDirectory: "true"
  fileSystemId: <your-efs-filesystem-id>
  gidRangeStart: "7000"
  gidRangeEnd: "8000"
  provisioningMode: efs-ap
  reuseAccessPoint: "false"
  subPathPattern: ${.PVC.namespace}/${.PVC.name}
provisioner: efs.csi.aws.com
reclaimPolicy: Retain
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

The GID range `7000-8000` covers UID 7777 used by RPI pods. Each PVC gets its own EFS access point with correct ownership.

In your overrides:

```yaml
queuereader:
  internalCache:
    provider: redis
    type: internal
    redisSettings:
      volumeClaimTemplates:
        enabled: true
        storageClassName: sc-rpi-efs
        storage: 10Gi
  internalQueues:
    provider: rabbitmq
    type: internal
    rabbitmqSettings:
      volumeClaimTemplates:
        enabled: true
        storageClassName: sc-rpi-efs
        storage: 10Gi
```

</details>

<details>
<summary><strong>Static BYO (pre-created PV/PVC)</strong></summary>

When using EFS, Redis and RabbitMQ need EFS access points with POSIX ownership matching UID/GID 7777 (the user RPI pods run as). Create one access point per volume:

```bash
# Redis
aws efs create-access-point \
  --file-system-id <your-efs-id> \
  --posix-user Uid=7777,Gid=7777 \
  --root-directory "Path=/<namespace>/redis,CreationInfo={OwnerUid=7777,OwnerGid=7777,Permissions=755}" \
  --region us-east-1

# RabbitMQ
aws efs create-access-point \
  --file-system-id <your-efs-id> \
  --posix-user Uid=7777,Gid=7777 \
  --root-directory "Path=/<namespace>/rabbitmq,CreationInfo={OwnerUid=7777,OwnerGid=7777,Permissions=755}" \
  --region us-east-1
```

Note the access point IDs from the output (e.g., `fsap-0abc123...`).

Define the PVs in your overrides using the `<efs-id>::<access-point-id>` format for volumeHandle. A simple StorageClass is needed (no dynamic provisioning parameters required for static BYO):

```yaml
storage:
  storageClass:
    enabled: true
    name: my-efs-sc
    provisioner: efs.csi.aws.com
  persistentVolumes:
  - name: pv-redis
    capacity: 10Gi
    accessModes:
    - ReadWriteMany
    storageClassName: my-efs-sc
    reclaimPolicy: Retain
    csi:
      driver: efs.csi.aws.com
      volumeHandle: <efs-id>::<redis-access-point-id>
    pvc:
      claimName: pvc-redis
  - name: pv-rabbitmq
    capacity: 10Gi
    accessModes:
    - ReadWriteMany
    storageClassName: my-efs-sc
    reclaimPolicy: Retain
    csi:
      driver: efs.csi.aws.com
      volumeHandle: <efs-id>::<rabbitmq-access-point-id>
    pvc:
      claimName: pvc-rabbitmq

queuereader:
  internalCache:
    provider: redis
    type: internal
    redisSettings:
      existingClaim: pvc-redis
      volumeClaimTemplates:
        enabled: false
  internalQueues:
    provider: rabbitmq
    type: internal
    rabbitmqSettings:
      existingClaim: pvc-rabbitmq
      volumeClaimTemplates:
        enabled: false
```

The chart creates the PVs and PVCs from the `persistentVolumes` block. The `existingClaim` on the queue reader tells it to use those PVCs instead of dynamic provisioning.

</details>

<details>
<summary><strong>emptyDir (no persistence)</strong></summary>

Simplest option. Data is cleared when the pod is deleted or rescheduled (emptyDir is tied to the pod lifecycle). Cache entries and queue messages rebuild automatically. No PVs, PVCs, or StorageClasses needed.

```yaml
queuereader:
  internalCache:
    provider: redis
    type: internal
  internalQueues:
    provider: rabbitmq
    type: internal
```

When neither `existingClaim` nor `volumeClaimTemplates.enabled` is set, the chart uses `emptyDir` by default.

</details>

### Permissions

RPI pods run as UID 7777 / GID 7777 by default. Storage volumes must be writable by this user. Key points:

- **Dynamic provisioning with EFS**: use `provisioningMode: efs-ap` with `gidRangeStart: 7000` / `gidRangeEnd: 8000` to auto-create access points with correct ownership
- **Static BYO with EFS**: create EFS access points with `Uid=7777,Gid=7777`
- **Azure Blob/Files**: the managed identity needs `Storage Blob Data Contributor` and `Storage File Data SMB Share Contributor` roles
- **emptyDir**: no permission issues (Kubernetes handles ownership)

</details>

<details>
<summary><strong style="font-size:1.25em;">StorageClass</strong></summary>

The chart can create a StorageClass resource from your overrides. This is useful when your cluster doesn't already have a StorageClass for your storage driver.

```yaml
storage:
  storageClass:
    enabled: true
    name: sc-rpi-efs
    provisioner: efs.csi.aws.com
```

For dynamic provisioning with EFS access points, add the full parameters:

```yaml
storage:
  storageClass:
    enabled: true
    name: sc-rpi-efs
    provisioner: efs.csi.aws.com
    reclaimPolicy: Retain
    volumeBindingMode: Immediate
    allowVolumeExpansion: true
    parameters:
      directoryPerms: "755"
      ensureUniqueDirectory: "true"
      fileSystemId: <your-efs-filesystem-id>
      gidRangeStart: "7000"
      gidRangeEnd: "8000"
      provisioningMode: efs-ap
      reuseAccessPoint: "false"
      subPathPattern: ${.PVC.namespace}/${.PVC.name}
```

Skip this if your cluster already has a StorageClass you want to use.

</details>

---
<sub>Redpoint Interaction v7.7 | [Helm Assistant](https://rpi-helm-assistant.redpointcdp.com) | [Support](mailto:support@redpointglobal.com) | [redpointglobal.com](https://www.redpointglobal.com)</sub>

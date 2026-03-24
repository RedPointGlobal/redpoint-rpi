![redpoint_logo](../chart/images/redpoint.png)
# Storage

[< Back to main README](../README.md)

RPI uses persistent storage for shared file output and optionally for internal Redis and RabbitMQ caches when distributed queue processing is enabled.

---

<details>
<summary><strong style="font-size:1.25em;">FileOutputDirectory</strong></summary>

A shared volume mounted by execution service, node manager, and queue reader pods for file-based processing output (CSV exports, reports, data imports).

| Platform | Recommended driver |
|:---------|:------------------|
| Azure | `blob.csi.azure.com` or `file.csi.azure.com` |
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

### Example: Azure Blob

```yaml
storage:
  persistentVolumeClaims:
    FileOutputDirectory:
      enabled: true
      claimName: rpifileoutputdir
      mountPath: /rpifileoutputdir
  persistentVolumes:
  - name: pv-rpi-blob
    capacity: 10Gi
    accessModes:
    - ReadWriteMany
    storageClassName: blob-fuse
    reclaimPolicy: Retain
    mountOptions:
    - -o allow_other
    - --file-cache-timeout-in-seconds=120
    csi:
      driver: blob.csi.azure.com
      volumeHandle: <resourceGroup>_<storageAccount>_<container>
      volumeAttributes:
        storageaccount: <your-storage-account>
        containerName: <your-container>
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

Create PersistentVolumes and PVCs manually before deploying. When using EFS, create access points with POSIX ownership matching UID/GID 7777 (the user RPI pods run as):

```bash
aws efs create-access-point \
  --file-system-id <your-efs-id> \
  --posix-user Uid=7777,Gid=7777 \
  --root-directory "Path=/redis,CreationInfo={OwnerUid=7777,OwnerGid=7777,Permissions=755}" \
  --region us-east-1
```

Use the access point ID in the PV volumeHandle:

```yaml
csi:
  driver: efs.csi.aws.com
  volumeHandle: <efs-id>::<access-point-id>
```

In your overrides, reference the pre-created PVC:

```yaml
queuereader:
  internalCache:
    provider: redis
    type: internal
    redisSettings:
      existingClaim: my-redis-pvc
      volumeClaimTemplates:
        enabled: false
  internalQueues:
    provider: rabbitmq
    type: internal
    rabbitmqSettings:
      existingClaim: my-rabbitmq-pvc
      volumeClaimTemplates:
        enabled: false
```

</details>

<details>
<summary><strong>emptyDir (no persistence)</strong></summary>

Simplest option. Data is lost on pod restart but rebuilds automatically. No PVs, PVCs, or StorageClasses needed.

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

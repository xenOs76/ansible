# NFS CSI Driver Role (`nfs_csi`)

Ansible role for deploying and managing the official Kubernetes SIG Storage NFS CSI Driver (`csi-driver-nfs/csi-driver-nfs`) via Helm on the Kubernetes control plane node, providing automated dynamic PersistentVolume provisioning backed by the homelab Linux kernel NFS server (`/exports`).

---

## 1. Role Overview

- **Host Target**: `control_plane`
- **Helm Chart**: `csi-driver-nfs/csi-driver-nfs` (v4.9.0+)
- **Target Namespace**: `kube-system`
- **Dynamic Provisioner**: `nfs.csi.k8s.io`
- **Controller Components**: `csi-provisioner` sidecar (watches PVCs and dynamically creates NFS subdirectories) and `csi-snapshotter`
- **Node Plugin**: `csi-nfs-node` DaemonSet mounting NFS volumes on worker nodes
- **Dynamic StorageClass**: `nfs-csi` with parameters `server: nfs-server.local` and `share: /exports`

---

## 2. Variables & Defaults

| Variable | Default | Description |
| :--- | :--- | :--- |
| `nfs_csi_enabled` | `false` (in `group_vars/all.yml`) | Enables or bypasses the NFS CSI driver deployment. |
| `nfs_csi_helm_repo` | `https://raw.githubusercontent.com/.../charts` | Helm repository hosting the official CSI chart. |
| `nfs_csi_release_name` | `csi-driver-nfs` | Helm release identifier. |
| `nfs_csi_namespace` | `kube-system` | Target namespace for the driver pods. |
| `nfs_csi_chart_version` | `v4.9.0` | Pinned Helm chart release version. |
| `nfs_csi_storage_class_name` | `nfs-csi` | Name of the dynamic StorageClass created. |
| `nfs_csi_server` | `nfs-server.local` | FQDN or IP of the NFS storage server. |
| `nfs_csi_share` | `/exports` | Root exported NFS share path. |
| `nfs_csi_reclaim_policy` | `Delete` | PV reclaim policy (`Delete` or `Retain`). |
| `nfs_csi_volume_binding_mode` | `Immediate` | Volume binding mode (`Immediate` or `WaitForFirstConsumer`). |

---

## 3. Usage & Playbooks

### Standalone Playbook Execution

```bash
# Deploy NFS CSI driver on preprod
./scripts/run-playbook.sh -e preprod -p nfs_csi.yml

# Deploy NFS CSI driver on prod
./scripts/run-playbook.sh -e prod -p nfs_csi.yml
```

### Makefile Targets

```bash
make preprod-nfs-csi
make prod-nfs-csi
```

---

## 4. Verification

Run on the control plane or workstation via kubectl:

```bash
# Verify CSI driver registration
kubectl get csidrivers

# Verify controller and node daemonset
kubectl get pods -n kube-system -l app.kubernetes.io/name=csi-driver-nfs

# Inspect dynamic StorageClass
kubectl get storageclass nfs-csi
```

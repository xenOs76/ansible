# Rook-Ceph Cloud-Native Storage Role (`rook_ceph`)

Ansible role for automating Rook-Ceph cloud-native storage orchestration on the `k8s-homelab` cluster, providing both
**RBD block storage** and **CephFS / CephNFS shared filesystem storage** as a seamless alternative to `nfs-server`.

---

## 1. Architecture Overview

This role deploys the official Rook-Ceph operator and provisions a Ceph cluster where storage is provided from a
dedicated block device attached to the Kubernetes control plane node (`kube-control-plane`):

- **Control Plane Node**: Hosts Ceph MON, MGR, OSD, MDS, and NFS-Ganesha daemons, backed by a dedicated unformatted
  block device (`/dev/vdb` in preprod). Explicit tolerations are configured to schedule Ceph control and storage pods on
  the control plane despite the `node-role.kubernetes.io/control-plane:NoSchedule` taint.
- **Worker Nodes**: Run Ceph CSI node plugins (`rook-ceph-csi-rbd-node` and `rook-ceph-csi-cephfs-node`) DaemonSets and
  standard kernel NFS client (`nfs-common`). Worker nodes do not host OSD storage; instead, pods on worker nodes consume
  dynamically provisioned Ceph block volumes (RBD), CephFS shared volumes, or mount Ceph NFS shares over the cluster
  network.
- **Dual Protocol Serving**:
  - **RBD (Block)**: A Kubernetes `StorageClass` (`rook-ceph-block`) registered with provisioner
    `rook-ceph.rbd.csi.ceph.com` backed by a replicated `CephBlockPool`.
  - **CephFS (Distributed Filesystem)**: A `CephFilesystem` resource (`cephfs`) backed by an active MDS daemon, exposed
    via dynamic `StorageClass` (`rook-cephfs`) with provisioner `rook-ceph.cephfs.csi.ceph.com` (RWX).
  - **CephNFS (Shared NFSv4 Server)**: An in-cluster NFS-Ganesha server managed by `CephNFS` bound to `hostNetwork:
    true` on `kube-control-plane` port 2049, exporting `/exports` with `no_root_squash`. This acts as a 100% drop-in
    alternative to `nfs-kernel-server` using the same `nfs-server.local:/exports` endpoint.

---

## 2. Role Variables

### Global Settings (`defaults/main.yml`)

| Variable | Default | Description |
| --- | --- | --- |
| `rook_ceph_enabled` | `true` | Enable or disable the Rook Ceph role. |
| `rook_ceph_version` | `"v1.15.5"` | Helm chart version for `rook-release/rook-ceph`. |
| `rook_ceph_helm_repo` | `"https://charts.rook.io/release"` | Upstream Rook Helm chart repository URL. |
| `rook_ceph_namespace` | `"rook-ceph"` | Target Kubernetes namespace for Rook and Ceph daemons. |
| `rook_ceph_cluster_name` | `"rook-ceph"` | CephCluster resource name and release identifier. |
| `rook_ceph_image_version` | `"v19.2.1"` | Upstream Ceph container image tag (`quay.io/ceph/ceph`). |
| `rook_ceph_rbd_enabled` | `true` | Enable RBD dynamic block storage. |
| `rook_ceph_storage_class_name` | `"rook-ceph-block"` | Name of the provisioned RBD StorageClass. |
| `rook_ceph_is_default_sc` | `true` | Whether to mark `rook-ceph-block` as default StorageClass. |
| `rook_ceph_cephfs_enabled` | `true` | Enable CephFS distributed filesystem and CSI driver. |
| `rook_ceph_fs_name` | `"cephfs"` | Name of the CephFilesystem custom resource. |
| `rook_ceph_fs_storage_class_name` | `"rook-cephfs"` | Name of the provisioned CephFS StorageClass. |
| `rook_ceph_nfs_enabled` | Dynamic | Enable CephNFS server (active when `storage_nfs_provider == 'ceph'`). |
| `rook_ceph_nfs_cluster_id` | `"homelab-nfs"` | Identifier for CephNFS daemon resource. |
| `rook_ceph_nfs_host_network` | `true` | Bind Ceph NFS-Ganesha directly to host port 2049 on control plane. |
| `rook_ceph_nfs_export_path` | `"/exports"` | Export pseudo-path exposed to NFS clients. |
| `rook_ceph_mon_count` | `1` | Ceph MON daemon count (1 for single control node). |
| `rook_ceph_mgr_count` | `1` | Ceph MGR daemon count. |
| `rook_ceph_mds_count` | `1` | Ceph MDS daemon count for CephFS. |
| `rook_ceph_pool_replicas` | `1` | Storage pool replica count (`size: 1` for single-node OSD). |
| `rook_ceph_failure_domain` | `"osd"` | Failure domain for Ceph CRUSH rules (`osd` for single-node). |
| `rook_ceph_fs_type` | `"ext4"` | Default filesystem formatted on mapped RBD block devices. |

### Environment-Specific Variables

- **Preprod (`group_vars/preprod.yml`)**:
  - `rook_ceph_storage_node: "kube-control-plane"`
  - `rook_ceph_devices: [{name: "vdb"}]`
- **Production (`group_vars/prod.yml`)**:
  - `rook_ceph_storage_node`: Target control or storage host.
  - `rook_ceph_devices`: List of raw block devices (e.g. `nvme0n1` or `sdb`). If empty, the operator is installed but
    cluster creation is deferred until disks are configured.

---

## 3. Storage Provider Selection (`storage_nfs_provider`)

The homelab provides two mutually exclusive implementations for NFS storage:

1. **`storage_nfs_provider: "kernel"`** (Legacy):
   - Deploys the Linux kernel `nfs-kernel-server` systemd daemon on the control plane.
   - Exports `/exports` via `/etc/exports`.
2. **`storage_nfs_provider: "ceph"`** (Cloud-Native Alternative):
   - Gracefully stops and disables `nfs-kernel-server` so host port 2049 is available.
   - Deploys `CephFilesystem` and `CephNFS` bound to host port 2049 on `kube-control-plane`.
   - Exports `/exports` backed by distributed Ceph storage.
   - All existing manifests, in-tree `nfs:` pods, and CKA volume drills work without modification.

---

## 4. Playbook Execution

Run the standalone Ceph playbook against preprod:

```bash
cd k8s-homelab
./scripts/run-playbook.sh -e preprod -p playbooks/ceph.yml
```

Or via Makefile:

```bash
make preprod-ceph
```

---

## 5. Verification & Diagnostics

### Diagnostic & Status Inspection Tool (`check-ceph-status.sh`)

When troubleshooting deployments or inspecting native Ceph health:

```bash
# On the workstation:
make preprod-ceph-status
# Or with options:
./scripts/check-ceph-status.sh --toolbox

# On the control plane node:
/home/vagrant/check-ceph-status.sh
```

The script inspects:

1. **Operator Deployment**: Checks pod phase, exit codes, recent events, and crash logs.
1. **Helm Release**: Verifies chart release status.
1. **CephCluster CR**: Evaluates CR phase (`Progressing`, `Ready`, `Error`), health conditions, and status messages.
1. **Ceph Daemon Pods**: Summarizes MON, MGR, OSD, MDS, and NFS pods.
1. **Native Ceph Status**: Runs `ceph status`, `ceph osd status`, `ceph fs status`, and `ceph nfs export ls`.
1. **StorageClass Registration**: Verifies both `rook-ceph-block` and `rook-cephfs`.

### End-to-End Dynamic Storage Verification (`test-ceph-storage.sh`)

Run the storage verification script from the control plane:

```bash
# Run all tests (RBD, CephFS, and NFS):
/home/vagrant/test-ceph-storage.sh

# Or test individual storage modes:
/home/vagrant/test-ceph-storage.sh --rbd
/home/vagrant/test-ceph-storage.sh --cephfs
/home/vagrant/test-ceph-storage.sh --nfs
```

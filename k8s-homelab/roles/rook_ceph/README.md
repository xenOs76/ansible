# Rook-Ceph Block Storage Role (`rook_ceph`)

Ansible role for automating Rook-Ceph cloud-native block storage orchestration on the `k8s-homelab` cluster.

---

## 1. Architecture Overview

This role deploys the official Rook-Ceph operator and provisions a Ceph cluster where storage is provided from a dedicated block device attached to the Kubernetes control plane node (`kube-control-plane`):

- **Control Plane Node**: Hosts the Ceph MON, MGR, and OSD daemons, backed by a dedicated unformatted block device (`/dev/vdb` in preprod). Explicit tolerations are configured to schedule Ceph control and storage pods on the control plane despite the `node-role.kubernetes.io/control-plane:NoSchedule` taint.
- **Worker Nodes**: Run the Ceph CSI node plugin (`rook-ceph-csi-rbd-node`) DaemonSet. Worker nodes do not host OSD storage; instead, pods on worker nodes consume dynamically provisioned Ceph block volumes (RBD) over the cluster network.
- **Dynamic Provisioning**: A Kubernetes `StorageClass` (`rook-ceph-block`) is registered with provisioner `rook-ceph.rbd.csi.ceph.com` backed by a replicated `CephBlockPool`.

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
| `rook_ceph_storage_class_name` | `"rook-ceph-block"` | Name of the provisioned Kubernetes StorageClass. |
| `rook_ceph_is_default_sc` | `true` | Whether to mark `rook-ceph-block` as default StorageClass. |
| `rook_ceph_mon_count` | `1` | Ceph MON daemon count (1 for single control node). |
| `rook_ceph_mgr_count` | `1` | Ceph MGR daemon count. |
| `rook_ceph_pool_replicas` | `1` | Storage pool replica count (`size: 1` for single-node OSD). |
| `rook_ceph_failure_domain` | `"osd"` | Failure domain for Ceph CRUSH rules (`osd` for single-node). |
| `rook_ceph_fs_type` | `"ext4"` | Default filesystem formatted on mapped RBD block devices. |

### Environment-Specific Variables

- **Preprod (`group_vars/preprod.yml`)**:
  - `rook_ceph_storage_node: "kube-control-plane"`
  - `rook_ceph_devices: [{name: "vdb"}]`
- **Production (`group_vars/prod.yml`)**:
  - `rook_ceph_storage_node`: Target control or storage host.
  - `rook_ceph_devices`: List of raw block devices (e.g. `nvme0n1` or `sdb`). If empty, the operator is installed but cluster creation is deferred until disks are configured.

---

## 3. Playbook Execution

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

## 4. Verification & Diagnostics

### Diagnostic & Status Inspection Tool (`check-ceph-status.sh`)

When troubleshooting stuck deployments, failing operators, or checking native Ceph health:

```bash
# On the workstation:
make preprod-ceph-status
# Or with options:
./scripts/check-ceph-status.sh --toolbox

# On the control plane node:
/home/vagrant/check-ceph-status.sh
```

The script inspects:

1. **Operator Deployment**: Checks pod phase, reports termination reasons, exit codes, recent events, and crash logs when in `Error` or `CrashLoopBackOff`.
1. **Helm Release**: Verifies chart release status.
1. **CephCluster CR**: Evaluates CR phase (`Progressing`, `Ready`, `Error`), health conditions, and status messages.
1. **Daemon Pods**: Summarizes MON, MGR, OSD, and CSI driver pods.
1. **Native Ceph Status**: Runs `ceph status` and `ceph osd status` via running MONs or the Ceph Toolbox (`--toolbox`).

### End-to-End Dynamic Storage Verification (`test-ceph-storage.sh`)

Once the operator and cluster are healthy, run the dynamic storage verification script from the control plane:

```bash
/home/vagrant/test-ceph-storage.sh
```

The drill dynamically allocates a 1Gi PVC, schedules a test container to `kube-worker-1`, writes a timestamp, reads back data, and verifies teardown cleanly.

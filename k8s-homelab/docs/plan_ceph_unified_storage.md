# Architectural Plan: Unified Ceph Cloud-Native Storage Exercises & Decoupling from Classic NFS

**Author:** Antigravity Pairing Agent  
**Date:** October 18, 2026  
**Status:** PROPOSED (Awaiting User Review)  
**Target Environments:** `preprod` (Vagrant Libvirt/KVM) & `prod` (Bare Metal)  
**Target Paths:** `~/cka/12-volumes/06-ceph/` (symlinked from `06-rbd/`), `~/cka/13-storage-classes/`

---

## 1. Executive Summary & Problem Statement

### The Problem

Currently, homelab Ceph exercises are fragmented and inappropriately co-located with baseline exam requirements:

1. **Unwanted Coupling with Classic NFS**:
   In `~/cka/13-storage-classes/02-storage-classes/`, Drill 5 mixes Ceph NFS (CephFS exported over NFS-Ganesha via `03-ceph-nfs-sc.yaml`) and native CephFS (`03-cephfs-sc.yaml`) into the same directory and guide as the standard Linux kernel NFS (`nfs-server.local:/srv/nfsroot`).
2. **Fragmented Ceph Architecture**:
   Ceph block storage (RBD) is housed under `~/cka/12-volumes/06-rbd/`, while Ceph shared filesystems (CephFS and Ceph NFS) live in `~/cka/13-storage-classes/02-storage-classes/`.
3. **Inconsistent On-Demand Availability**:
   While iSCSI (`07-iscsi/`) and Fibre Channel SAN (`08-fc/`) are clearly categorized as on-demand auxiliary storage layers with dedicated activation playbooks (`iscsi.yml`, `fc.yml`) and health checks, Ceph NFS was embedded into a core CKA exercise that students expect to execute against the standard baseline environment.

### The Objective

- **Decouple**: Remove all Ceph exercises (`ceph-nfs`, `cephfs`) from `~/cka/13-storage-classes/` so that Chapter 13 focuses purely on standard CKA provisioners (`local-path-provisioner` and classic `nfs-kernel-server`).
- **Unify**: Group Ceph RBD (Block), native CephFS (Shared Filesystem), and Ceph NFS (NFS-Ganesha over CephFS) into a single, cohesive, on-demand storage section under `~/cka/12-volumes/06-ceph/` (with `06-rbd` preserved as a backward-compatibility symlink).
- **On-Demand Parity**: Standardize lifecycle management (`make preprod-ceph`, `playbooks/ceph.yml`), pre-flight readiness gates, and automated test skipping to match iSCSI and Fibre Channel SAN.

---

## 2. Storage Taxonomy & On-Demand Matrix

| Tier | Storage Type | Technology / CSI Driver | Deployment Model | Activation Command | Supported Access Modes | Volume Modes | Practice Location |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Required Core** | **Standard NFS** | Linux Kernel NFS Server (`nfs-kernel-server`) | Baseline (Always Available) | `make preprod-deploy` | `ReadWriteMany` (RWX), `ReadOnlyMany` (ROX) | Filesystem | `12-volumes/01-nfs/` & `13-storage-classes/` |
| **Optional Aux 1** | **Unified Ceph** | Rook-Ceph (`rbd.csi.ceph.com`, `cephfs.csi.ceph.com`, `nfs.csi.k8s.io`) | **On-Demand** (`playbooks/ceph.yml`) | `make preprod-ceph` | `ReadWriteOnce` (RWO), `ReadWriteMany` (RWX) | Filesystem & Raw Block | `12-volumes/06-ceph/` |
| **Optional Aux 2** | **iSCSI SAN** | Linux-IO Target (LIO / `iscsi_target`) | **On-Demand** (`playbooks/iscsi.yml`) | `make preprod-iscsi` | `ReadWriteOnce` (RWO), `ReadWriteOncePod` (RWOP) | Filesystem & Raw Block | `12-volumes/07-iscsi/` |
| **Optional Aux 3** | **Fibre Channel SAN** | Linux SCSI_DEBUG FC SAN Emulator (`fc_san`) | **On-Demand** (`playbooks/fc.yml`) | `make preprod-fc` | `ReadWriteOnce` (RWO), Multipath Active/Passive | Filesystem & Raw Block | `12-volumes/08-fc/` |

---

## 3. Detailed Reorganization Plan

### A. Restructure `~/cka/12-volumes/06-ceph/`

Expand `06-rbd/` into `06-ceph/` containing a comprehensive multi-backend Ceph guide and structured sub-drills:

```text
~/cka/12-volumes/06-ceph/
├── README.md                          # Master guide for Ceph RBD, CephFS, and Ceph NFS
├── test-ceph-storage.sh               # Unified automated verification suite
├── 01-rbd-dynamic-filesystem.yaml     # Ceph RBD: Dynamic ext4/xfs filesystem PVC & pod
├── 02-rbd-raw-block.yaml              # Ceph RBD: Raw block volume (volumeMode: Block)
├── 03-rbd-static-pv-pvc-pod.yaml      # Ceph RBD: Static PV binding with image name & pool
├── 04-rbd-pvc-expansion.yaml          # Ceph RBD: Online volume expansion (1Gi -> 2Gi)
├── 05-cephfs-sc.yaml                  # CephFS: Native CephFS StorageClass
├── 06-cephfs-dynamic-pvc.yaml         # CephFS: Dynamic ReadWriteMany shared PVC
├── 07-cephfs-shared-deployment.yaml   # CephFS: Multi-replica NGINX shared mount
├── 08-ceph-nfs-sc.yaml                # CephNFS: NFS-Ganesha export via NFS CSI
├── 09-ceph-nfs-dynamic-pvc.yaml       # CephNFS: ReadWriteMany claim over Ceph NFS
└── 10-ceph-nfs-shared-deployment.yaml # CephNFS: Multi-node consumer workload
```

- **Backward Compatibility Symlink**:
  Create symbolic link `~/cka/12-volumes/06-rbd -> 06-ceph` so existing scripts and muscle memory continue to function without disruption.

### B. Clean Up `~/cka/13-storage-classes/`

Purge all Ceph-specific files from `13-storage-classes/02-storage-classes/`:

- **Remove**:
  - `03-ceph-nfs-sc.yaml`
  - `03-cephfs-sc.yaml`
  - `04-ceph-dynamic-pvc.yaml`
  - `05-ceph-shared-deployment.yaml`
  - `test-ceph-nfs-drills.sh`
- **Update Guide (`storage_classes_readme.md.j2`)**:
  - Remove **Drill 5: Cloud-Native Ceph Dynamic Shared Storage Alternatives**.
  - Keep Chapter 13 focused purely on:
    - Drill 1: `local-path-provisioner` deployment & concepts
    - Drill 2: StorageClass policies (`Retain` vs `Delete`, `Immediate` vs `WaitForFirstConsumer`)
    - Drill 3: Dynamic PVC lifecycle, delayed binding, and volume expansion
    - Drill 4: Classic Dynamic NFS CSI Driver (`nfs.csi.k8s.io` to `nfs-server.local:/srv/nfsroot`)
  - Add cross-reference banner directing students interested in advanced cloud-native Ceph shared storage to `~/cka/12-volumes/06-ceph/`.

---

## 4. On-Demand Availability Standards (Parity with iSCSI & FC)

To match the operational standards of `07-iscsi/` and `08-fc/`:

1. **Dedicated Playbook & Makefile Targets**:
   - `make preprod-ceph`: Executes `./scripts/run-playbook.sh -e preprod -p ceph.yml`
   - `make preprod-ceph-status`: Checks status of Rook-Ceph operator, CephCluster, OSDs, CephBlockPool, CephFileSystem, and CephNFS daemon.

2. **Automated Health Check & Safe Skipping**:
   Update `test-ceph-storage.sh` and the master `test-volumes-drills.sh` runner with pre-flight checks:

   ```bash
   # Check if Ceph cluster is active before running tests:
   if ! kubectl get cephcluster rook-ceph -n rook-ceph >/dev/null 2>&1; then
     echo "==> Ceph cluster not active. Skipping Ceph drills."
     echo "    To enable Ceph storage, run: make preprod-ceph"
     exit 0
   fi
   ```

   This ensures that running `test-volumes-drills.sh` in a vanilla environment without Ceph does not trigger test failures.

---

## 5. Implementation Roadmap & Steps

1. **Ansible Task Updates (`roles/cka_lab/tasks/`)**:
   - In `scenario_volumes.yml`:
     - Create directory `{{ cka_lab_volumes_dir }}/06-ceph`.
     - Render Ceph manifests (RBD, CephFS, CephNFS) into `06-ceph/`.
     - Create symlink `{{ cka_lab_volumes_dir }}/06-rbd -> 06-ceph`.
     - Update `test-ceph-storage.sh` to validate all three Ceph capabilities.
   - In `scenario_storage_classes.yml`:
     - Remove the 5 Ceph template renders from `02-storage-classes/`.
     - Remove `test-ceph-nfs-drills.sh` from the script syntax check loop.

2. **Template Updates (`roles/cka_lab/templates/`)**:
   - Create `volumes_06_ceph_readme.md.j2` (or consolidate into `volumes_06_rbd_readme.md.j2` renamed to `volumes_06_ceph_readme.md.j2`) covering RBD, CephFS, and CephNFS.
   - Edit `storage_classes_readme.md.j2` to remove Drill 5 and add cross-reference pointer.
   - Edit `volumes_readme.md.j2` to update Drill 6 overview and taxonomy table.

3. **Validation & Quality Gates**:
   - Validate YAML with `yamllint`.
   - Validate Ansible plays with `ansible-lint` (`production` profile).
   - Validate Markdown with `markdownlint-cli2`.
   - Verify script syntax with `bash -n`.

---

## 6. Feedback & Decisions Needed

Before implementing, please confirm:

1. **Directory Naming**: Is `06-ceph/` (with `06-rbd -> 06-ceph` symlink) the desired destination name under `12-volumes/`?
2. **CephFS inclusion**: Would you like native CephFS (`rook-cephfs`) included alongside Ceph NFS (`ceph-nfs-csi`) in this unified `06-ceph/` guide?
3. **Makefile target**: Should `make preprod-ceph` and `make preprod-ceph-status` be confirmed as the standard CLI entrypoints?

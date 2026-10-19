# Implementation Plan: Fibre Channel (FC) SAN Storage Emulation & Multi-Tier Volume Drills

**Target Scenarios:** `k8s-homelab/roles/fc_san/`, `k8s-homelab/roles/nfs_server/`, & `k8s-homelab/roles/cka_lab/tasks/scenario_volumes.yml`  
**Target VM Directories:** `/home/vagrant/cka/12-volumes/08-fc/`, `/srv/fc/`, & `/srv/nfsroot/` (with `/exports -> /srv/nfsroot` symlink)  
**Curriculum Domain:** CNCF CKA — Storage (10%), Workloads & Scheduling (15%)  

---

## 1. Executive Summary & Storage Tier Taxonomy

In this design, **NFS** remains the guaranteed baseline storage provider for the cluster, while **Ceph RBD**, **iSCSI**, and **Fibre Channel (FC) SAN** form the **Auxiliary Block & SAN Storage Layers**. These auxiliary layers are strictly optional and can be independently enabled, deployed, or skipped without disrupting default cluster operations or standard CKA practice labs.

To achieve clean FHS (Filesystem Hierarchy Standard) consistency across all storage backends, all network-served storage is standardized under `/srv/`:

- **NFS Root**: `/srv/nfsroot` (with a bidirectional `/exports -> /srv/nfsroot` symlink for full backward compatibility)
- **iSCSI Backstore**: `/srv/iscsi`
- **FC SAN Backstore**: `/srv/fc`

```text
+--------------------------------------------------------------------------------------------------+
|                                    KUBERNETES CLUSTER NODES                                      |
|            kube-control-plane (192.168.56.10)  |  kube-worker-1 & 2 (192.168.56.21 / 22)        |
+--------------------------------------------------------------------------------------------------+
                                                 |
         +---------------------------------------+---------------------------------------+
         |                                       |                                       |
+-----------------+                   +---------------------+                 +--------------------+
|  CORE BASELINE  |                   | OPTIONAL BLOCK TIER |                 | OPTIONAL SAN TIER  |
|   (Always On)   |                   |    (On Demand)      |                 |    (On Demand)     |
+-----------------+                   +---------------------+                 +--------------------+
|   NFS Server    |                   |  1. Ceph RBD (CSI)  |                 | 3. FC SAN Emulator |
| (/srv/nfsroot & |                   |  2. iSCSI (LIO)     |                 |    (Dual Fabric    |
| /exports link)  |                   |     Target & IQN    |                 |     WWPNs & LUNs)  |
|  RWX / ReadOnly |                   |     (/srv/iscsi)    |                 |     (/srv/fc)      |
+-----------------+                   +---------------------+                 +--------------------+
```

### Storage Providers Modularity Matrix

| Tier | Provider | Kubernetes Volume Plugin | Default Status | Make Target | Primary Access Modes | Volume Mode |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Baseline** | **NFS** | In-Tree (`nfs`) & CSI (`csi-driver-nfs`) | **Enabled** (Default) | `make preprod-nfs` | `ReadWriteMany` (RWX), `ReadOnlyMany` (ROX) | Filesystem |
| **Optional 1** | **Ceph RBD** | Ceph CSI (`rbd.csi.ceph.com`) | **Optional** (`rook_ceph_rbd_enabled: false`) | `make preprod-ceph` | `ReadWriteOnce` (RWO), `ReadWriteOncePod` (RWOP) | Filesystem & Block |
| **Optional 2** | **iSCSI** | In-Tree (`iscsi`) | **Optional** (`iscsi_target_enabled: false`) | `make preprod-iscsi` | `ReadWriteOnce` (RWO) | Filesystem & Block |
| **Optional 3** | **FC SAN** *(New)* | In-Tree (`fc`) | **Optional** (`fc_san_enabled: false`) | `make preprod-fc` | `ReadWriteOnce` (RWO) | Filesystem & Block |

---

## 2. NFS Root Migration & Backward Compatibility (`/srv/nfsroot` + `/exports`)

To align with the FHS standard while preserving full backward compatibility for all existing scripts and manifests:

1. **Standardize Export Directory**:
   - Primary physical path becomes `/srv/nfsroot` (configured via `nfs_export_dir: "/srv/nfsroot"` in `group_vars/all.yml`).
   - Create symbolic link `/exports -> /srv/nfsroot` on `kube-control-plane` (and worker mount roots if applicable).
2. **NFS Server Configuration (`roles/nfs_server`)**:
   - Ensure `/srv/nfsroot` is created with permissions `0777`.
   - Symlink `/exports` to `/srv/nfsroot`.
   - Export `/srv/nfsroot` (and/or `/exports`) in `/etc/exports` with options `rw,sync,no_subtree_check,no_root_squash,insecure,fsid=0`.
3. **CKA Lab Manifests & Backward Compatibility**:
   - Update `cka_lab_nfs_export_dir` default to `/srv/nfsroot`.
   - Existing drills referencing either `/srv/nfsroot` or `/exports` resolve identically via the filesystem symlink and NFSv4 root pseudo-filesystem (`fsid=0`).

---

## 3. Fibre Channel SAN Emulation Architecture

Kubernetes `kubelet` attaches Fibre Channel volumes using its in-tree `pkg/volume/fc` driver. On Linux worker nodes, kubelet identifies attached FC block devices by scanning `/dev/disk/by-path/` matching:

1. `/dev/disk/by-path/pci-*-fc-0x${targetWWN}-lun-${lun}` or `*-fc-0x${targetWWN}-lun-${lun}`
2. Device WWIDs under `/dev/disk/by-id/wwn-0x${wwid}`
3. Multipath device mappers under `/dev/mapper/`

### A. Emulated SAN Fabric Topology

- **SAN Storage Array Model**: `os76-san-array01` (Dual-Fabric Redundant Controller Emulation)
- **Primary Fabric A Target WWPN**: `5001438024266301`
- **Secondary Fabric B Target WWPN**: `5001438024266302` (Dual-path multipath verification)
- **Target WWNN**: `20000025b5000001`
- **Backstore Path**: `/srv/fc/`
- **LUN Inventory**:
  - `LUN 0` (512 MiB): Filesystem volume target (ext4, formatted on first mount) at `/srv/fc/lun0.img`
  - `LUN 1` (512 MiB): Raw block volume target (`volumeMode: Block`) at `/srv/fc/lun1.img`
  - `LUN 2` (1024 MiB): Dynamic expansion & reclaim recovery target at `/srv/fc/lun2.img`

### B. Host & Node Emulation Engine (`roles/fc_san`)

1. **Target Controller Provisioning (`kube-control-plane`)**:
   - Manages sparse backing LUN disk images in `/srv/fc/` (`lun0.img`, `lun1.img`, `lun2.img`).
   - Exposes SAN status API and CLI utility `fc-san-ctl` (list LUNs, grow LUN, simulate link state).
2. **Node Initiator & udev Topology (`kube-worker-1`, `kube-worker-2`)**:
   - Attaches backing block devices and installs canonical FC udev rules (`/etc/udev/rules.d/99-fc-san.rules`).
   - Generates predictable device paths conforming strictly to Kubernetes `pkg/volume/fc` conventions:
     - `/dev/disk/by-path/pci-0000:00:03.0-fc-0x5001438024266301-lun-0`
     - `/dev/disk/by-path/pci-0000:00:04.0-fc-0x5001438024266302-lun-0` (Fabric B multipath link)
     - `/dev/disk/by-path/pci-0000:00:03.0-fc-0x5001438024266301-lun-1` (Raw block LUN)
     - `/dev/disk/by-id/wwn-0x50014380242663010000000000000000`
   - Populates sysfs mock adapter nodes in `/sys/class/fc_host/host1` and `/sys/class/fc_host/host2` (`port_name`, `node_name`, `speed`, `port_state`) for authentic diagnostics via `systool -c fc_host -v`.
3. **Optional Dual-Fabric Multipathing**:
   - Preconfigures `multipath.conf` with active/passive ALUA path grouping for WWPNs `5001438024266301` and `5001438024266302`.

---

## 4. Hands-on Volume Management Drills Matrix (All 4 Storage Options)

Every storage option provides dedicated exercises covering core volume management competencies:

### Option 1: NFS (`12-volumes/01-nfs/`) [Baseline Shared Filesystem]

1. **Drill 1.1 — Inline Diagnostic Mount**: Direct inline `volumes.nfs` mount in Pod spec (`01-nfs-direct-pod.yaml`).
2. **Drill 1.2 — Multi-Node Shared Write**: Concurrent `ReadWriteMany` (RWX) multi-replica deployment sharing `/srv/nfsroot` (`02-nfs-deployment-shared.yaml`).
3. **Drill 1.3 — Static PV/PVC Lifecycle**: Hand-crafting PV and PVC manifests, observing `Available` $\to$ `Bound` $\to$ `Released` status transitions (`03-nfs-pv.yaml`, `04-nfs-pvc.yaml`).
4. **Drill 1.4 — Reclaim Policy Live Mutation**: Patching `persistentVolumeReclaimPolicy` from `Delete` to `Retain` using `kubectl patch`.
5. **Drill 1.5 — Dynamic Provisioning**: Utilizing `csi-driver-nfs` StorageClass for automatic PVC volume binding.

### Option 2: Ceph RBD (`12-volumes/06-rbd/`) [Cloud-Native Distributed Block]

1. **Drill 2.1 — Dynamic Filesystem Claim**: Dynamic block provisioning with ext4 filesystem format (`01-rbd-dynamic-filesystem.yaml`).
2. **Drill 2.2 — Raw Block Mode**: Deploying `volumeMode: Block` with `volumeDevices` directly exposed as a raw block device inside container namespaces (`02-rbd-raw-block.yaml`).
3. **Drill 2.3 — Static CSI PV Binding**: Binding an existing Ceph image to a static PV using `spec.csi.volumeHandle` (`03-rbd-static-pv-pvc-pod.yaml`).
4. **Drill 2.4 — Online Volume Expansion**: Live capacity expansion (`allowVolumeExpansion: true`) with in-flight filesystem resizing (`04-rbd-pvc-expansion.yaml`).
5. **Drill 2.5 — RWOP Concurrency Guard**: Demonstrating `ReadWriteOncePod` single-pod attachment protection.

### Option 3: iSCSI (`12-volumes/07-iscsi/`) [IP SAN Block Storage]

1. **Drill 3.1 — Direct Inline Mount**: Pod spec with inline `volumes.iscsi` referencing portal and IQN (`01-iscsi-direct-pod.yaml`).
2. **Drill 3.2 — Static PV/PVC Filesystem Mount**: Decoupled PV (`iscsi-static-pv`) and PVC with `ReadWriteOnce` (`02-iscsi-pv-pvc-pod.yaml`).
3. **Drill 3.3 — Raw Block Mode**: Raw block attachment (`volumeMode: Block`) mapped to `/dev/iscsiblock` (`03-iscsi-raw-block.yaml`).
4. **Drill 3.4 — Multi-Node Attach Conflict**: Demonstrating multi-node RWO attach conflict and node fencing (`04-iscsi-two-nodes-rwo.yaml`).
5. **Drill 3.5 — Authenticated CHAP Integration**: Securing iSCSI LUNs using Kubernetes Secrets and target portal credentials (`05-iscsi-chap-secret.yaml`).
6. **Drill 3.6 — Target Capacity Expansion**: Resizing backing target LUN and issuing online `resize2fs`.

### Option 4: Fibre Channel SAN (`12-volumes/08-fc/` — *New*) [Enterprise FC SAN Block Storage]

1. **Drill 4.1 — Direct Inline FC Mount**: Inline Pod volume referencing `fc.targetWWNs` (`["5001438024266301"]`) and `fc.lun: 0` (`01-fc-direct-pod.yaml`).
2. **Drill 4.2 — Static PV & PVC Lifecycle**: Authoring a production-grade FC PersistentVolume with `storageClassName: fc-manual`, `accessModes: [ReadWriteOnce]`, and matching PVC (`02-fc-pv-pvc-pod.yaml`).
3. **Drill 4.3 — Raw SAN Block Mode**: Provisioning `volumeMode: Block` with `volumeDevices` mapping directly to `/dev/fcblock` (`03-fc-raw-block.yaml`).
4. **Drill 4.4 — Dual-Fabric Multipath & Failover**: Configuring `targetWWNs` with both Fabric A (`5001438024266301`) and Fabric B (`5001438024266302`), simulating fabric link failure, and verifying uninterrupted I/O (`04-fc-multipath-pv-pvc.yaml`).
5. **Drill 4.5 — SAN Reclaim & Disaster Recovery**: Exercising `persistentVolumeReclaimPolicy: Retain`, deleting the PVC, and re-binding the un-scrubbed SAN LUN to a recovery PV to retrieve persistent data (`05-fc-reclaim-recovery-drill.md`).
6. **Drill 4.6 — SAN LUN Resizing**: Growing the SAN LUN using `fc-san-ctl grow-lun 0 1G` and expanding the Kubernetes PVC without unmounting the running workload (`06-fc-lun-expansion.yaml`).

---

## 5. Proposed Repository Implementation & File Tree

### A. New Role: `roles/fc_san/`

```text
k8s-homelab/roles/fc_san/
├── README.md
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── target.yml
│   └── initiator.yml
└── templates/
    ├── 99-fc-san.rules.j2
    └── fc_san_ctl.sh.j2
```

### B. Updated Roles for NFS Standardization

- `k8s-homelab/group_vars/all.yml`:
  - `nfs_export_dir: "/srv/nfsroot"`
  - `nfs_legacy_export_symlink: "/exports"`
- `k8s-homelab/roles/nfs_server/tasks/main.yml`:
  - Creates `/srv/nfsroot`
  - Creates symlink `/exports -> /srv/nfsroot`
  - Updates `/etc/exports` with `/srv/nfsroot` and `fsid=0`

### C. New Playbook & Automation Targets

- `k8s-homelab/playbooks/fc.yml`
- Add Makefile commands to `k8s-homelab/Makefile`:
  - `make preprod-fc`: Deploys Fibre Channel SAN emulation target and initiator udev rules.
  - `make preprod-fc-status`: Inspects active WWPNs, LUNs, and mapped paths.

### D. Updates to CKA Practice Scenarios (`roles/cka_lab`)

Directory layout under `/home/vagrant/cka/12-volumes/`:

```text
/home/vagrant/cka/12-volumes/
├── README.md                                  # Master volume guide with FC SAN coverage
├── test-volumes-drills.sh                     # Automated validation suite (supports --fc)
├── test-nfs-mounts.sh
├── 01-nfs/                                    # NFS Baseline shared filesystem (/srv/nfsroot)
├── 02-emptydir/                               # Ephemeral scratch storage
├── 03-hostpath/                               # Node filesystem mounting
├── 04-configmap-secret/                       # In-memory projected volumes
├── 05-pv-pvc-lifecycle/                       # Core exam binding & reclaim drills
├── 06-rbd/                                    # Optional Ceph RBD block storage
├── 07-iscsi/                                  # Optional iSCSI IP SAN storage
├── 08-fc/                                     # Optional Fibre Channel SAN storage [NEW]
│   ├── README.md                              # Dedicated FC SAN practice guide
│   ├── test-fc-volumes.sh                     # Non-interactive automated test suite
│   ├── 01-fc-direct-pod.yaml                  # Direct in-tree pod volume mount
│   ├── 02-fc-pv-pvc-pod.yaml                  # Static PV/PVC filesystem mount
│   ├── 03-fc-raw-block.yaml                   # Raw block mode (volumeMode: Block)
│   ├── 04-fc-multipath-pv-pvc.yaml            # Dual-fabric multipath PV/PVC
│   ├── 05-fc-reclaim-recovery-drill.md        # Reclaim & disaster recovery guide
│   └── 06-fc-lun-expansion.yaml              # Live SAN LUN & PVC capacity expansion
└── 09-nfs-csi -> ../storage-classes/02-storage-classes
```

---

## 6. Quality Gates & Validation Steps

1. **Ansible Linting**:
   Passes `ANSIBLE_ROLES_PATH=k8s-homelab/roles ansible-lint -c k8s-homelab/.ansible-lint k8s-homelab/playbooks/site.yml` and `fc.yml` with 0 failures and 0 warnings.
2. **Shell Script Validation**:
   `shellcheck -s bash` on `test-fc-volumes.sh` and `fc_san_ctl.sh`.
3. **YAML Syntax & Schema**:
   `yamllint -c .yamllint` on all new manifests.
4. **Markdown Standards**:
   `markdownlint-cli2` following MD012 and MD029 standards.
5. **Changelog Entry**:
   Add high-level entry under `## [Unreleased]` in `k8s-homelab/CHANGELOG.md`.

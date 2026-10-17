# Implementation Plan: Storage, Volumes & StorageClasses Drills for CKA Lab

**Target Scenarios:** `k8s-homelab/roles/cka_lab/tasks/scenario_volumes.yml` & `scenario_storage_classes.yml`  
**Target VM Directories:** `/home/vagrant/cka/volumes/` & `/home/vagrant/cka/storage-classes/`  
**Curriculum Domain:** CNCF CKA — Storage (10%), Workloads & Scheduling (15%)  

---

## 1. Objectives & Executive Summary

The **Storage** domain in the CKA exam validates candidate proficiency in persisting state, provisioning dynamic and static volumes, and governing storage lifecycle policies. Candidates must understand how Pods attach to storage, how Claims bind to Volumes, and how StorageClasses orchestrate dynamic provisioners.

While `k8s-homelab/roles/cka_lab` already provisions rich NFS, Ceph, and iSCSI infrastructures, this plan unifies and structures all exercises into a coherent **Storage Master Chapter**:

1. A master pedagogical **`README.md`** aligning static and dynamic storage drills with CKA exam competencies and permitted documentation.
2. Comprehensive **PV and PVC lifecycle drills** (creation, status phases `Pending` $\to$ `Bound` $\to$ `Released`, selector matching, capacity requests).
3. **Access Modes mastering**:
   - `ReadWriteOnce` (RWO) vs `ReadWriteMany` (RWX) vs `ReadOnlyMany` (ROX) vs `ReadWriteOncePod` (RWOP).
4. **Reclaim Policy management & live mutation**:
   - Demonstrating `Retain` (data preserved upon PVC deletion) vs `Delete` (underlying asset deleted).
   - Live mutation of PV reclaim policy using `kubectl patch`.
5. **StorageClass parameterization & Volume Binding Modes**:
   - Contrasting `volumeBindingMode: Immediate` against `volumeBindingMode: WaitForFirstConsumer` (topological delayed scheduling).
   - Dynamic provisioning via `local-path` and `csi-driver-nfs`.
6. **Online PVC volume expansion**:
   - Configuring `allowVolumeExpansion: true` on StorageClasses.
   - Performing online capacity expansion on live PVCs without pod recreation.
7. **Ephemeral and node-local volume mechanisms**:
   - `emptyDir` (scratch disk vs in-memory RAM disk `medium: Memory`).
   - `hostPath` (types `DirectoryOrCreate`, `File`).
8. End-to-end automated **verification suites** (`test-volumes-drills.sh` and `test-storage-classes-drills.sh`).

> [!IMPORTANT]
> **Copyright & Attribution Policy**:
> All generated artifacts (READMEs, templates, manifests, test scripts, and CHANGELOG entries) must strictly reference only canonical official Kubernetes documentation (`kubernetes.io/docs/`) and official CNCF CKA exam objectives. Never cite proprietary course names, books, or third-party training authors.

---

## 2. Curriculum & Documentation Alignment

### A. CNCF CKA Exam Competencies

- **Storage Architecture**: Understanding the separation of concerns between Cluster Administrator (`PersistentVolume`, `StorageClass`) and Application Developer (`PersistentVolumeClaim`, `Pod.spec.volumes`).
- **Access Modes**: Selecting appropriate access modes for single-node databases vs multi-replica web workers.
- **Lifecycle & Reclaim Policies**: Managing persistent data retention and preventing accidental data loss during namespace cleanups.
- **Delayed Binding (`WaitForFirstConsumer`)**: Avoiding scheduling deadlocks where a PV is provisioned on a node that lacks compute resources to run the scheduled pod.
- **Dynamic Volume Expansion**: Expanding persistent capacity dynamically while workloads remain operational.

### B. Permitted Official Exam Documentation (`kubernetes.io/docs/`)

- Concepts:
  - `https://kubernetes.io/docs/concepts/storage/persistent-volumes/`
  - `https://kubernetes.io/docs/concepts/storage/storage-classes/`
  - `https://kubernetes.io/docs/concepts/storage/volumes/`
- Tasks:
  - `https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/`
  - `https://kubernetes.io/docs/tasks/administer-cluster/change-pv-reclaim-policy/`
- Reference & Cheat Sheet:
  - `https://kubernetes.io/docs/reference/kubectl/cheatsheet/#viewing-and-finding-resources`
- Terminal `kubectl explain` fast paths:

  ```bash
  kubectl explain pv.spec
  kubectl explain pv.spec.accessModes
  kubectl explain pv.spec.persistentVolumeReclaimPolicy
  kubectl explain pvc.spec.resources.requests.storage
  kubectl explain storageclass.volumeBindingMode
  kubectl explain storageclass.allowVolumeExpansion
  kubectl explain pod.spec.volumes.persistentVolumeClaim
  ```

---

## 3. Proposed Directory Structure on Control Plane

### A. Static Volumes & Node Storage (`/home/vagrant/cka/volumes/`)

```text
/home/vagrant/cka/volumes/
├── README.md                                  # Master volume guide & exam walkthrough
├── test-volumes-drills.sh                     # Automated validation suite for volumes
├── 01-nfs/                                    # Shared network storage (NFS RWX)
│   ├── 01-nfs-direct-pod.yaml                 # Direct inline volume mount
│   ├── 02-nfs-deployment-shared.yaml          # Multi-replica RWX shared data deployment
│   ├── 03-nfs-pv.yaml                         # Static PersistentVolume definition
│   ├── 04-nfs-pvc.yaml                        # PersistentVolumeClaim definition
│   └── 05-nfs-pvc-pod.yaml                    # Pod consuming static NFS PVC
├── 02-emptydir/                               # Ephemeral scratch storage
│   ├── 01-emptydir-sidecar-pod.yaml           # Shared multi-container volume
│   └── 02-emptydir-memory-pod.yaml            # RAM disk (medium: Memory)
├── 03-hostpath/                               # Node filesystem mounting
│   ├── 01-hostpath-pod.yaml                   # hostPath DirectoryOrCreate mount
│   └── 02-hostpath-log-viewer.yaml            # Reading node /var/log securely
├── 04-configmap-secret/                       # In-memory projected volumes
│   ├── 01-configmap-volume-pod.yaml           # ConfigMap directory mount
│   └── 02-secret-volume-pod.yaml              # Secret volume with restrictive permissions
└── 05-pv-pvc-lifecycle/                       # Core exam binding & reclaim drills
    ├── 01-local-pv-pvc.yaml                   # Static PV/PVC pairing with nodeAffinity
    ├── 02-pvc-expansion.yaml                  # Online PVC expansion manifest
    ├── 03-reclaim-policy-drill.md             # Reclaim policy manual inspection guide
    ├── reclaim-mutation-drill.sh              # Script patching PV from Delete to Retain
    └── test-reclaim-mutation.sh               # Automated verification of reclaim mutation
```

### B. Dynamic StorageClasses (`/home/vagrant/cka/storage-classes/`)

```text
/home/vagrant/cka/storage-classes/
├── README.md                                  # Master StorageClass guide & exam walkthrough
├── test-storage-classes-drills.sh             # Automated validation suite for StorageClasses
├── 01-provisioners/                           # Dynamic CSI provisioners
│   ├── install-local-path-provisioner.sh      # Rancher local-path dynamic provisioner
│   └── install-nfs-csi-driver.sh              # Official Kubernetes SIG NFS CSI driver
└── 02-storage-classes/                        # StorageClass definitions & drills
    ├── cka-lab-sc-retain.yaml                 # SC with reclaimPolicy: Retain & Immediate
    ├── cka-lab-sc-delete-wait.yaml            # SC with WaitForFirstConsumer binding
    ├── cka-lab-dynamic-pvc.yaml               # Dynamic PVC requesting storage from SC
    ├── cka-lab-consumer-pod.yaml              # Workload triggering delayed provisioning
    ├── 03-nfs-csi-sc.yaml                     # Dynamic NFS StorageClass (RWX)
    ├── 04-nfs-dynamic-pvc.yaml                # Dynamic RWX PVC
    └── 05-nfs-shared-deployment.yaml          # Multi-replica workload sharing dynamic NFS
```

---

## 4. Detailed Drill Walkthrough & Synergy with Existing Repo Assets

### Drill 1: Static PV and PVC Lifecycle Pairing (`volumes/05-pv-pvc-lifecycle/`)

1. **Static Volume Allocation**:
   Authoring a `PersistentVolume` with explicit storage capacity (`5Gi`), `storageClassName: manual`, and `accessModes: [ReadWriteOnce]`.
2. **Claim Binding Mechanics**:
   Authoring a `PersistentVolumeClaim` that matches capacity, access mode, and storage class.
3. **Observing Lifecycle Transitions**:
   Monitoring status transitions from `Available` $\to$ `Bound`.

### Drill 2: Reclaim Policy Mutation & Data Preservation (`volumes/05-pv-pvc-lifecycle/`)

1. **The Reclaim Dilemma**:
   By default, dynamically provisioned PVs often use `Delete`. If a developer deletes the PVC, the underlying data volume is permanently destroyed.
2. **Live Patching Reclaim Policy**:

   ```bash
   kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
   ```

3. **Verification**:
   Deleting the PVC, observing the PV transition to `Released` rather than being deleted, preserving data on disk for manual recovery.

### Drill 3: StorageClass Dynamic Provisioning & Binding Modes (`storage-classes/`)

1. **Immediate Provisioning**:
   StorageClass with `volumeBindingMode: Immediate`. Creating a PVC immediately calls the CSI provisioner to allocate a volume before any pod is scheduled.
2. **Delayed Provisioning (`WaitForFirstConsumer`)**:
   StorageClass with `volumeBindingMode: WaitForFirstConsumer`. The PVC remains in `Pending` state upon creation and only binds when a consuming Pod is scheduled, ensuring the volume is provisioned on the exact worker node where the Pod's compute requirements can be satisfied.

### Drill 4: Online Volume Expansion (`volumes/05-pv-pvc-lifecycle/`)

1. **Enabling Expansion**:
   Ensuring the StorageClass specifies `allowVolumeExpansion: true`.
2. **Expanding Live Claim**:

   ```bash
   kubectl patch pvc dynamic-claim -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
   ```

3. **Verifying Filesystem Expansion**:
   Observing `pvc.status.capacity.storage` update without needing to delete or restart the workload.

### Drill 5: Ephemeral Scratch vs Shared Multi-Node Storage

1. **`emptyDir` (`volumes/02-emptydir/`)**:
   Comparing fast scratch disk storage against RAM-backed memory volumes (`medium: Memory`).
2. **NFS Shared Storage (`volumes/01-nfs/`)**:
   Demonstrating `ReadWriteMany` (RWX) where multiple pods running across different worker nodes (`kube-worker-1`, `kube-worker-2`) write concurrently to `/exports`.

---

## 5. Implementation Steps in Ansible Monorepo

1. **Jinja2 Templates Updates (`roles/cka_lab/templates/`)**:
   - `volumes_readme.md.j2`: Master guide updated with exact CKA keywords, allowed docs, and reclaim drills.
   - `storage_classes_readme.md.j2`: Master guide updated with binding modes and expansion drills.
   - `volumes_test_drills.sh.j2`: Consolidated automated verification suite testing all volume types.
   - `storage_classes_test_drills.sh.j2`: Consolidated automated verification suite testing dynamic provisioning.

2. **Ansible Task Updates (`roles/cka_lab/tasks/`)**:
   - Ensure clean execution in `scenario_volumes.yml` and `scenario_storage_classes.yml`.

3. **Quality Gates & Linters**:
   - `shellcheck -s bash` on all shell scripts.
   - `yamllint -c .yamllint` on YAML manifests and tasks.
   - `nix shell nixpkgs#markdownlint-cli2 --command markdownlint-cli2` on markdown templates and docs.
   - `nix shell nixpkgs#ansible-lint` passing with 0 failures/warnings.

4. **Changelog**:
   - Update `k8s-homelab/CHANGELOG.md` under `## [Unreleased]`.

# Kubernetes Cluster Upgrade TODOs & Version Evolution Checklist

Operational tracking document, prerequisites, breaking changes, and validation procedures for upgrading the `k8s-homelab` cluster across minor versions from **v1.34** through **v1.37**.

---

## 1. Architectural Rules of Thumb & Version Skew Policy

1. **Sequential Minor Upgrades Only**:
   - Never skip minor versions (e.g. `1.34 → 1.35 → 1.36 → 1.37`).
   - Upgrading directly from `1.34` to `1.36` or `1.37` is strictly unsupported by `kubeadm` and the Kubernetes control plane.
1. **Control Plane First**:
   - Always upgrade the control plane node (`kube-control-plane`) completely before upgrading any worker nodes (`kube-worker-1`, `kube-worker-2`).
1. **Version Skew Constraints**:
   - `kubelet` must **never** be newer than `kube-apiserver`.
   - `kubelet` may be at most **3 minor versions older** than `kube-apiserver` (in production), but for `kubeadm` upgrades, keep worker nodes within **1 minor version** of the control plane.
   - `kubectl` is supported within **1 minor version** (older or newer) of `kube-apiserver`.
1. **Node Maintenance Hygiene**:
   - Always `drain` nodes before upgrading the host `kubelet` service:

     ```bash
     kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
     ```

   - Always `uncordon` nodes after service restart:

     ```bash
     kubectl uncordon <node-name>
     ```

---

## 2. Upgrade Hop 1: v1.34 → v1.35 (Target CKA Exam Curriculum)

### Pre-Upgrade Checklist & Breaking Changes

- [ ] **etcd Snapshot Backup**:
  - Run manual etcd backup drill (`~/cka/02-etcd/01-backup-restore/`) or verify systemd backup timer:

    ```bash
    systemctl status etcd-backup.timer
    /usr/local/bin/etcd-backup.sh
    ```

- [ ] **Kubeadm Configuration Schema**:
  - `kubeadm.k8s.io/v1beta3` is completely removed. Ensure any declarative init/join manifests use `apiVersion: kubeadm.k8s.io/v1beta4`.
  - Convert legacy configuration files:

    ```bash
    kubeadm config migrate --old-config kubeadm-old.yaml --new-config kubeadm-v1beta4.yaml
    ```

- [ ] **CLI Syntax Compliance**:
  - Verify zero usage of deprecated `kubectl autoscale --cpu-percent` (must use `--cpu=50%` or `--cpu=500m`).
  - Verify all manifest generators use `--dry-run=client -o yaml`.

### Step-by-Step Upgrade Execution

1. **Update Control Plane**:

   ```bash
   # On kube-control-plane:
   sudo apt-mark unhold kubeadm
   sudo apt-get update && sudo apt-get install -y kubeadm=1.35.x-1.1
   sudo apt-mark hold kubeadm

   # Plan and execute control plane upgrade
   sudo kubeadm upgrade plan
   sudo kubeadm upgrade apply v1.35.x -y

   # Drain control plane (if hosting application pods)
   kubectl drain kube-control-plane --ignore-daemonsets --delete-emptydir-data

   # Upgrade kubelet and kubectl
   sudo apt-mark unhold kubelet kubectl
   sudo apt-get install -y kubelet=1.35.x-1.1 kubectl=1.35.x-1.1
   sudo apt-mark hold kubelet kubectl

   # Restart kubelet and restore scheduling
   sudo systemctl daemon-reload && sudo systemctl restart kubelet
   kubectl uncordon kube-control-plane
   ```

1. **Update Worker Nodes (Sequentially)**:

   ```bash
   # From kube-control-plane:
   kubectl drain kube-worker-1 --ignore-daemonsets --delete-emptydir-data

   # On kube-worker-1:
   sudo apt-mark unhold kubeadm
   sudo apt-get update && sudo apt-get install -y kubeadm=1.35.x-1.1
   sudo apt-mark hold kubeadm
   sudo kubeadm upgrade node

   sudo apt-mark unhold kubelet kubectl
   sudo apt-get install -y kubelet=1.35.x-1.1 kubectl=1.35.x-1.1
   sudo apt-mark hold kubelet kubectl
   sudo systemctl daemon-reload && sudo systemctl restart kubelet

   # From kube-control-plane:
   kubectl uncordon kube-worker-1

   # Repeat same sequence for kube-worker-2
   ```

### Post-Upgrade Feature Validation

- [ ] **In-Place Pod Resource Resizing (GA)**:
  - Run the automated drill in `~/cka/04-pods/05-spec-immutability/inplace-resize-drill.sh`.
  - Confirm container CPU/memory requests can be modified via patch with 0 container restarts.
- [ ] **Node-Local Traffic Distribution (`PreferSameNode`)**:
  - Deploy `~/cka/06-networking/01-services/cka-lab-traffic-distribution-svc.yaml`.
  - Verify `trafficDistribution: PreferSameNode` is accepted and active in `kubectl describe svc`.
- [ ] **Pod Generation Tracking**:
  - Inspect `kubectl get pod -o jsonpath='{.metadata.generation}'` to confirm generation incrementation.

---

## 3. Upgrade Hop 2: v1.35 → v1.36 ("Haru")

### Pre-Upgrade Checklist & Breaking Changes

- [ ] **Container Runtime (CRI) Capabilities**:
  - Verify containerd supports User Namespaces (containerd v1.7+ / v2.0+).
- [ ] **Cilium CNI Compatibility**:
  - Check Cilium eBPF host routing against 1.36 kernel interfaces (`cilium status`).
- [ ] **Admission Controllers**:
  - Review Mutating Admission Policy capabilities if transitioning from webhook-based mutation to CEL.

### Post-Upgrade Feature Validation

- [ ] **User Namespaces Support (GA)**:
  - Deploy a test pod with `spec.hostUsers: false`:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: userns-pod
    spec:
      hostUsers: false
      containers:
        - name: app
          image: busybox:1.36.1
          command: ["sleep", "3600"]
    ```

  - Verify that root inside the container maps to an unprivileged UID on the host node (`cat /proc/self/uid_map`).
- [ ] **CEL Mutating Admission Policies (Beta)**:
  - Test declarative in-tree mutations via `admissionregistration.k8s.io/v1alpha1`.

---

## 4. Upgrade Hop 3: v1.36 → v1.37 ("Garhwal")

### Pre-Upgrade Checklist & Breaking Changes

- [ ] **Metrics API Migration (GA)**:
  - Update any custom APIService probes or monitoring manifests from `v1beta1.metrics.k8s.io` to `v1.metrics.k8s.io`.
  - Check Metrics Server health:

    ```bash
    kubectl get apiservice v1.metrics.k8s.io
    kubectl top nodes
    kubectl top pods
    ```

- [ ] **HPA Scale-to-Zero Verification**:
  - Test autoscaling workloads with `minReplicas: 0` on external/custom queue metrics.
- [ ] **Storage Hygiene**:
  - Verify `pvc.status.unusedSinceTime` reporting on idle PersistentVolumeClaims.

---

## 5. Automated Upgrade via Ansible (`upgrade.yml`)

The homelab provides automated rolling upgrade orchestration via Ansible:

```bash
cd k8s-homelab

# Execute automated rolling upgrade against target environment
./scripts/run-playbook.sh -e preprod -p upgrade.yml --extra-vars "k8s_version=1.35.1-1.1"
```

### Post-Execution Validation Suite

```bash
# Verify all cluster nodes report the target version
kubectl get nodes -o wide

# Run end-to-end CKA validation suites
~/cka/test-all-drills.sh
~/cka/04-pods/test-pods-drills.sh
~/cka/05-scheduling/test-scheduling-drills.sh
~/cka/06-networking/test-networking-drills.sh
~/cka/16-upgrade/test-upgrade-drills.sh
```

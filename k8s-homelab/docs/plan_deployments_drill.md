# Implementation Plan: Deployments & Workload Rollout Drills for CKA Lab

**Target Scenario:** `k8s-homelab/roles/cka_lab/tasks/scenario_deployments.yml`  
**Target VM Directory:** `/home/vagrant/cka/deployments/`  
**Curriculum Domain:** CNCF CKA — Workloads & Scheduling (15%), Troubleshooting (30%)  

---

## 1. Objectives & Executive Summary

The **Deployment** primitive is the central workload controller in Kubernetes for stateless applications. In the CKA exam, candidates are tested on rapid declarative and imperative workload deployment, zero-downtime rolling update tuning, rollback management, label selector troubleshooting, and batch configuration changes.

While `k8s-homelab/roles/cka_lab/tasks/scenario_deployments.yml` already provides a solid foundation of manifests across five subdirectories, this plan enhances the module to reach complete CKA curriculum parity:

1. A comprehensive pedagogical **`README.md`** aligning all drills with official CNCF exam objectives and permitted documentation.
2. Step-by-step **imperative generation drills** (`kubectl create deployment`, `kubectl set image`, `kubectl scale`, `kubectl autoscale`).
3. Hands-on **rollout history & revision management** (`kubectl rollout status`, `kubectl rollout history --revision`, `kubectl rollout undo --to-revision`).
4. In-depth **upgrade strategies tuning** (`maxSurge` vs `maxUnavailable` in integers and percentages, and `type: Recreate`).
5. **Selector immutability & label troubleshooting** (diagnosing selector mismatches, handling immutable label rejections).
6. **Batch atomic mutations** using `kubectl rollout pause` and `kubectl rollout resume`.
7. **Pod quarantine and autopsy drill** (modifying labels on failing deployment pods for offline debugging without interrupting replica health).
8. An automated **verification test suite** (`test-deployments-drills.sh`).

> [!IMPORTANT]
> **Copyright & Attribution Policy**:
> All generated artifacts (READMEs, templates, manifests, test scripts, and CHANGELOG entries) must strictly reference only canonical official Kubernetes documentation (`kubernetes.io/docs/`) and official CNCF CKA exam objectives. Never cite proprietary course names, books, or third-party training authors.

---

## 2. Curriculum & Documentation Alignment

### A. CNCF CKA Exam Competencies

- **Workload Management**: Creating, maintaining, and scaling multi-replica Deployments.
- **Rollout Lifecycle**: Performing progressive updates, inspecting revision history, recording change causes, and executing rollbacks.
- **Strategy Tuning**: Configuring `RollingUpdate` parameters (`maxSurge`, `maxUnavailable`) for zero-downtime releases vs `Recreate` for singleton workloads.
- **Atomic Batch Changes**: Pausing rollouts to apply multiple container/spec updates before resuming.
- **Controller Troubleshooting**: Resolving pod selector mismatches, immutable field rejections, and image pull failures.

### B. Permitted Official Exam Documentation (`kubernetes.io/docs/`)

- Concepts:
  - `https://kubernetes.io/docs/concepts/workloads/controllers/deployment/`
  - `https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/`
- Tasks:
  - `https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/`
  - `https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/`
- Reference & Cheat Sheet:
  - `https://kubernetes.io/docs/reference/kubectl/cheatsheet/#updating-resources`
- Terminal `kubectl explain` fast paths:

  ```bash
  kubectl explain deployment.spec.strategy
  kubectl explain deployment.spec.strategy.rollingUpdate.maxSurge
  kubectl explain deployment.spec.strategy.rollingUpdate.maxUnavailable
  kubectl explain deployment.spec.revisionHistoryLimit
  kubectl explain deployment.spec.template.spec.containers
  ```

---

## 3. Proposed Directory Structure on Control Plane (`/home/vagrant/cka/deployments/`)

```text
/home/vagrant/cka/deployments/
├── README.md                                  # Master CKA guide, references & drill instructions
├── test-deployments-drills.sh                 # Automated end-to-end verification script
├── 01-basic-deployment/
│   ├── run-imperative.sh                      # Rapid imperative kubectl deployment creation
│   ├── web-frontend-deployment.yaml           # HA frontend proxy manifest (3 replicas)
│   └── api-service-deployment.yaml            # Backend API service manifest
├── 02-troubleshooting-labels/
│   ├── README.md                              # Selector immutability & autopsy walkthrough
│   ├── broken-deployment.yaml                 # Intentional selector mismatch
│   ├── fixed-deployment.yaml                  # Corrected matching labels manifest
│   └── quarantine-drill.sh                    # Pod isolation & autopsy drill script
├── 03-rolling-updates-rollbacks/
│   ├── 01-catalog-v1.yaml                     # Baseline release (v1: nginx:1.24-alpine)
│   ├── 02-catalog-v2.yaml                     # Updated release (v2: nginx:1.25-alpine)
│   └── rollout-drill.sh                       # Interactive rollout, history & undo drill
├── 04-strategies/
│   ├── rolling-update-custom.yaml             # Zero-downtime bounds (maxSurge 1, maxUnavailable 0)
│   ├── rolling-update-percent.yaml            # Percentage bounds (maxSurge 25%, maxUnavailable 25%)
│   └── recreate-strategy.yaml                 # Downtime-tolerant singleton worker (type: Recreate)
└── 05-pause-resume/
    ├── batch-change-deployment.yaml           # Multi-attribute target deployment
    └── pause-resume-drill.sh                  # Interactive pause/resume walkthrough
```

---

## 4. Detailed Drill Walkthrough & Synergy with Existing Repo Assets

### Drill 1: Rapid Imperative Creation (`01-basic-deployment/`)

Creating and scaling Deployments imperatively under exam time constraints:

1. **Imperative generation with starter YAML**:

   ```bash
   kubectl create deployment web-app \
     --image=nginx:alpine \
     --replicas=3 \
     --port=80 \
     --dry-run=client -o yaml > web-app.yaml
   ```

2. **Scaling workloads on the fly**:

   ```bash
   kubectl scale deployment web-app --replicas=5
   ```

3. **In-place image updates with change annotations**:

   ```bash
   kubectl set image deployment/web-app nginx=nginx:1.26-alpine
   kubectl annotate deployment/web-app kubernetes.io/change-cause="Upgrade web-app to 1.26-alpine" --overwrite
   ```

### Drill 2: Selector Immutability & Pod Autopsy (`02-troubleshooting-labels/`)

1. **Selector Immutability**:
   Demonstrating that `spec.selector` cannot be updated once a Deployment is created. Attempts to mutate selectors fail with `field is immutable`.
2. **Selector Mismatch Troubleshooting**:
   Diagnosing situations where `spec.selector.matchLabels` does not match `spec.template.metadata.labels`, causing pods not to be recognized by the ReplicaSet.
3. **Pod Quarantine / Isolation Pattern**:
   Relabeling a misbehaving pod (`kubectl label pod <pod-name> app=quarantine --overwrite`). The ReplicaSet detects the lost replica and spawns a fresh healthy pod, leaving the failing pod alive for inspection.

### Drill 3: Progressive Rollouts & History Management (`03-rolling-updates-rollbacks/`)

1. **Deploying Baseline and Updating**:
   Applying `01-catalog-v1.yaml`, then updating with `02-catalog-v2.yaml`.
2. **Rollout Status and Revision History**:

   ```bash
   kubectl rollout status deployment/catalog-service
   kubectl rollout history deployment/catalog-service
   kubectl rollout history deployment/catalog-service --revision=2
   ```

3. **Rollback Execution**:

   ```bash
   # Revert to previous revision
   kubectl rollout undo deployment/catalog-service

   # Revert to explicit past revision
   kubectl rollout undo deployment/catalog-service --to-revision=1
   ```

### Drill 4: Strategy Tuning: Zero-Downtime vs. Recreate (`04-strategies/`)

1. **Zero-Downtime Guarantee**:
   Configuring `maxUnavailable: 0` and `maxSurge: 1` ensuring the cluster never drops below desired replica count during updates.
2. **Percentage-Based Bursts**:
   Configuring `maxSurge: 25%` and `maxUnavailable: 25%` for large multi-replica microservices.
3. **`type: Recreate`**:
   Configuring Deployments that terminate all old pods before creating new ones. Required for workloads using `ReadWriteOnce` volumes that cannot be mounted across nodes concurrently.

### Drill 5: Atomic Batch Updates via Pause & Resume (`05-pause-resume/`)

1. **Pausing Rollout**:

   ```bash
   kubectl rollout pause deployment/batch-app
   ```

2. **Applying Multiple Updates**:
   Modifying resources, updating image, changing environment variables, and adjusting probes without triggering multiple intermediate rollout revisions.
3. **Resuming Rollout**:

   ```bash
   kubectl rollout resume deployment/batch-app
   ```

   Validates that only **one** new ReplicaSet and rollout revision is triggered.

---

## 5. Implementation Steps in Ansible Monorepo

1. **Jinja2 Templates Creation / Updates (`roles/cka_lab/templates/`)**:
   - `deployments_readme.md.j2`: Master guide with CKA exam keywords and allowed docs.
   - `deployments_01_run_imperative.sh.j2`: Executable imperative script.
   - `deployments_02_quarantine_drill.sh.j2`: Pod quarantine autopsy script.
   - `deployments_test_drills.sh.j2`: Automated test suite asserting rollouts, undos, and strategies.

2. **Ansible Task Updates (`roles/cka_lab/tasks/scenario_deployments.yml`)**:
   - Render updated templates and scripts into `{{ cka_lab_deployments_dir }}`.

3. **Quality Gates & Linters**:
   - `shellcheck -s bash` on all `.sh.j2` scripts.
   - `yamllint -c .yamllint` on YAML manifests and tasks.
   - `nix shell nixpkgs#markdownlint-cli2 --command markdownlint-cli2` on markdown templates and docs.
   - `nix shell nixpkgs#ansible-lint` passing with 0 failures/warnings.

4. **Changelog**:
   - Update `k8s-homelab/CHANGELOG.md` under `## [Unreleased]`.

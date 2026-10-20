# Implementation Plan: Pre-Upgrade Deprecations Drill & Pluto Integration

**Target Scenario:** `k8s-homelab/roles/cka_lab/tasks/scenario_upgrade_drill.yml`  
**Target VM Directory:** `/home/vagrant/cka/16-upgrade/00-pre-upgrade-deprecations/`  
**Curriculum Domain:** CNCF CKA — Cluster Architecture, Installation & Configuration (25%)  
**Primary Focus:** Preflight API Deprecation Auditing (Phase 0), Pluto Scanner, and Practical API Migration  
**Target Upgrade Version:** Kubernetes **v1.37** (upgrading from **v1.36**)  

---

## 1. Root Cause Analysis: Why `kubectl apply` Failed on 1.36

When attempting to load `02-hpa-v2beta2.yaml` or `03-cronjob-v1beta1.yaml` on Kubernetes v1.36.0:

```text
error: resource mapping not found for name: "legacy-api-hpa" namespace: "default"
from "02-hpa-v2beta2.yaml": no matches for kind "HorizontalPodAutoscaler" in version "autoscaling/v2beta2"
```

### The Kubernetes API Lifecycle: Deprecation vs. Removal

Kubernetes adheres to a strict API lifecycle:

1. **Introduction**: Alpha (`v1alpha1`) $\to$ Beta (`v1beta1`) $\to$ GA (`v1`).
1. **Deprecation**: An older version is marked deprecated, but the API server continues to serve it for at least 3 minor
   releases or 12 months.
1. **Removal**: The API endpoint is **permanently deleted from the API server binary**. Once removed, `kube-apiserver`
   returns HTTP 404, which `kubectl apply` reports as `no matches for kind ... in version ...`.

| Manifest | API Version | Deprecated In | Removed In | Status on v1.36 API Server |
| --- | --- | --- | --- | --- |
| `01-ingress-v1beta1.yaml` | `networking.k8s.io/v1beta1` | v1.19 | **v1.22** | **Removed** (Cannot `kubectl apply`) |
| `02-hpa-v2beta2.yaml` | `autoscaling/v2beta2` | v1.23 | **v1.26** | **Removed** (Cannot `kubectl apply`) |
| `03-cronjob-v1beta1.yaml` | `batch/v1beta1` | v1.21 | **v1.25** | **Removed** (Cannot `kubectl apply`) |
| `04-pdb-v1beta1.yaml` | `policy/v1beta1` | v1.21 | **v1.25** | **Removed** (Cannot `kubectl apply`) |
| `05-kubeadm-v1beta3.yaml` | `kubeadm.k8s.io/v1beta3` | v1.27 | **v1.31** | **Removed** (Cannot `kubeadm` parse) |

These manifests are valid for **offline static scanner analysis** (`pluto detect-files -d ./deprecated-manifests`), but
cannot be loaded directly into a running v1.36 cluster via `kubectl apply`.

---

## 2. Cluster Upgrade Roadmap Scan: What Applies to v1.36 $\to$ v1.37?

An exhaustive scan of the Kubernetes v1.34 $\to$ v1.37 feature roadmap and API lifecycle reveals four distinct mechanisms
available to simulate pre-upgrade deprecation checks in an active v1.36 cluster:

### A. Native Built-In Kubernetes Resources Loadable in v1.36

These resources are actively served by Kubernetes v1.36. `kubectl apply` **succeeds**, writes the object to etcd, and
triggers live API server deprecation warnings:

1. **`Service.spec.externalIPs` (Formally Deprecated in v1.36 via KEP-3836)**:
   - Deprecated due to security risks (traffic interception / spoofing).
   - `kubectl apply` accepts the Service, but the API server emits:
     `Warning: spec.externalIPs is deprecated in v1.36+`.
2. **Pod / Workload `serviceAccount` Field (Deprecated in favor of `serviceAccountName`)**:
   - `spec.serviceAccount` is legacy syntax.
   - `kubectl apply` accepts the Pod/Deployment, but the API server emits:
     `Warning: spec.serviceAccount is deprecated in favor of spec.serviceAccountName`.
3. **Ingress `kubernetes.io/ingress.class` Annotation**:
   - Legacy annotation replaced by `spec.ingressClassName`.
   - `kubectl apply` accepts the Ingress, and live scanners flag the legacy annotation.
4. **Metrics API Transition (`metrics.k8s.io/v1beta1` $\to$ `v1` in v1.37)**:
   - v1.36 serves `v1beta1`. In v1.37, Metrics API reaches GA `v1`.

### B. Custom Resource Definitions (CRDs) with Schema Deprecation (90% of Real-World Deprecations)

In modern enterprise Kubernetes (and CKA/CKS exams), over 90% of pre-upgrade deprecation events originate from **CRDs**
(Cert-Manager, Prometheus Operator, Istio, Flux, Cilium, Rook-Ceph).
Kubernetes OpenAPI v3 allows CRD authors to declare:

```yaml
schema:
  openAPIV3Schema: ...
deprecated: true
deprecationWarning: "drill.cka.io/v1beta1 AppService is deprecated in v1.36; migrate to v1 before v1.37"
```

When a custom resource using `v1beta1` is applied to v1.36:

1. `kubectl apply` **succeeds**.
1. The API server prints the official deprecation warning to the terminal.
1. The API server records an event in Prometheus metric `apiserver_requested_deprecated_apis`.
1. Pluto and live scanners detect the deprecated CR version.

### C. In-Cluster Helm Release Secret Storage (`sh.helm.release.v1...`)

Why do older APIs like `autoscaling/v2beta2` matter if they were removed in earlier releases?
Because **Helm stores historical release manifests inside compressed Secrets**!
If an application was deployed via Helm months ago, its release secret in `kube-system` or `default` still embeds the
original manifest containing `autoscaling/v2beta2`.
When `helm upgrade` or `helm rollback` is executed post-upgrade, Helm decodes the *old* manifest and asks the API server
to diff it. Because the API server dropped that endpoint, Helm crashes with `resource mapping not found`.
Loading synthetic Helm release secrets into the cluster (`simulate-helm-deprecation.sh`) allows `pluto detect-helm` to
detect these latent deprecations **live in-cluster** without `kubectl apply` rejecting the schema.

---

## 3. Two-Tier Lab Structure: Static Scanning vs. Live Cluster Simulation

To eliminate ambiguity, the practice assets are partitioned into two distinct tiers:

```text
/home/vagrant/cka/16-upgrade/00-pre-upgrade-deprecations/
├── README.md                                       # Master guide explaining both tiers
├── test-deprecations-drill.sh                      # Automated test suite validating both tiers
├── static-manifests/                               # TIER 1: Offline static files for Pluto (CI/CD drill)
│   ├── 01-ingress-v1beta1.yaml                     # Historical removed APIs (scanned with pluto detect-files)
│   ├── 02-hpa-v2beta2.yaml
│   ├── 03-cronjob-v1beta1.yaml
│   ├── 04-pdb-v1beta1.yaml
│   └── 05-kubeadm-v1beta3.yaml
├── modern-manifests/                               # Converted equivalents for comparison & validation
│   ├── 01-ingress-v1.yaml
│   ├── 02-hpa-v2.yaml
│   ├── 03-cronjob-v1.yaml
│   ├── 04-pdb-v1.yaml
│   └── 05-kubeadm-v1beta4.yaml
├── live-manifests/                                 # TIER 2: Directly loadable in v1.36 via kubectl apply
│   ├── 01-crd-appservice.yaml                      # CRD defining v1beta1 (deprecated) and v1 (storage)
│   ├── 02-cr-deprecated-v1beta1.yaml               # Custom resource triggering live deprecation warning
│   ├── 03-cr-modern-v1.yaml                        # Migrated custom resource
│   ├── 04-service-externalips.yaml                 # Native Service triggering spec.externalIPs deprecation
│   └── 05-pod-legacy-serviceaccount.yaml           # Native Pod triggering spec.serviceAccount deprecation
└── scripts/
    ├── install-pluto.sh                            # Downloads & verifies Pluto binary
    ├── scan-manifests.sh                           # Audits static manifests with Pluto
    ├── load-live-deprecations.sh                   # NEW: Deploys CRD and loads live deprecated resources
    ├── cleanup-live-deprecations.sh                # NEW: Removes live test resources
    ├── simulate-helm-deprecation.sh                # Injects in-cluster Helm release secret for detect-helm
    ├── scan-cluster.sh                             # Audits live cluster objects, Helm, and apiserver metrics
    └── remediate-manifests.sh                      # Demonstrates migration workflow (kubectl-convert, diff)
```

---

## 4. Live Deprecation Workflow Walkthrough

### Step 1: Deploy and Load Live Deprecated Resources in v1.36

Execute the new loader script:

```bash
cd /home/vagrant/cka/16-upgrade/00-pre-upgrade-deprecations/scripts
./load-live-deprecations.sh
```

This script:

1. Deploys the practice CRD `appservices.drill.cka.io` with `v1beta1` marked `deprecated: true`.
1. Applies `02-cr-deprecated-v1beta1.yaml` $\to$ `kubectl apply` outputs:
   `Warning: drill.cka.io/v1beta1 AppService is deprecated in v1.36; migrate to v1 before v1.37`
1. Applies `04-service-externalips.yaml` $\to$ outputs:
   `Warning: spec.externalIPs is deprecated in v1.36+`
1. Applies `05-pod-legacy-serviceaccount.yaml` $\to$ outputs:
   `Warning: spec.serviceAccount is deprecated in favor of spec.serviceAccountName`
1. Calls `simulate-helm-deprecation.sh create` to populate in-cluster Helm release storage.

### Step 2: Audit Live Cluster via Pluto and Native Metrics

Run the cluster scanner:

```bash
./scan-cluster.sh
```

Output:

1. **Pluto Helm Scan**: `pluto detect-helm --target-versions k8s=v1.37.0` flags the synthetic Helm release secret.
1. **Pluto API Scan**: `pluto detect-api-resources --target-versions k8s=v1.37.0` audits live cluster endpoints.
1. **API Server Metrics**: Queries the raw apiserver metrics endpoint:

   ```bash
   kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis
   ```

   Confirms live deprecation hits recorded by the control plane.

### Step 3: Remediate Live Resources

```bash
# Migrate Custom Resource from v1beta1 to v1
kubectl apply -f ../live-manifests/03-cr-modern-v1.yaml

# Clean up temporary live test resources
./cleanup-live-deprecations.sh
```

---

## 5. Implementation Steps in Ansible Monorepo

### Phase 1: Ansible Tasks & Directory Updates (`tasks/scenario_upgrade_drill.yml`)

1. Add directory creation for:
   - `{{ cka_lab_upgrade_deprecations_dir }}/live-manifests`
   - `{{ cka_lab_upgrade_deprecations_dir }}/static-manifests` (symlinked or renamed from `deprecated-manifests`)
1. Render new templates:
   - `upgrade_00_crd_appservice.yaml.j2` $\to$ `live-manifests/01-crd-appservice.yaml`
   - `upgrade_00_cr_deprecated.yaml.j2` $\to$ `live-manifests/02-cr-deprecated-v1beta1.yaml`
   - `upgrade_00_cr_modern.yaml.j2` $\to$ `live-manifests/03-cr-modern-v1.yaml`
   - `upgrade_00_service_externalips.yaml.j2` $\to$ `live-manifests/04-service-externalips.yaml`
   - `upgrade_00_pod_legacy_sa.yaml.j2` $\to$ `live-manifests/05-pod-legacy-serviceaccount.yaml`
   - `upgrade_00_load_live.sh.j2` $\to$ `scripts/load-live-deprecations.sh`
   - `upgrade_00_cleanup_live.sh.j2` $\to$ `scripts/cleanup-live-deprecations.sh`
1. Update `upgrade_00_scan_cluster.sh.j2` to include `apiserver_requested_deprecated_apis` metric queries.

### Phase 2: Documentation & Test Suite Updates

1. Update `upgrade_00_deprecations_readme.md.j2`:
   - Add Section 1 explaining why historical manifests cannot be applied via `kubectl apply` on v1.36.
   - Detail the Tier 1 (Static files) vs Tier 2 (Live cluster loadable) workflow.
   - Document `apiserver_requested_deprecated_apis` metric inspection.
1. Update `upgrade_00_test_drills.sh.j2`:
   - Add verification for `load-live-deprecations.sh` and `cleanup-live-deprecations.sh`.
   - Validate live CRD deprecation warning emission and cleanup.

### Phase 3: Quality Gates & Linters

1. `shellcheck -s bash` on all scripts.
1. `yamllint -c .yamllint` on all YAML manifests.
1. `check-readme-line-length.py` and `markdownlint-cli2` on markdown files.
1. `ansible-lint` passing with 0 failures / 0 warnings.
1. Update `k8s-homelab/CHANGELOG.md`.

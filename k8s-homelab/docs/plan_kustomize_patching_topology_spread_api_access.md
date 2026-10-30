# Implementation Plan: Kustomize Patching & Directives, Topology Spread, and API Server Access

**Target Scenarios:**

- `k8s-homelab/roles/cka_lab/tasks/scenario_configmaps.yml` (`~/cka/09-kustomize/`)
- `k8s-homelab/roles/cka_lab/tasks/scenario_scheduling.yml` (`~/cka/10-scheduling/`)
- `k8s-homelab/roles/cka_lab/tasks/scenario_rbac.yml` (`~/cka/03-rbac/`)

**Target VM Directories:**

- `/home/vagrant/cka/09-kustomize/` (symlink: `/home/vagrant/cka/kustomize/`)
- `/home/vagrant/cka/10-scheduling/06-topology-spread/`
- `/home/vagrant/cka/03-rbac/03-api-access/`

**Curriculum Domains:** CNCF CKA — Workloads & Scheduling (15%), Cluster Architecture (25%), Troubleshooting (30%)

---

## 1. Objectives & Executive Summary

This plan addresses three architectural and pedagogical gaps in the `k8s-homelab` CKA training suite:

1. **Comprehensive Kustomize Directives & Patching Examples (`09-kustomize/`)**:
   Aligns the Kustomize drill 100% with canonical upstream documentation ([Declarative Management of Kubernetes
   Objects Using Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)).
   Introduces missing resource generators (`secretGenerator` across literals, files, and `.env` files), `images:` image
   tag/digest rewrites, `nameSuffix:`, `commonAnnotations:`, and a complete suite of patching examples covering all
   JSON 6902 verbs (`add`, `replace`, `remove`, array appending `/-`), inline Strategic Merge patches, file-based
   patches under a clean `patches/` directory path, and wildcard labelSelector targeting.
2. **Even Pod Distribution with Topology Spread Constraints (`10-scheduling/06-topology-spread/`)**:
   Provides hands-on drills for `spec.topologySpreadConstraints`, demonstrating `maxSkew`, `topologyKey`, hard
   (`DoNotSchedule`) vs soft (`ScheduleAnyway`) unsatisfiable policies, `labelSelector`, and modern `matchLabelKeys`
   (`pod-template-hash`) across cluster worker nodes.
3. **In-Pod API Server Interrogation & Resource Path Navigation (`03-rbac/03-api-access/`)**:
   Provides an end-to-end hands-on drill based on canonical documentation
   ([Accessing the Kubernetes API from a Pod](https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/)).
   Teaches in-pod credential discovery (`token`, `ca.crt`, `namespace`), REST URI hierarchy navigation (`/api/v1` vs
   `/apis/<group>/<version>`), namespaced Secret discovery (`/api/v1/namespaces/{ns}/secrets/{name}`), payload base64
   extraction, RBAC 403 Forbidden verification, and host exploration via `kubectl proxy`.

> [!IMPORTANT]
> **Documentation & Attribution Policy**:
> All generated artifacts (READMEs, templates, manifests, test scripts, and CHANGELOG entries) must strictly reference
> canonical official Kubernetes documentation (`kubernetes.io/docs/`) and official CNCF CKA exam objectives. Never
> cite proprietary course names, books, or third-party training authors.

---

## 2. Curriculum & Documentation Alignment

### A. Official Kubernetes Documentation References

- **Kustomize Declarative Management**:
  - `https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/` `[EXAM ALLOWED]`
  - `https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patches/` `[EXAM ALLOWED]`
- **Pod Topology Spread Constraints**:
  - `https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/` `[EXAM ALLOWED]`
- **In-Pod API Access & REST Hierarchy**:
  - `https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/` `[EXAM ALLOWED]`
  - `https://kubernetes.io/docs/reference/using-api/api-concepts/` `[EXAM ALLOWED]`

### B. In-Exam Search Keywords & CLI Fast Paths

```bash
# In-exam search keywords:
# "declarative management using kustomize", "topology spread constraints", "access api from a pod"

# Fast terminal lookups:
kubectl explain pod.spec.topologySpreadConstraints
kubectl explain pod.spec.topologySpreadConstraints.matchLabelKeys
kubectl kustomize --help
kubectl proxy --help
```

---

## 3. Detailed Component Specifications

### Component 1: Kustomize Patching & Complete Directives (`09-kustomize/`)

#### A. Directory Layout on Control Plane

```text
/home/vagrant/cka/09-kustomize/
├── README.md                                  # Master guide explaining all options & directives
├── test-kustomize.sh                          # Non-interactive automated test validation harness
├── base/
│   ├── kustomization.yaml                     # Declares base resources: deployment, service, configmap
│   ├── deployment.yaml                        # Base workload referencing webapp-config and webapp-secret
│   ├── service.yaml                           # Base ClusterIP service
│   └── configmap.yaml                         # Baseline app configuration
└── overlays/
    ├── development/
    │   ├── kustomization.yaml                 # Dev overlay: prefix, annotations, dev generators, JSON patches
    │   ├── dev-settings.properties            # File source for configMapGenerator
    │   ├── dev-app.env                        # Key=value env-file source for configMapGenerator
    │   ├── dev-secrets.env                    # Sensitive env-file source for secretGenerator
    │   └── patches/
    │       ├── patch-memory-replace.yaml      # JSON 6902 replace: memory request to 32Mi
    │       └── patch-remove-probe.yaml        # JSON 6902 remove: strips liveness probe for dev
    └── production/
        ├── kustomization.yaml                 # Prod overlay: suffix, images transformer, strategic merge
        ├── prod-secrets.env                   # Sensitive env-file source for secretGenerator
        └── patches/
            ├── patch-replicas-ha.yaml         # Strategic merge patch: scale replicas to 3 & limits
            ├── patch-sidecar-add.yaml         # JSON 6902 add: appends log-shipper sidecar container (/-)
            ├── patch-env-add.yaml             # JSON 6902 add: appends DB_TIMEOUT env variable (/-)
            └── patch-security-context.yaml    # Wildcard patch targeting Deployments via labelSelector
```

#### B. Covered Kustomize Options & Explanations in `README.md`

The master `README.md` will include an in-depth reference table and narrative explanations covering:

1. **`secretGenerator:`**
   - Generating `Opaque` and typed Secrets (`type: kubernetes.io/basic-auth`) without storing base64 raw secrets in git.
   - Sources: `literals: [KEY=value]`, `files: [cert.pem]`, and `envs: [credentials.env]`.
2. **`configMapGenerator:` with `envs:`**
   - Generating ConfigMaps from multi-line `.env` files without manually repeating key names.
   - Behavior options: `behavior: create` (default), `behavior: replace`, and `behavior: merge`.
3. **`images:` Transformer**
   - Dynamically customizing container images across overlays without writing patch manifests:
     - `name`: identifies the image defined in the base (`nginx`).
     - `newName`: overrides image repository (`cgr.dev/chainguard/nginx`).
     - `newTag`: updates tag (`1.25.4-alpine`).
     - `digest`: pins immutable SHA256 digest (`sha256:45b23dee...`).
4. **`namePrefix:` and `nameSuffix:`**
   - Prepending (`dev-`) or appending (`-v1`) to all generated resource names to avoid collisions.
5. **`commonAnnotations:` and `labels:`**
   - Cross-cutting metadata injection: `commonAnnotations` for metadata tracking and `labels` with
     `includeSelectors: true` (Kustomize v5) for synchronizing pod template labels and deployment selectors.
6. **`generatorOptions:`**
   - `disableNameSuffixHash: true` to prevent unpredictable hashed names (`webapp-config-4k58m279b9`) when static
     names are required by downstream tools.
7. **Comprehensive Patching Taxonomy**:
   - **JSON 6902 `op: replace`**: Direct modification of scalar or nested values by JSON pointer
     (`/spec/template/spec/containers/0/resources/requests/memory`).
   - **JSON 6902 `op: add` with `/-`**: Appending elements to arrays without indexing
     (`/spec/template/spec/containers/-` for sidecars, `/env/-` for environment variables).
   - **JSON 6902 `op: remove`**: Stripping unnecessary or incompatible fields
     (`/spec/template/spec/containers/0/livenessProbe`).
   - **Inline Strategic Merge**: Defining lightweight partial YAML specs directly inside `kustomization.yaml` under
     `patches: - patch: |- ...`.
   - **File-based Strategic Merge**: Referencing standalone patch manifests via `patches: - path: patches/...`.
   - **LabelSelector Target Filtering**: Targeting resources by labels (`target: { kind: Deployment, labelSelector:
     "app.kubernetes.io/name=webapp" }`) rather than hardcoding names.

---

### Component 2: Topology Spread Constraints Drill (`10-scheduling/06-topology-spread/`)

#### A. Directory Layout on Control Plane

```text
/home/vagrant/cka/10-scheduling/
├── ...                                        # Existing 01 through 05 drills
└── 06-topology-spread/
    ├── README.md                              # In-depth guide: skew math, topology domains & rolling updates
    ├── test-topology-spread.sh                # Automated test runner testing skew across worker nodes
    ├── topology-spread-hard.yaml              # Deployment with DoNotSchedule (strict balance)
    ├── topology-spread-soft.yaml              # Deployment with ScheduleAnyway (best effort)
    └── topology-spread-rolling.yaml           # Deployment with matchLabelKeys (pod-template-hash)
```

#### B. Covered Topology Spread Concepts & Explanations in `README.md`

1. **The Skew Formula**:
   $$\text{Skew} = \text{Count}(\text{Target Topology}) - \text{Min}(\text{Count across all topologies})$$
   - `maxSkew: 1` mandates that no two topology domains (e.g. `kubernetes.io/hostname`) differ by more than 1 pod.
2. **Topology Keys**:
   - Node-level spreading: `topologyKey: kubernetes.io/hostname`.
   - Zone-level spreading: `topologyKey: topology.kubernetes.io/zone`.
3. **Unsatisfiable Policies**:
   - `whenUnsatisfiable: DoNotSchedule`: Hard constraint. If scheduling a pod exceeds `maxSkew`, the pod remains
     `Pending`.
   - `whenUnsatisfiable: ScheduleAnyway`: Soft constraint. Scheduler prioritizes reducing skew, but schedules the pod
     if no compliant node exists.
4. **Label Selectors & `matchLabelKeys`**:
   - `labelSelector`: Matches pods contributing to the skew calculation.
   - `matchLabelKeys: ["pod-template-hash"]`: Crucial for rolling deployments; evaluates newly created pods separately
     from old pods being terminated to prevent deadlocks and unnecessary skew calculation stalls.
5. **Interactive Lab Exercise**:
   - Deploy 4 replicas across 2 worker nodes (`kube-worker-1` and `kube-worker-2`), verifying a 2-2 balance.
   - Cordon `kube-worker-2` (`kubectl cordon kube-worker-2`) and scale deployment to 5 replicas.
   - Observe that with `DoNotSchedule`, the 5th pod stays `Pending` (violates `maxSkew: 1`).
   - Contrast with `ScheduleAnyway`, where the 5th pod schedules successfully on `kube-worker-1`.

---

### Component 3: In-Pod API Server Interrogation & Resource Navigation (`03-rbac/03-api-access/`)

#### A. Directory Layout on Control Plane

```text
/home/vagrant/cka/03-rbac/
├── ...                                        # Existing create-user-context, manual-user, serviceaccounts
└── 03-api-access/
    ├── README.md                              # Master guide: credential discovery & REST path hierarchy
    ├── test-api-access.sh                     # Automated test validating in-pod API queries & RBAC barriers
    ├── exec-inspector.sh                      # Helper script dropping into an interactive in-pod curl shell
    ├── api-reader-rbac.yaml                   # Namespace, ServiceAccount, Role, RoleBinding for API access
    ├── sample-secrets.yaml                    # Seed sensitive Secret (db-credentials) in test namespace
    └── api-inspector-pod.yaml                 # Pod mounting ServiceAccount with curl/jq tooling
```

#### B. Covered API Interrogation Concepts & Explanations in `README.md`

1. **In-Pod ServiceAccount Projection**:
   - Default mount location: `/var/run/secrets/kubernetes.io/serviceaccount/`.
   - Three core projected files:
     - `token`: Bound JWT bearer token for the assigned ServiceAccount.
     - `ca.crt`: In-cluster certificate authority bundle validating the API server TLS certificate.
     - `namespace`: Current namespace string where the pod runs.
   - Internal API Server endpoint: `https://kubernetes.default.svc` (or `https://kubernetes.default.svc.cluster.local`).
2. **REST URI Hierarchy & Path Navigation**:
   - **API Group Discovery**:
     - Core API (`/api/v1`): Pods, Services, Namespaces, Nodes, ConfigMaps, Secrets, PersistentVolumes.
     - Named Groups (`/apis/<group>/<version>`): Deployments (`/apis/apps/v1`), CronJobs (`/apis/batch/v1`),
       NetworkPolicies (`/apis/networking.k8s.io/v1`).
   - **Namespaced Resource Navigation**:
     - List secrets: `GET /api/v1/namespaces/{namespace}/secrets`
     - Read single secret: `GET /api/v1/namespaces/{namespace}/secrets/{name}`
     - List configmaps: `GET /api/v1/namespaces/{namespace}/configmaps`
     - List pods: `GET /api/v1/namespaces/{namespace}/pods`
     - List deployments: `GET /apis/apps/v1/namespaces/{namespace}/deployments`
   - **Cluster-Scoped Resource Navigation**:
     - List nodes: `GET /api/v1/nodes`
     - List namespaces: `GET /api/v1/namespaces`
3. **Secret Payload Extraction & Base64 Decoding**:
   - Parsing the JSON payload returned by `/api/v1/namespaces/{namespace}/secrets/{name}`:

     ```bash
     curl -s --cacert ${CACERT} -H "Authorization: Bearer ${TOKEN}" \
       "${APISERVER}/api/v1/namespaces/${NAMESPACE}/secrets/db-credentials" | \
       jq -r '.data.password' | base64 -d
     ```

4. **RBAC Authorization Boundaries & Error Inspection**:
   - Querying unauthorized paths (e.g., `GET /api/v1/namespaces/kube-system/secrets`) returns `403 Forbidden` with a
     structured JSON error message explaining the missing RBAC rule.
5. **Workstation Fast Path via `kubectl proxy`**:
   - Demonstrates creating an authenticated HTTP proxy from the workstation:

     ```bash
     kubectl proxy --port=8001 &
     curl -s http://localhost:8001/api/v1/namespaces/default/secrets
     ```

   - Teaches the direct 1:1 parity between `kubectl proxy` URLs and in-pod `https://kubernetes.default.svc` paths.

---

## 4. Implementation Steps & Tasks

### Step 1: Update Ansible Role `cka_lab` Templates & Tasks

1. **Kustomize (`roles/cka_lab/tasks/scenario_configmaps.yml`)**:
   - Render `kustomize_base_kustomization.yaml.j2`, `kustomize_base_deployment.yaml.j2`.
   - Render `overlays/development/`: `kustomize_overlay_dev_kustomization.yaml.j2`, `dev-app.env.j2`,
     `dev-secrets.env.j2`, `patch-memory-replace.yaml.j2`, `patch-remove-probe.yaml.j2`.
   - Render `overlays/production/`: `kustomize_overlay_prod_kustomization.yaml.j2`, `prod-secrets.env.j2`,
     `patch-replicas-ha.yaml.j2`, `patch-sidecar-add.yaml.j2`, `patch-env-add.yaml.j2`,
     `patch-security-context.yaml.j2`.
   - Render updated `kustomize_readme.md.j2` with exhaustive options guide.
   - Render `kustomize_test_drills.sh.j2` executable at `~/cka/09-kustomize/test-kustomize.sh`.
2. **Topology Spread (`roles/cka_lab/tasks/scenario_scheduling.yml`)**:
   - Create directory `{{ cka_lab_scheduling_dir }}/06-topology-spread`.
   - Render `scheduling_06_topology_spread_hard.yaml.j2`, `scheduling_06_topology_spread_soft.yaml.j2`,
     `scheduling_06_topology_spread_rolling.yaml.j2`.
   - Render `scheduling_06_guide.md.j2` with glow formatting and skew explanations.
   - Render `scheduling_06_test_topology_spread.sh.j2` executable at `test-topology-spread.sh`.
   - Update `scheduling_readme.md.j2` and `scheduling_test_drills.sh.j2`.
3. **In-Pod API Access (`roles/cka_lab/tasks/scenario_rbac.yml`)**:
   - Create directory `{{ cka_lab_rbac_dir }}/03-api-access`.
   - Render `rbac_api_reader_rbac.yaml.j2`, `rbac_api_sample_secrets.yaml.j2`, `rbac_api_inspector_pod.yaml.j2`.
   - Render `rbac_api_access_guide.md.j2` detailing credential extraction and URI endpoints.
   - Render `rbac_api_exec_inspector.sh.j2` and `rbac_test_api_access.sh.j2`.
   - Update `rbac_readme.md.j2` and `rbac_test_drills.sh.j2`.

### Step 2: Quality Gates & Linting Verification

- Run `yamllint -c .yamllint` on all newly added tasks and manifests.
- Run `shellcheck -s bash` on all newly added test and helper scripts.
- Run `markdownlint-cli2` on all newly added guide and readme templates.
- Run `python3 scripts/check-readme-line-length.py` to enforce `<= 120` character wrapping across all markdown prose.

### Step 3: CHANGELOG.md & Documentation Update

- Add high-level summaries under `## [Unreleased]` in `k8s-homelab/CHANGELOG.md` following project standards.
- Update `roles/cka_lab/README.md` and `templates/cka_master_readme.md.j2`.

# Implementation Plan: ConfigMaps, Secrets & Pod Consumption Drills for CKA Lab

**Target Scenario:** `k8s-homelab/roles/cka_lab/tasks/scenario_configmaps.yml`  
**Target VM Directory:** `/home/vagrant/cka/configmaps/`  
**Curriculum Domain:** CNCF CKA — Workloads & Scheduling (15%), Storage (10%)  

---

## 1. Objectives & Executive Summary

Currently, `roles/cka_lab/tasks/scenario_configmaps.yml` renders sample ConfigMap manifests (`default/`, `development/`, `sample-configmaps.yaml`) and Kustomize overlays, but lacks:

1. A master pedagogical **`README.md`** guiding trainees through CKA exam objectives, speed habits, and allowed documentation.
2. Step-by-step **imperative generation drills** (`kubectl create configmap` variants: literals, files, env files).
3. **Pod workload consumption manifests** directly demonstrating the canonical consumption patterns:
   - Single environment variable binding (`valueFrom.configMapKeyRef` / `valueFrom.secretKeyRef`).
   - Bulk environment variable binding (`envFrom.configMapRef` / `envFrom.secretRef` with prefix).
   - Full volume directory mount (`volumes[].configMap` / `secret`).
   - Granular single file projection via `volumeMounts[].subPath`.
4. **Immutability and update drills** (`immutable: true`, API server rejection, dynamic kubelet volume update vs static env vars).
5. An automated **verification test suite** (`test-configmaps-drills.sh`) conforming to the repository standard.

This plan integrates and cross-references existing repo exercises (`cka/secrets/`, `cka/volumes/`, `cka/kustomize/`) into a cohesive **Configuration Primitives** chapter.

> [!IMPORTANT]
> **Copyright & Attribution Policy**:
> All generated artifacts (READMEs, templates, manifests, test scripts, and CHANGELOG entries) must strictly reference only canonical official Kubernetes documentation (`kubernetes.io/docs/`) and official CNCF CKA exam objectives. Never cite proprietary course names, books, or third-party training authors.

---

## 2. Curriculum & Documentation Alignment

### A. CNCF CKA Exam Competencies

- **Decoupled Configuration**: Managing application parameters and sensitive data independently of container images.
- **Consumption Mechanisms**: Injecting configuration data into container runtimes via environment variables and volume mounts.
- **Immutability**: Declaring immutable configuration to protect against accidental drift and lessen cluster control plane watch overhead.
- **Declarative Configuration**: Generating configuration dynamically using Kustomize `configMapGenerator`.

### B. Permitted Official Exam Documentation (`kubernetes.io/docs/`)

- Concepts:
  - `https://kubernetes.io/docs/concepts/configuration/configmap/`
  - `https://kubernetes.io/docs/concepts/configuration/secret/`
- Tasks:
  - `https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/`
  - `https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-secret/`
  - `https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/`
- Reference & Cheat Sheet:
  - `https://kubernetes.io/docs/reference/kubectl/cheatsheet/#creating-objects`
- Terminal `kubectl explain` fast paths:

  ```bash
  kubectl explain pod.spec.containers.env.valueFrom.configMapKeyRef
  kubectl explain pod.spec.containers.envFrom.configMapRef
  kubectl explain pod.spec.volumes.configMap
  kubectl explain pod.spec.containers.volumeMounts.subPath
  ```

---

## 3. Proposed Directory Structure on Control Plane (`/home/vagrant/cka/configmaps/`)

```text
/home/vagrant/cka/configmaps/
├── README.md                                  # Master CKA guide, references & drill instructions
├── test-configmaps-drills.sh                  # Automated end-to-end verification script
├── sample-configmaps.yaml                     # Pre-rendered baseline manifest
├── default/                                   # Standalone manifests (default namespace)
│   ├── sample-app-config.yaml
│   ├── sample-service-config.yaml
│   └── sample-system-config.yaml
├── development/                               # Standalone manifests (dev namespace)
│   ├── dev-app-config.yaml
│   ├── dev-service-config.yaml
│   └── dev-system-config.yaml
├── 01-imperative-creation/
│   ├── run-imperative.sh                      # Executable drill: literals, files, env files
│   ├── app.properties                         # Multi-line properties source file
│   └── ui.conf                                # Custom config source file
├── 02-env-var-injection/
│   ├── 01-single-env-pod.yaml                 # valueFrom: configMapKeyRef & secretKeyRef
│   └── 02-bulk-envfrom-pod.yaml               # envFrom: configMapRef (prefix) & secretRef
├── 03-volume-mounts-subpath/
│   ├── 01-volume-directory-pod.yaml           # Full directory mount (overwrites dir)
│   └── 02-subpath-single-file-pod.yaml        # subPath mount (preserves existing directory)
├── 04-immutability-drill/
│   ├── immutable-configmap.yaml               # immutable: true ConfigMap definition
│   └── test-immutability.sh                   # Script attempting mutation & verifying API rejection
└── 05-cross-references.md                     # Links to /home/vagrant/cka/secrets & /home/vagrant/cka/kustomize
```

---

## 4. Detailed Drill Walkthrough & Synergy with Existing Repo Assets

### Drill 1: Rapid Imperative Creation (`01-imperative-creation/`)

- Creating ConfigMaps from literals:
  `kubectl create configmap game-config --from-literal=lives=3 --from-literal=difficulty=hard`
- Creating ConfigMaps from single and renamed files:
  `kubectl create configmap app-props --from-file=app.properties --from-file=custom-ui=ui.conf`
- Creating ConfigMaps from env files:
  `kubectl create configmap env-config --from-env-file=app.env`
- Corresponding Secret creation comparisons (`kubectl create secret generic ...`).

### Drill 2: Granular vs. Bulk Environment Variable Injection (`02-env-var-injection/`)

- **Pod 1 (`01-single-env-pod.yaml`)**:
  - Injects `APP_ENV` from `sample-app-config`.
  - Injects `DATABASE_URL` from Secret `sample-app-secret` (`/home/vagrant/cka/secrets`).
  - Verifies key-level granular injection.
- **Pod 2 (`02-bulk-envfrom-pod.yaml`)**:
  - Uses `envFrom` with `prefix: "CFG_"` for `sample-app-config`.
  - Uses `envFrom` for `sample-app-secret`.
  - Contrasts prefix isolation vs direct key injection.

### Drill 3: Volume Mounts & `subPath` Projections (`03-volume-mounts-subpath/`)

- **Pod 1 (`01-volume-directory-pod.yaml`)**:
  - Mounts ConfigMap `sample-service-config` to `/etc/sample-config`.
  - Validates file creation for `application.properties` and `nginx.conf`.
- **Pod 2 (`02-subpath-single-file-pod.yaml`)**:
  - Uses `nginx:alpine` image.
  - Injects `nginx.conf` directly to `/etc/nginx/conf.d/default.conf` via `subPath: nginx.conf`.
  - Validates that other files in `/etc/nginx/conf.d/` are preserved.
  - References `volumes_04_configmap_volume_pod.yaml` and `volumes_04_secret_volume_pod.yaml` from `cka/volumes/`.

### Drill 4: Spec Immutability & Live Update Semantics (`04-immutability-drill/`)

- Demonstrates `immutable: true` on `sample-system-config`.
- Runs `test-immutability.sh`:
  - Attempts `kubectl patch` or `kubectl apply` with a modified key.
  - Captures `Invalid value ... field is immutable` rejection error.
  - Contrasts dynamic kubelet volume sync behavior against static container environment variables.

### Drill 5: Kustomize Integration & GitOps Parity

- References `/home/vagrant/cka/kustomize/` (`base/`, `overlays/development/`).
- Reviews `configMapGenerator` with `files:` and `literals:`, demonstrating hash suffixing (`dev-configmap-2g97b9576m`).

---

## 5. Implementation Steps in Ansible Monorepo

1. **Jinja2 Templates Creation (`roles/cka_lab/templates/`)**:
   - `configmaps_readme.md.j2`
   - `configmaps_01_run_imperative.sh.j2`
   - `configmaps_01_app.properties.j2`
   - `configmaps_01_ui.conf.j2`
   - `configmaps_02_single_env_pod.yaml.j2`
   - `configmaps_02_bulk_envfrom_pod.yaml.j2`
   - `configmaps_03_volume_dir_pod.yaml.j2`
   - `configmaps_03_subpath_pod.yaml.j2`
   - `configmaps_04_immutable_cm.yaml.j2`
   - `configmaps_04_test_immutability.sh.j2`
   - `configmaps_test_drills.sh.j2`

2. **Ansible Task Updates (`roles/cka_lab/tasks/scenario_configmaps.yml`)**:
   - Create drill subdirectories under `cka_lab_configmaps_dir`.
   - Render all templates with mode `0644` (and `0755` for shell scripts).
   - Ensure clean execution in both `default` and `development` namespaces.

3. **Variables & Defaults (`roles/cka_lab/defaults/main.yml`)**:
   - Add drill directory configuration variables if needed.

4. **Quality Gates & Linters**:
   - `shellcheck -s bash` on all `.sh.j2` scripts.
   - `yamllint -c .yamllint` on all YAML manifests and tasks.
   - `nix shell nixpkgs#markdownlint-cli2 --command markdownlint-cli2` on markdown templates.
   - `nix shell nixpkgs#ansible-lint` passing with 0 failures/warnings.

5. **Changelog**:
   - Add concise entry under `## [Unreleased]` in `k8s-homelab/CHANGELOG.md` focusing strictly on features and scenario additions without citing copyrighted training courses.

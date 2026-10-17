# Implementation Plan: Secrets & Workload Consumption Drills for CKA Lab

**Target Scenario:** `k8s-homelab/roles/cka_lab/tasks/scenario_secrets.yml`  
**Target VM Directory:** `/home/vagrant/cka/secrets/`  
**Curriculum Domain:** CNCF CKA — Workloads & Scheduling (15%), Storage (10%)  

---

## 1. Objectives & Executive Summary

Currently, `roles/cka_lab/tasks/scenario_secrets.yml` generates self-signed TLS certificates and SSH keys using OpenSSL and ssh-keygen, renders `sample-secrets.yaml` across `default` and `development` namespaces (`Opaque`, `basic-auth`, `tls`, `ssh-auth`), and applies them to the cluster. However, the scenario lacks:

1. A master pedagogical **`README.md`** guiding trainees through CKA exam competencies, security best practices, and allowed documentation.
2. Step-by-step **imperative generation drills** (`kubectl create secret generic`, `tls`, `docker-registry`).
3. Hands-on **Base64 inspection & payload decoding** techniques under timed exam conditions (`base64 -d`, JSONPath extraction).
4. **Pod workload consumption manifests** demonstrating:
   - Granular secret key binding (`valueFrom.secretKeyRef`).
   - Bulk secret binding (`envFrom.secretRef` with collision-prevention prefixes).
   - Restrictive volume mounting (`volumes[].secret` with octal/decimal `defaultMode: 0400` / `256`).
   - TLS Secret mounting for HTTPS web termination (e.g. NGINX).
5. **Secret immutability enforcement** (`immutable: true`, API server rejection, etcd watch reduction).
6. An automated **verification test suite** (`test-secrets-drills.sh`) conforming to the repository standard.

> [!IMPORTANT]
> **Copyright & Attribution Policy**:
> All generated artifacts (READMEs, templates, manifests, test scripts, and CHANGELOG entries) must strictly reference only canonical official Kubernetes documentation (`kubernetes.io/docs/`) and official CNCF CKA exam objectives. Never cite proprietary course names, books, or third-party training authors.

---

## 2. Curriculum & Documentation Alignment

### A. CNCF CKA Exam Competencies

- **Confidential Data Management**: Managing sensitive credentials (API tokens, passwords, TLS certificates, container registry credentials) independently of workload specifications.
- **Secret Types**: Understanding built-in Secret types (`Opaque`, `kubernetes.io/tls`, `kubernetes.io/basic-auth`, `kubernetes.io/dockerconfigjson`, `kubernetes.io/ssh-auth`).
- **Encoding vs. Encryption**: Differentiating Base64 transport encoding from at-rest encryption in etcd.
- **Consumption Mechanisms**: Injecting secrets into container processes via environment variables or mounting as secure in-memory filesystem volumes (`tmpfs`).
- **Least-Privilege File Permissions**: Restricting secret file permissions inside containers (`defaultMode: 0400`).
- **Specification Immutability**: Protecting sensitive credentials against unauthorized or accidental mutation.

### B. Permitted Official Exam Documentation (`kubernetes.io/docs/`)

- Concepts:
  - `https://kubernetes.io/docs/concepts/configuration/secret/`
- Tasks:
  - `https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-secret/`
  - `https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/`
  - `https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/`
- Reference & Cheat Sheet:
  - `https://kubernetes.io/docs/reference/kubectl/cheatsheet/#creating-objects`
- Terminal `kubectl explain` fast paths:

  ```bash
  kubectl explain secret.type
  kubectl explain secret.data
  kubectl explain secret.stringData
  kubectl explain pod.spec.containers.env.valueFrom.secretKeyRef
  kubectl explain pod.spec.containers.envFrom.secretRef
  kubectl explain pod.spec.volumes.secret
  kubectl explain pod.spec.volumes.secret.defaultMode
  ```

---

## 3. Proposed Directory Structure on Control Plane (`/home/vagrant/cka/secrets/`)

```text
/home/vagrant/cka/secrets/
├── README.md                                  # Master CKA guide, references & drill instructions
├── test-secrets-drills.sh                     # Automated end-to-end verification script
├── sample-secrets.yaml                        # Pre-rendered baseline manifests (all types)
├── sample-tls.crt / sample-tls.key            # Pre-generated default TLS credentials
├── sample-ssh.key / sample-ssh.key.pub        # Pre-generated default SSH credentials
├── dev-tls.crt / dev-tls.key                  # Pre-generated dev TLS credentials
├── dev-ssh.key / dev-ssh.key.pub              # Pre-generated dev SSH credentials
├── 01-imperative-creation/
│   ├── run-imperative.sh                      # Executable drill: generic, tls, docker-registry
│   ├── db-creds.txt                           # Key-value secret source file
│   └── certs/                                 # Ephemeral drill certificate and key
├── 02-decode-inspection/
│   └── decode-secrets.sh                      # Base64 decoding & JSONPath extraction drill
├── 03-env-var-injection/
│   ├── 01-single-secret-env-pod.yaml          # Granular valueFrom.secretKeyRef injection
│   └── 02-bulk-secret-envfrom-pod.yaml        # Bulk envFrom.secretRef injection with prefix
├── 04-volume-mounts-tls/
│   ├── 01-secure-volume-pod.yaml              # Volume mount with restrictive mode (0400)
│   ├── 02-nginx-tls-pod.yaml                  # HTTPS termination pod mounting TLS Secret
│   └── nginx-tls.conf                         # NGINX SSL virtual host configuration
└── 05-immutability-drill/
    ├── immutable-secret.yaml                  # immutable: true Secret manifest
    └── test-immutability.sh                   # Script verifying API server update rejection
```

---

## 4. Detailed Drill Walkthrough & Synergy with Existing Repo Assets

### Drill 1: Rapid Imperative Creation (`01-imperative-creation/`)

Creating Secrets imperatively using `kubectl create secret`:

1. **Generic Secret from literals and files**:

   ```bash
   kubectl create secret generic app-db-auth \
     --from-literal=username=dbadmin \
     --from-literal=password='VerySecurePassword2026!' \
     --from-file=credentials=db-creds.txt \
     --dry-run=client -o yaml
   ```

2. **TLS Secret (`kubernetes.io/tls`)**:

   ```bash
   kubectl create secret tls web-tls-secret \
     --cert=sample-tls.crt \
     --key=sample-tls.key \
     --dry-run=client -o yaml
   ```

3. **Container Registry Secret (`kubernetes.io/dockerconfigjson`)**:

   ```bash
   kubectl create secret docker-registry regcred \
     --docker-server=registry.internal.lan:5000 \
     --docker-username=builduser \
     --docker-password='DockerToken#987' \
     --docker-email=build@cluster.local \
     --dry-run=client -o yaml
   ```

### Drill 2: Base64 Payload Inspection & Fast Decoding (`02-decode-inspection/`)

Under timed exam conditions, candidates must quickly extract and verify credentials stored in secrets without manual base64 copy-pasting:

1. **Single key decoding via JSONPath**:

   ```bash
   kubectl get secret sample-app-secret -n default \
     -o jsonpath='{.data.password}' | base64 -d
   ```

2. **Decoding all keys in one command via Go template**:

   ```bash
   kubectl get secret sample-app-secret -n default \
     -o go-template='{{range $k,$v := .data}}{{$k}}: {{$v | base64decode}}{{"\n"}}{{end}}'
   ```

3. **Contrasting `data` (Base64-encoded) vs `stringData` (write-only plain text)**:
   Demonstrating how `stringData` allows writing plain text in manifests while the API server automatically encodes it into `data` upon storage.

### Drill 3: Granular vs. Bulk Environment Variable Injection (`03-env-var-injection/`)

- **Pod 1 (`01-single-secret-env-pod.yaml`)**:
  - Injects `username` and `password` from `sample-app-secret` into `DB_USER` and `DB_PASS`.
  - Verifies key-level granular binding with `valueFrom.secretKeyRef`.
- **Pod 2 (`02-bulk-secret-envfrom-pod.yaml`)**:
  - Uses `envFrom` with `prefix: "SEC_"` for `sample-app-secret`.
  - Shows that all keys (`SEC_username`, `SEC_password`, `SEC_database-url`, `SEC_api-key`) are injected into the environment.

### Drill 4: Secure Volume Mounts & TLS Web Termination (`04-volume-mounts-tls/`)

1. **Restrictive POSIX Permissions (`defaultMode: 0400`)**:
   - In Kubernetes manifests, `defaultMode` for volumes is written in decimal or octal notation: `256` (decimal) = `0400` (read-only for owner).
   - Validating inside container that secret files are `r--------` (`0400`), preventing access by unauthorized non-root container users.
2. **TLS Ingress / Web Server Termination (`02-nginx-tls-pod.yaml`)**:
   - Mounts `sample-tls-secret` to `/etc/nginx/certs` (`tls.crt` and `tls.key`).
   - Runs NGINX with SSL termination listening on port 443.
   - Probes the HTTPS endpoint with `curl -k https://127.0.0.1:443` inside an ephemeral container to confirm working TLS handshake.
3. **Cross-Reference with Storage Volumes (`cka/volumes/`)**:
   - Bridges `volumes_04_secret_volume_pod.yaml` and `volumes_07_iscsi_05_chap_secret.yaml`.

### Drill 5: Specification Immutability (`05-immutability-drill/`)

- Configures `immutable: true` on `immutable-secret.yaml`.
- Runs `test-immutability.sh` attempting to modify credentials via `kubectl patch`.
- Captures and asserts the API server rejection error (`field is immutable`).
- Emphasizes the security advantage: prevents running pods from silently having credentials rotated without controlled deployment rollouts.

---

## 5. Implementation Steps in Ansible Monorepo

1. **Jinja2 Templates Creation (`roles/cka_lab/templates/`)**:
   - `secrets_readme.md.j2`
   - `secrets_01_run_imperative.sh.j2`
   - `secrets_01_db_creds.txt.j2`
   - `secrets_02_decode_secrets.sh.j2`
   - `secrets_03_single_env_pod.yaml.j2`
   - `secrets_03_bulk_envfrom_pod.yaml.j2`
   - `secrets_04_secure_volume_pod.yaml.j2`
   - `secrets_04_nginx_tls_pod.yaml.j2`
   - `secrets_04_nginx_tls.conf.j2`
   - `secrets_05_immutable_secret.yaml.j2`
   - `secrets_05_test_immutability.sh.j2`
   - `secrets_test_drills.sh.j2`

2. **Ansible Task Updates (`roles/cka_lab/tasks/scenario_secrets.yml`)**:
   - Create drill subdirectories under `cka_lab_secrets_dir`.
   - Render all templates with mode `0644` (and `0755` for shell scripts).
   - Maintain existing TLS/SSH certificate generation and `sample-secrets.yaml` application.

3. **Variables & Defaults (`roles/cka_lab/defaults/main.yml`)**:
   - Keep current secret defaults, adding any necessary drill parameters.

4. **Quality Gates & Linters**:
   - `shellcheck -s bash` on all `.sh.j2` scripts.
   - `yamllint -c .yamllint` on all YAML manifests and tasks.
   - `nix shell nixpkgs#markdownlint-cli2 --command markdownlint-cli2` on markdown templates and docs.
   - `nix shell nixpkgs#ansible-lint` passing with 0 failures/warnings.

5. **Changelog**:
   - Add concise entry under `## [Unreleased]` in `k8s-homelab/CHANGELOG.md` following standard format.

---

## Trainee Feedback & Comments Section
<!-- Trainees / reviewers may add comments or adjustments below -->

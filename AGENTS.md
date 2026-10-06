# AGENTS.md

Context, architecture, workflows, and operational standards for AI coding agents operating on the `os76-ansible` repository.

---

## 1. Repository Identity & Scope

`os76-ansible` is a private infrastructure-as-code monorepo containing Ansible automation playbooks, roles, and lab environments for the OS76 infrastructure.

### Repository Layout

- **`k8s-homelab/`** — Primary active project: automated multi-node Kubernetes (`kubeadm`) cluster provisioning on Libvirt/KVM via Vagrant, CKA practice labs, rolling upgrades, and cluster maintenance.
- **`os76_priv_lan_mgmt/`** — LAN network infrastructure automation (gateway routers, hostapd access points, dnsmasq/unbound DNS resolvers, node exporter metrics, and Let's Encrypt certificates).
- **`os76_priv_ca/`** — Private Certificate Authority (PKI) management playbooks.
- **`os76_k3s/` & `archived/`** — Historical and legacy K3s homelab playbooks and Helm charts.
- **`docs/` & `Docs.md`** — Reference documentation, Ansible filter guides, and upstream bookmarks.

---

## 2. `k8s-homelab` Architecture

Multi-node Kubernetes 1.34+ cluster automated using `kubeadm`, `containerd`, and Cilium CNI on Libvirt/KVM.

### VM Topology & Inventory

| Node Name | IP Address | Roles | vCPU | RAM | Base Image |
| --- | --- | --- | --- | --- | --- |
| `kube-control-plane` | `192.168.56.20` | Control Plane, API server, etcd | 2 | 4096 MB | Ubuntu 26.04 |
| `kube-worker-1` | `192.168.56.21` | Worker Node | 2 | 2048 MB | Ubuntu 26.04 |
| `kube-worker-2` | `192.168.56.22` | Worker Node | 2 | 2048 MB | Ubuntu 26.04 |

- **Inventories**: `inventory/preprod/hosts.ini` (local Vagrant VMs) and `inventory/prod/hosts.ini` (bare metal / production nodes).
- **Group Variables**: Global settings in `group_vars/all.yml` (`k8s_version: 1.34.1-1.1`, `pod_network_cidr: 10.244.0.0/16`, `service_cidr: 10.96.0.0/12`).

### Roles Summary

1. **`common`**: Pinned base packages (`socat`, `kubectl-netdrill`, `bash-completion`), sysctl network tuning, and kernel modules (`overlay`, `br_netfilter`, `rbd`).
1. **`containerd`**: Container runtime installation, configuration (`SystemdCgroup = true`), and service health validation.
1. **`kubernetes_packages`**: APT repository setup (`pkgs.k8s.io`), pinned binaries (`kubeadm`, `kubelet`, `kubectl`), and apt-mark hold.
1. **`control_plane`**: `kubeadm init` automation, dynamic IP discovery for kube-apiserver TLS SANs, `~/.kube/config` distribution, user shell preferences (`alias k=kubectl`, `export koyaml="..."`, bash completion, and `~/.kube/kuberc`), and training MOTD cleanup.
1. **`worker`**: Node registration via secure join tokens and discovery hashes.
1. **`cilium`**: Helm-based Cilium CNI deployment with eBPF host routing and status health checks.
1. **`caddy`**: Ingress reverse proxy with PowerDNS DNS-01 ACME Let's Encrypt certificates.
1. **`rook_ceph`**: Cloud-native block storage orchestration via Rook-Ceph operator, backed by a dedicated unformatted volume on the control plane node and dynamically provisioned to worker nodes via Ceph CSI.
1. **`control_plane_tools`**: Control plane utilities including `etcdctl`, `etcdutl` (pinned `v3.5.16` with system-wide `ETCDCTL_API=3`), `k9s` (pinned `v0.51.0` with transparent Nord skin), and diagnostics.
1. **`cka_lab`**: Hands-on CKA exam practice scenarios deployed exclusively via `make preprod-cka-lab` (`playbooks/cka_lab.yml`), including initial steps reminder MOTD activation.
1. **`upgrade`**: Rolling node upgrades (`kubeadm upgrade apply/node`, `kubelet`, `kubectl`).
1. **`reset`**: Safe cluster teardown and node state reset (`kubeadm reset -f`, interface cleanups).

---

## 3. CKA Lab Practice Environment (`cka_lab`)

Dedicated CKA certification scenarios provisioned on `kube-control-plane`:

- **User Authentication (`user_rbac`)**:
  - Trainee user `anna`: Dedicated Linux user with CSR-approved certificate (`/CN=anna/O=developers`) and isolated `~/.kube/config`.
  - Minimal context script (`create-user-context.sh`): Located at `/home/vagrant/cka/rbac/create-user-context.sh` (symlinked at `/home/vagrant/cka/create-user-context.sh`). Follows `bmuschko/cka-crash-course` (Exercise 04) to generate client keys, approve CSRs, and configure a minimal-permission user context `vagrant` in `~/.kube/config`.
  - Exercise guide: `/home/vagrant/cka/rbac/README.md`.
- **Secrets Scenario (`secrets`)**: Sample Secrets across `default` and `development` namespaces (`Opaque`, `basic-auth`, `tls`, `ssh-auth`) at `/home/vagrant/cka/secrets/sample-secrets.yaml`.
- **ConfigMaps & Kustomize (`configmaps`)**:
  - Sample ConfigMaps across namespaces at `/home/vagrant/cka/configmaps/sample-configmaps.yaml`.
  - Self-contained Kustomize lab at `/home/vagrant/cka/kustomize/` (`base/`, `overlays/development/`, `overlays/production/`).
- **Helm & Addons (`helm`)**: Standalone installation scripts for Metrics Server (`install-kube-metrics.sh`), Prometheus Operator (`install-kube-prometheus.sh`), NGINX Gateway Fabric (`install-nginx-gateway-fabric.sh`), and httpbin-go (`install-httpbin-go.sh`) at `/home/vagrant/cka/helm/`.

---

## 4. Workflows & Command Reference

Always run commands from the repository root or `k8s-homelab/`.

### Lab Lifecycle

```bash
cd k8s-homelab

# Boot preprod VMs
make preprod-up

# Full cluster deployment via Ansible
make preprod-deploy

# Deploy CKA practice training lab
make preprod-cka-lab

# Suspend / halt VMs
make preprod-down

# Destroy VMs
make preprod-destroy
```

- **`make preprod-up`**: Boots base VMs with containerd and Kubernetes binaries preinstalled.
- **`make preprod-deploy`**: Full automated cluster deployment via Ansible (`site.yml`). Initializes control plane, configures user preferences, joins workers, installs Cilium, and automatically cleans up `~/.motd`.
- **`make preprod-cka-lab`**: Deploys dedicated hands-on CKA practice scenarios (`playbooks/cka_lab.yml`) and activates the initial steps reminder MOTD on the control plane (~/.kube backup, kubectl completion, alias k, completion for k, and safe deletion kuberc).

### Playbook Execution Wrapper (`run-playbook.sh`)

Use `./scripts/run-playbook.sh` instead of invoking raw `ansible-playbook`:

```bash
cd k8s-homelab

# Run default site playbook against preprod
./scripts/run-playbook.sh

# Run specific playbook with custom tags
./scripts/run-playbook.sh -p playbooks/site.yml -t completion

# Run positional playbook syntax
./scripts/run-playbook.sh playbooks/cka_lab.yml -i inventory/preprod/hosts.ini

# Cluster upgrade
./scripts/run-playbook.sh -e preprod -p upgrade.yml --extra-vars "k8s_version=1.34.2-1.1"
```

### Workstation Kubeconfig Synchronization

```bash
cd k8s-homelab

# Fast non-destructive sync of control plane credentials to ~/.kube/config
./scripts/sync-kubeconfig.sh
```

---

## 5. Agent Quality Gates & Validation Rules

Before committing changes or marking tasks complete, agents must verify all applicable linters:

### 1. YAML Validation

```bash
yamllint -c .yamllint <files>
```

### 2. Shell Script Validation

```bash
shellcheck -s bash <script_path>
```

- Adhere to defensive Bash patterns: `set -euo pipefail`, double-quote variables, handle unbound parameters cleanly (`${VAR:-}`).

### 3. Markdown Standards

```bash
nix shell nixpkgs#markdownlint-cli2 --command markdownlint-cli2 <markdown_files>
```

- **MD012**: No multiple consecutive blank lines (max 1 blank line between blocks).
- **MD029**: Ordered list prefixes must follow `1.` style (use `1.` for all items in ordered lists).

### 4. Ansible Linting

```bash
nix shell nixpkgs#ansible-lint --command bash -c \
  "ANSIBLE_ROLES_PATH=k8s-homelab/roles ansible-lint -c k8s-homelab/.ansible-lint k8s-homelab/playbooks/site.yml"
```

- Code must pass the `production` profile with 0 failures and 0 warnings.

---

## 6. Git & Mirroring Conventions

1. **Commit Messages**: Follow Conventional Commits format:
   - `feat(k8s-homelab): ...`
   - `fix(scripts): ...`
   - `refactor(common): ...`
   - `docs(cka_lab): ...`
2. **Gitea Upstream Remote**:
   - `origin` is `git@git.priv.os76.xyz:xeno/os76-ansible.git` on branch `master`.
3. **Public GitHub Mirror**:
   - The `k8s-homelab/` subproject is mirrored publicly at `/home/xeno/git/github/public/ansible/` (`git@github.com:xenOs76/ansible.git` on branch `main`).
   - When modifying `k8s-homelab`, synchronize changed files to `/home/xeno/git/github/public/ansible/k8s-homelab/`, ensure clean git status, and push to GitHub `origin/main`.
4. **Changelog**:
   - Every user-facing feature, fix, or scenario addition must be documented under `## [Unreleased]` in `k8s-homelab/CHANGELOG.md`.

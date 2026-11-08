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

1. **`common`**: Pinned base packages (`socat`, `kubectl-netdrill`, `bash-completion`, `vim`), sysctl network tuning,
   default system editor configuration (`vim`), global YAML indentation defaults (`/etc/vim/vimrc.local`), and kernel
   modules (`overlay`, `br_netfilter`).
1. **`containerd`**: Container runtime installation, configuration (`SystemdCgroup = true`), and service health validation.
1. **`kubernetes_packages`**: APT repository setup (`pkgs.k8s.io`), pinned binaries (`kubeadm`, `kubelet`, `kubectl`), and apt-mark hold.
1. **`control_plane`**: `kubeadm init` automation, dynamic IP discovery for kube-apiserver TLS SANs, automated daily etcd backup with systemd timer (`etcd-backup.timer`), `~/.kube/config` distribution, user shell preferences (`alias k=kubectl`, `export kdo/koyaml="..."`, `export know="..."`, `alias etcdctl="..."`, bash completion, and `~/.kube/kuberc`), and training MOTD cleanup.
1. **`worker`**: Node registration via secure join tokens and discovery hashes.
1. **`cilium`**: Helm-based Cilium CNI deployment with eBPF host routing and status health checks.
1. **`caddy`**: Ingress reverse proxy with PowerDNS DNS-01 ACME Let's Encrypt certificates.
1. **`rook_ceph`**: Cloud-native block storage orchestration via Rook-Ceph operator, backed by a dedicated unformatted volume on the control plane node and dynamically provisioned to worker nodes via Ceph CSI.
1. **`nfs_server`**: Linux kernel NFS storage server on control plane exporting `/srv/nfsroot` to cluster worker nodes, provisioned automatically during `make preprod-up` and supported across preprod and prod.
1. **`iscsi_target`**: Standalone Linux-IO (LIO) iSCSI target server on control plane with file-backed LUNs for raw block and PV/PVC testing (`make preprod-iscsi`).
1. **`control_plane_tools`**: Control plane utilities including `etcdctl`, `etcdutl` (pinned `v3.5.16` with system-wide
   `ETCDCTL_API=3`), `k9s` (pinned `v0.51.0` with transparent Nord skin), `glow` (pinned `2.1.1` with styled alias),
   `krew` (pinned `v0.5.0` plugin manager), and `kubectl-cyclonus` (pinned `v0.2.1` NetworkPolicy analyzer).
1. **`cka_lab`**: Node preparation and lab synchronization role deployed via `make preprod-cka-lab`
   (`playbooks/cka_lab.yml`), including initial steps reminder MOTD, inter-node SSH, trainee user `anna`, and repo sync.
1. **`upgrade`**: Rolling node upgrades (`kubeadm upgrade apply/node`, `kubelet`, `kubectl`).
1. **`reset`**: Safe cluster teardown and node state reset (`kubeadm reset -f`, interface cleanups).

---

## 3. CKA Lab Practice Environment & Decoupled `os76-cka-lab`

The CKA exam training curriculum is hosted in an independent, purpose-built repository **`os76-cka-lab`**
(`git@git.priv.os76.xyz:xeno/os76-cka-lab.git`, private on Gitea only, not mirrored to GitHub). It features
pure YAML manifests, native bash setup/verification scripts, and the lightweight `./ckalab` CLI runner.

The `os76-ansible` repository provides the foundational infrastructure automation and reproducible intermediate
VM staging states required for all CKA challenges:

- **Stage 0 (`make preprod-stage-bare`)**: OS tuning, sysctls, and kernel modules (`overlay`, `br_netfilter`) only.
  Leaves nodes without containerd or k8s binaries for CRI and cluster bootstrapping drills from scratch.
- **Stage 1 (`make preprod-stage-prebootstrap`)**: Nodes primed with `containerd`, pinned `kubeadm`, `kubelet`,
  and `kubectl`, and control plane tools. Uninitialized (`kubeadm init` has not run).
- **Stage 2 (`make preprod-stage-cp-only`)**: Control plane initialized with Cilium CNI and workstation credentials
  synced. Worker nodes unjoined for token creation, discovery hash calculation, and worker join practice.
- **Stage 3 (`make preprod-stage-ready`)**: Full multi-node cluster ready (identical to `make preprod-deploy`).
- **Snapshot Management (`make cka-snapshot-save` / `make cka-snapshot-restore`)**: Instant Libvirt snapshot
  save and restore for disaster recovery and fast training ground resets without full VM re-creation.
- **Lab Synchronization (`make cka-lab-clone`)**: Synchronizes the standalone `os76-cka-lab` repository into
  `/home/vagrant/cka/` on `kube-control-plane`.

- **Node-Level Infrastructure Preparation (`roles/cka_lab`)**:
  - Trainee user `anna`: Dedicated Linux user with CSR-approved certificate (`/CN=anna/O=developers`) and isolated
    `~/.kube/config`.
  - Inter-node SSH: Automated SSH keypair and `/etc/hosts` resolution across cluster nodes for seamless worker access.
  - Training MOTD: Reminds trainee of standard environment variables (`kdo`, `know`), aliases (`k`, `etcdctl`), and
    exam documentation boundaries.
  - Automated synchronization: Synchronizes the standalone `os76-cka-lab` suite into `/home/vagrant/cka/` via
    `ansible.posix.synchronize` (or Git clone fallback) and ensures executable permissions on `./ckalab`.

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
- **`make preprod-cka-lab`**: Deploys dedicated hands-on CKA practice scenarios (`playbooks/cka_lab.yml`) and activates the initial steps reminder MOTD on the control plane (~/.kube backup, kubectl completion, alias k, completion for k, kdo, know, etcdctl alias, and safe deletion kuberc).

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

### 5. Markdown & README Paragraph Line Length (120 chars)

```bash
python3 scripts/check-readme-line-length.py <files>
```

- All paragraph lines, bullet point descriptions, and blockquotes in READMEs (`README.md`, `*readme.md.j2`, `*.md`) must adhere to a strict 120-character maximum line length.
- Code blocks, tables, headings, and long URLs are exempt.
- Can be automatically validated across the repo via `python3 scripts/check-readme-line-length.py --all` or auto-formatted via `python3 scripts/format-readme-line-length.py <files>`.
- Enforced on every commit via Git pre-commit hook (`.githooks/checks/readme-line-length.sh`).

---

## 6. Git & Mirroring Conventions

1. **Commit Messages**: Follow Conventional Commits format:
   - `feat(k8s-homelab): ...`
   - `fix(scripts): ...`
   - `refactor(common): ...`
   - `docs(cka_lab): ...`
1. **Gitea Upstream Remote**:
   - `origin` is `git@git.priv.os76.xyz:xeno/os76-ansible.git` on branch `master`.
1. **Public GitHub Mirror**:
   - The `k8s-homelab/` subproject is mirrored publicly at `/home/xeno/git/github/public/ansible/` (`git@github.com:xenOs76/ansible.git` on branch `main`).
   - Only synchronize changed files to `/home/xeno/git/github/public/ansible/k8s-homelab/` and push to GitHub `origin/main` when explicitly requested by the user.
1. **Changelog**:
   - Every user-facing feature, fix, or scenario addition must be documented under `## [Unreleased]` in `k8s-homelab/CHANGELOG.md`.
   - Maintain a concise, high-level summary style: group related items by major feature area in bold, avoiding deeply nested sub-bullets or individual script/manifest file path clutter.

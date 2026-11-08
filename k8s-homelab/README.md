# Kubernetes Homelab & Certification Lab Suite (`k8s-homelab`)

Modular, production-grade Ansible automation suite to bootstrap, configure, manage, and tear down a multi-node
Kubernetes 1.34+ cluster (`kubeadm` + `containerd` + Cilium CNI) on Libvirt/KVM via Vagrant or bare metal.

The environment serves as both an enterprise-grade homelab foundation and a rapid-iteration training platform for the
**Certified Kubernetes Administrator (CKA)** and **Certified Kubernetes Security Specialist (CKS)** certifications.

---

## Architecture & Topology

### Virtual Machine Inventory (`inventory/preprod/hosts.ini`)

| Node Name | IP Address | Roles | vCPU | RAM | Storage Disks |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `kube-control-plane` | `192.168.56.10` | Control Plane, API Server, etcd, NFS, iSCSI | 2 | 4096 MB | 25GB root + 20GB Ceph volume (`/dev/vdb`) |
| `kube-worker-1` | `192.168.56.21` | Worker Node | 2 | 2048 MB | 25GB root |
| `kube-worker-2` | `192.168.56.22` | Worker Node | 2 | 2048 MB | 25GB root |

- **Operating System**: Ubuntu 26.04 LTS
- **Container Runtime**: `containerd` (`SystemdCgroup = true`)
- **Networking & CNI**: Cilium with eBPF host routing (`pod_network_cidr: 10.1.0.0/16`, `service_cidr: 10.96.0.0/12`)
- **Ingress**: Custom-compiled Caddy with PowerDNS DNS-01 ACME Let's Encrypt wildcard certificates

---

## Core Subsystems

### 1. Storage Architecture

- **NFS Shared Storage (`roles/nfs_server`, `playbooks/nfs.yml`)**: Linux kernel NFS server exporting `/srv/nfsroot`
  (with legacy `/exports` symlink) across cluster worker nodes as the lightweight core storage baseline.
- **Rook-Ceph (`roles/rook_ceph`, `playbooks/ceph.yml`)**: On-demand cloud-native Ceph orchestration backed by
  `/dev/vdb` on the control plane, dynamically provisioning block PVCs via `rook-ceph-block` StorageClass.
- **iSCSI Target Server (`roles/iscsi_target`, `playbooks/iscsi.yml`)**: On-demand standalone Linux-IO (`LIO`) kernel
  target with file-backed LUNs for raw block and static PV testing.

### 2. CKA Staged Provisioning & Practice Infrastructure (`roles/cka_lab`, `playbooks/`)

The CKA curriculum is decoupled into an independent challenge repository featuring 42 active-recall drills and the
POSIX/Bash `./ckalab` CLI runner. `k8s-homelab` provides the foundational infrastructure automation and reproducible
intermediate VM staging states required for all CKA challenges:

- **Stage 0: Bare Nodes (`make preprod-stage-bare`)**: OS tuning, sysctls, and kernel modules (`overlay`,
  `br_netfilter`) only. Leaves nodes without containerd or k8s binaries for CRI and cluster bootstrapping drills from
  scratch.
- **Stage 1: Pre-bootstrap (`make preprod-stage-prebootstrap`)**: Nodes primed with `containerd`, pinned `kubeadm`,
  `kubelet`, `kubectl`, and control plane tools. Uninitialized (`kubeadm init` has not run).
- **Stage 2: Control Plane Only (`make preprod-stage-cp-only`)**: Control plane initialized with Cilium CNI and
  workstation credentials synced. Worker nodes unjoined for token creation, discovery hash calculation, and worker join
  practice.
- **Stage 3: Ready Cluster (`make preprod-stage-ready` / `make preprod-deploy`)**: Full multi-node cluster ready.
- **Snapshot Management (`make cka-snapshot-save` / `make cka-snapshot-restore`)**: Instant atomic Libvirt disk snapshot
  save and restore for disaster recovery and fast training ground resets without full VM re-creation.
- **Node-Level Infrastructure Preparation (`roles/cka_lab`)**:
  - Trainee user `anna`: Dedicated Linux user with CSR-approved certificate (`/CN=anna/O=developers`) and isolated
    `~/.kube/config`.
  - Inter-node SSH: Automated SSH keypair and `/etc/hosts` resolution across cluster nodes for seamless worker access.
  - Training MOTD: Reminds trainee of standard environment variables (`kdo`, `know`), aliases (`k`, `etcdctl`), and
    exam documentation boundaries.
  - Lab Synchronization: Synchronizes the standalone CKA practice suite into `/home/vagrant/cka/` via
    `ansible.posix.synchronize` (or Git fallback) and ensures executable permissions on `./ckalab`.

### 3. CKS Certification Lab Suite (`roles/cks_lab`)

Deployed to `/home/vagrant/cks/` on `kube-control-plane` (`make preprod-cks-lab`):

- **Pod-to-Pod Security & NetworkPolicies**: Zero-trust default-deny isolation, cross-tenant logical AND policies,
  CoreDNS/external egress filtering, Cilium Hubble eBPF drop tracing, and `kubectl-cyclonus` policy analysis.
- **Security Toolchain**: Pinned binaries with dual `amd64`/`arm64` support (`kube-bench`, `trivy`, `hadolint`,
  `kubesec`, `cosign`, `falco`).
- **AppArmor Kernel Hardening**: Multi-node profile distribution and kernel enforcement (`k8s-deny-write`,
  `k8s-deny-network`) with Pod drills and automated test scripts.
- **Seccomp Syscall Filtering**: Multi-node Seccomp profile placement in kubelet root (`audit.json`,
  `fine-grained.json`) and native Kubernetes 1.30+ `securityContext` Pod drills.
- **Host Attack Surface Auditing**: Native audit utilities (`audit-ports.sh`, `audit-services.sh`,
  `audit-file-perms.sh`).

---

## Quickstart & Workflow Commands

Always execute commands inside the reproducible Nix environment via `./scripts/shell.sh` or through `Makefile` targets.

### Cluster Lifecycle

```bash
# 1. Boot preprod Libvirt VMs (creates VMs and provisions NFS server)
make preprod-up

# 2. Deploy complete Kubernetes cluster (control plane, workers, Cilium CNI)
make preprod-deploy

# 3. Synchronize credentials non-destructively to workstation ~/.kube/config
make preprod-sync-kubeconfig

# 4. Verify cluster connectivity directly from your host workstation
kubectl --context=k8s-homelab-preprod get nodes -o wide
```

### Certification Labs & CKA Staged Lifecycle

```bash
# Intermediate staging states for CRI and bootstrapping drills
make preprod-stage-bare          # Stage 0: OS tuning only (no containerd/k8s)
make preprod-stage-prebootstrap  # Stage 1: containerd & k8s binaries installed
make preprod-stage-cp-only       # Stage 2: Control plane initialized, workers unjoined
make preprod-stage-ready         # Stage 3: Full multi-node cluster ready

# Instant Libvirt disk snapshots for rapid drill resets
make cka-snapshot-save           # Save 'cka-baseline' snapshot across all VMs
make cka-snapshot-restore        # Revert all VMs to 'cka-baseline'

# Prepare control plane trainee environment & sync CKA lab suite
make preprod-cka-lab

# Deploy hands-on CKS security training scenarios
make preprod-cks-lab
```

### Storage Provisioning

```bash
# Deploy Rook-Ceph operator & CephCluster on preprod
make preprod-ceph

# Check Ceph cluster, pool, and operator status
make preprod-ceph-status

# Deploy standalone iSCSI target server
make preprod-iscsi

# Deploy NFS server
make preprod-nfs
```

### Teardown & Maintenance

```bash
# Fast cluster reset without destroying VMs (clears kubeadm, iptables, CNI interfaces)
make preprod-reset

# Perform rolling upgrade across control plane and workers
./scripts/run-playbook.sh -e preprod -p upgrade.yml --extra-vars "k8s_version=1.34.2-1.1"

# Destroy VMs and remove storage volumes
make preprod-destroy
```

---

## Directory Structure

```text
k8s-homelab/
├── Vagrantfile                   # 1 Control Plane + 2 Workers on Libvirt/KVM
├── Makefile                      # Standardized automation targets
├── ansible.cfg                   # Pipelining, roles path, YAML stdout callback
├── inventory/
│   ├── preprod/hosts.ini         # Vagrant libvirt inventory with per-host keys
│   └── prod/hosts.ini            # Bare-metal / physical cluster inventory
├── group_vars/
│   ├── all.yml                   # Cluster version, CIDRs, suite version (1.6.0)
│   ├── preprod.yml               # Preprod environment overrides
│   ├── control_plane.yml         # Control plane settings
│   └── workers.yml               # Worker node settings
├── roles/
│   ├── common/                   # Kernel modules, sysctl network tuning, base packages
│   ├── containerd/               # containerd runtime configuration (SystemdCgroup)
│   ├── kubernetes_packages/      # pkgs.k8s.io repository and pinned k8s binaries
│   ├── control_plane/            # kubeadm init, TLS SANs, shell preferences, credentials
│   ├── worker/                   # kubeadm join token registration
│   ├── control_plane_tools/      # Helm, k9s, glow, etcdctl, krew, kubectl-cyclonus
│   ├── cilium/                   # Cilium CLI installation & eBPF CNI deployment
│   ├── caddy/                    # Ingress proxy with PowerDNS DNS-01 ACME TLS
│   ├── rook_ceph/                # Rook-Ceph operator & CephBlockPool storage
│   ├── nfs_server/               # Linux kernel NFS shared storage export
│   ├── iscsi_target/             # LIO iSCSI target server with file-backed LUNs
│   ├── cka_lab/                  # CKA trainee node setup (MOTD, SSH, anna) & lab sync
│   ├── cks_lab/                  # Hands-on CKS security tools, AppArmor, and Seccomp
│   ├── upgrade/                  # Zero-downtime rolling cluster upgrade playbook
│   └── reset/                    # Fast cluster wipe (kubeadm reset, iptables flush)
├── playbooks/                    # Orchestration playbooks (site, cka_stage_*, cks_lab)
└── scripts/                      # Lifecycle wrappers, credential sync, and linters
```

---

## Quality Gates & Linters

Every playbook and role adheres to strict production quality gates:

```bash
# Run complete test suite (yamllint, syntax check, inventory parse, ansible-lint)
make lint
```

- **Ansible Lint**: Validated against `production` profile with 0 failures and 0 warnings.
- **YAML & Shell**: Enforced with `yamllint` and defensive `shellcheck` standards (`set -euo pipefail`).
- **Markdown**: Formatted per `markdownlint-cli2` rules.

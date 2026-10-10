# Kubernetes Homelab & Certification Lab Suite (`k8s-homelab`)

Modular, production-grade Ansible automation suite to bootstrap, configure, manage, and tear down a multi-node Kubernetes 1.34+ cluster (`kubeadm` + `containerd` + Cilium CNI) on Libvirt/KVM via Vagrant or bare metal.

The environment serves as both an enterprise-grade homelab foundation and a rapid-iteration training platform for the **Certified Kubernetes Administrator (CKA)** and **Certified Kubernetes Security Specialist (CKS)** certifications.

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

- **Rook-Ceph (`roles/rook_ceph`, `playbooks/ceph.yml`)**: Cloud-native Ceph orchestration backed by `/dev/vdb` on the control plane, dynamically provisioning block PVCs via `rook-ceph-block` StorageClass.
- **NFS Shared Storage (`roles/nfs_server`, `playbooks/nfs.yml`)**: Linux kernel NFS server exporting `/exports` across cluster worker nodes.
- **iSCSI Target Server (`roles/iscsi_target`, `playbooks/iscsi.yml`)**: Standalone Linux-IO (`LIO`) kernel target with file-backed LUNs for raw block and static PV testing.

### 2. CKA Hands-on Lab Suite (`roles/cka_lab`)

Deployed to `/home/vagrant/cka/` on `kube-control-plane` (`make preprod-cka-lab`):

- **Workloads & Pods**: Advanced scheduling (taints, tolerations, affinity), sidecar containers, jobs, cronjobs, and ephemeral debug containers.
- **Networking**: ClusterIP, NodePort, Ingress prefix routing, Gateway API (`HTTPRoute`), and multi-tier NetworkPolicies.
- **Storage Drills**: Static PV/PVC mounts across NFS, Ceph RBD, and iSCSI raw block devices.
- **Cluster Maintenance**: Safe drain/cordon, etcd backup/restore drills (`etcdctl`/`etcdutl` v3.5.16), and rolling cluster upgrades.
- **Dynamic Chaos Injection (`make preprod-cka-chaos`)**: Headless LitmusChaos drills (OOM kills, network latency, DNS blackholing, node memory pressure).

### 3. CKS Certification Lab Suite (`roles/cks_lab`)

Deployed to `/home/vagrant/cks/` on `kube-control-plane` (`make preprod-cks-lab`):

- **Security Toolchain**: Pinned binaries with dual `amd64`/`arm64` support (`kube-bench`, `trivy`, `hadolint`, `kubesec`, `cosign`, `falco`).
- **AppArmor Kernel Hardening**: Multi-node profile distribution and kernel enforcement (`k8s-deny-write`, `k8s-deny-network`) with Pod drills and automated test scripts.
- **Seccomp Syscall Filtering**: Multi-node Seccomp profile placement in kubelet root (`audit.json`, `fine-grained.json`) and native Kubernetes 1.30+ `securityContext` Pod drills.
- **Host Attack Surface Auditing**: Native audit utilities (`audit-ports.sh`, `audit-services.sh`, `audit-file-perms.sh`).

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

### Certification Labs

```bash
# Deploy hands-on CKA training scenarios
make preprod-cka-lab

# Deploy CKA lab with dynamic LitmusChaos troubleshooting drills
make preprod-cka-chaos

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
│   ├── all.yml                   # Cluster version, CIDRs, suite version (1.4.1)
│   ├── preprod.yml               # Preprod environment overrides
│   ├── control_plane.yml         # Control plane settings
│   └── workers.yml               # Worker node settings
├── roles/
│   ├── common/                   # Kernel modules, sysctl network tuning, base packages
│   ├── containerd/               # containerd runtime configuration (SystemdCgroup)
│   ├── kubernetes_packages/      # pkgs.k8s.io repository and pinned k8s binaries
│   ├── control_plane/            # kubeadm init, TLS SANs, shell preferences, credentials
│   ├── worker/                   # kubeadm join token registration
│   ├── control_plane_tools/      # Helm, k9s (Nord theme), glow, etcdctl/etcdutl
│   ├── cilium/                   # Cilium CLI installation & eBPF CNI deployment
│   ├── caddy/                    # Ingress proxy with PowerDNS DNS-01 ACME TLS
│   ├── rook_ceph/                # Rook-Ceph operator & CephBlockPool storage
│   ├── nfs_server/               # Linux kernel NFS shared storage export
│   ├── iscsi_target/             # LIO iSCSI target server with file-backed LUNs
│   ├── cka_lab/                  # 15 hands-on CKA practice scenarios & Litmus chaos
│   ├── cks_lab/                  # Hands-on CKS security tools, AppArmor, and Seccomp
│   ├── upgrade/                  # Zero-downtime rolling cluster upgrade playbook
│   └── reset/                    # Fast cluster wipe (kubeadm reset, iptables flush)
├── playbooks/                    # Orchestration playbooks (site, cka_lab, cks_lab, etc.)
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

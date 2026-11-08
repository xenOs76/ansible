# Kubernetes Ansible Homelab & Certification Labs

Production-grade Ansible automation for multi-node Kubernetes 1.34+ (`kubeadm` + `containerd` + Cilium CNI) running on
Libvirt/KVM via Vagrant or bare metal, featuring staged VM provisioning and training environments for **CKA** and
**CKS**.

---

## Highlights

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Cluster Topology** | Kubernetes 1.34+, Ubuntu 26.04 | 1 Control Plane + 2 Workers with automated bootstrapping |
| **Networking & Ingress** | Cilium (eBPF) + Caddy Reverse Proxy | Dual Ingress (NodePort 31080) and Gateway API (NodePort 30080) routing |
| **Storage Architecture** | Kernel NFS, Rook-Ceph, iSCSI | Core baseline NFS storage (`/srv/nfsroot`) with on-demand Ceph and iSCSI targets |
| **CKA Staged Provisioning** | 4-Stage VM Lifecycle & Snapshots | Intermediate staging (Bare, CRI, CP-only, Ready) with instant Libvirt snapshots |
| **Security Certification** | CKS Training Suite (`roles/cks_lab`) | Zero-trust NetworkPolicies, metadata shielding, AppArmor, and Seccomp profiles |

---

## Quickstart

```bash
cd k8s-homelab

# 1. Boot preprod Libvirt VMs
make preprod-up

# 2. Deploy full cluster & sync workstation credentials
make preprod-deploy && make preprod-sync-kubeconfig

# 3. Intermediate staging states for CKA practice drills
make preprod-stage-bare          # Stage 0: OS tuning & kernel modules only
make preprod-stage-prebootstrap  # Stage 1: containerd & k8s binaries installed
make preprod-stage-cp-only       # Stage 2: CP initialized, workers unjoined
make preprod-stage-ready         # Stage 3: Full multi-node cluster ready

# 4. Instant snapshot backup and restore
make cka-snapshot-save           # Save 'cka-baseline' disk snapshot across all VMs
make cka-snapshot-restore        # Instant revert to baseline state

# 5. Deploy certification training labs
make preprod-cka-lab             # Node preparation (MOTD, SSH, user anna) & lab sync
make preprod-cks-lab             # CKS security hardening scenarios
```

For full architecture details, topology diagrams, and scenario breakdowns, see
[**`k8s-homelab/README.md`**](./k8s-homelab/README.md).

---

## Quality Gates

- **Ansible Lint**: Zero warnings or failures on `production` profile.
- **Linters**: Defensive Bash (`shellcheck`), `yamllint`, and `markdownlint-cli2`.
- **Reproducibility**: Hermetic Nix development environment (`shell.nix`).

---

## License

Licensed under the [MIT License](./LICENSE).

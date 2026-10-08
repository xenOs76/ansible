# Kubernetes Ansible Homelab & Certification Labs

Production-grade Ansible automation for multi-node Kubernetes 1.34+ (`kubeadm` + `containerd` + Cilium CNI) running on Libvirt/KVM via Vagrant or bare metal, featuring comprehensive **CKA** and **CKS** practice suites.

---

## Highlights

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Cluster Topology** | Kubernetes 1.34.1, Ubuntu 26.04 | 1 Control Plane + 2 Workers with automated bootstrapping |
| **Networking & Ingress** | Cilium (eBPF) + Caddy Reverse Proxy | eBPF host routing and automated PowerDNS DNS-01 Let's Encrypt TLS |
| **Storage Stack** | Rook-Ceph, NFS, iSCSI | Ceph block storage (`/dev/vdb`), kernel NFS exports, and LIO iSCSI target |
| **Certification Labs** | CKA & CKS Training Suites | 15+ CKA drills (LitmusChaos, RBAC, static pods) and CKS hardening (AppArmor, Seccomp) |

---

## Quickstart

```bash
cd k8s-homelab

# 1. Boot preprod Libvirt VMs
make preprod-up

# 2. Deploy full cluster & sync workstation credentials
make preprod-deploy && make preprod-sync-kubeconfig

# 3. Deploy certification training labs
make preprod-cka-lab    # CKA practice scenarios
make preprod-cks-lab    # CKS security hardening scenarios
```

For full architecture details, topology diagrams, and scenario breakdowns, see [**`k8s-homelab/README.md`**](./k8s-homelab/README.md).

---

## Quality Gates

- **Ansible Lint**: Zero warnings or failures on `production` profile.
- **Linters**: Defensive Bash (`shellcheck`), `yamllint`, and `markdownlint-cli2`.
- **Reproducibility**: Hermetic Nix development environment (`shell.nix`).

---

## License

Licensed under the [MIT License](./LICENSE).

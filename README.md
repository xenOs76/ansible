# Ansible Automation

A curated collection of production-grade Ansible automation playbooks, infrastructure-as-code configurations, and hands-on lab environments.

## Repository Contents

### [k8s-homelab](./k8s-homelab)

Automated provisioning, configuration, and lifecycle management for multi-node Kubernetes clusters (`kubeadm`) on Libvirt/KVM via Vagrant and bare metal/preprod environments.

Key features include:

- **Automated Bootstrapping**: Modular Ansible roles for container runtime (`containerd`), Kubernetes packages (`kubeadm`, `kubelet`, `kubectl`), control plane initialization, and worker join automation.
- **Networking & CNI**: Production-ready Cilium CNI deployment with eBPF host routing.
- **Enterprise Storage**: Integrated Rook-Ceph block storage, kernel NFS exports, and standalone LIO iSCSI target server.
- **CKA & CKS Certification Labs**: 15+ hands-on CKA practice scenarios with LitmusChaos drills, alongside CKS host hardening (AppArmor, Seccomp, and security toolchain).
- **Fast Credential Sync**: Defensive Bash scripts (`scripts/sync-kubeconfig.sh`) for non-destructive synchronization of workstation `~/.kube/config` with strict TLS verification.
- **Upgrades & Maintenance**: Automated rolling cluster upgrades and etcd snapshot/health verification tools (`etcdctl`, `etcdutl`).

For detailed documentation, architecture diagrams, and quick-start instructions, refer to the [k8s-homelab README](./k8s-homelab/README.md).

## Quality & Standards

All playbooks and roles in this repository adhere to strict quality standards:

- **Ansible Lint**: Validated against `ansible-lint` using the `production` profile with zero warnings or failures.
- **YAML & Markdown**: Checked via `yamllint` and `markdownlint-cli2`.
- **Reproducible Environments**: Managed with Nix flakes and `shell.nix` for deterministic development tooling.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-10-08

### Added

- **CKS Certification Lab Suite (`roles/cks_lab`, `playbooks/cks_lab.yml`)**: Provisioned hands-on exam training environment on control plane with automated security tooling (`kube-bench`, `trivy`, `hadolint`, `kubesec`, `cosign`), multi-node AppArmor profiles and kernel enforcement (`k8s-deny-write`, `k8s-deny-network`), Seccomp profiles (`audit.json`, `fine-grained.json`), native K8s 1.30+ security context drills, and system footprint audit scripts.
- **NFS Shared Storage (`roles/nfs_server`, `playbooks/nfs.yml`)**: Dedicated NFS kernel storage server role provisioned automatically during VM boot (`make preprod-up`) across preprod and prod environments.
- **iSCSI Target & Storage Scenarios (`roles/iscsi_target`, `roles/cka_lab`)**: Standalone Linux-IO (LIO) target server with declarative file-backed LUNs, initiator tooling, and CKA volume drills for direct mounts, raw block devices, and static PV/PVC bindings.
- **Ceph RBD Practice Drills (`roles/cka_lab`)**: Block storage practice scenarios covering ext4 dynamic volumes, raw block devices, Ceph CSI static bindings, and live online volume expansion.
- **Rook-Ceph Block Storage (`roles/rook_ceph`)**: Cloud-native Ceph orchestration backed by dedicated virtual disk on the control plane with dynamic storage class provisioning.
- **Control Plane Tooling (`roles/control_plane_tools`)**: Consolidated official `glow` CLI viewer package installation into control plane bootstrap tooling.

### Fixed

- **Cross-Node Task Delegation (`inventory/preprod/hosts.ini`)**: Configured per-host SSH private keys in preprod inventory to resolve authentication failures during delegated execution across cluster nodes.
- **CKS Multi-Node Template Rendering (`roles/cks_lab`)**: Resolved list indexing in cartesian product loops for AppArmor and Seccomp profile distribution.
- **Storage & CSI Configurations (`roles/cka_lab`, `roles/rook_ceph`)**: Corrected Ceph CSI driver domain to `.csi.ceph.com` and pinned static iSCSI claims to empty StorageClass to prevent admission binding deadlocks.
- **VM Disk Provisioning & Cleanup (`Vagrantfile`, `Makefile`)**: Expanded base root disk sizing to 25GB to eliminate kubelet disk pressure, and automated secondary volume removal on destroy.

## [1.3.0] - 2026-10-02

### Added

- **CKA Training Lab Suite (`roles/cka_lab`)**: Provisioned 15+ hands-on exam practice scenarios via `make preprod-cka-lab` under `/home/vagrant/cka/`, including `scheduling`, `workloads_advanced`, `storage_classes`, `cluster_troubleshooting`, `crds`, `chaos_troubleshooting` (Headless LitmusChaos), `networking` (Services, Ingress, Gateway API, NetworkPolicies), `pods`, `deployments`, `volumes` (NFS server export), `user_rbac`, `secrets`, `configmaps`, `kustomize`, and `helm` (Metrics Server, Prometheus Operator, NGINX Gateway Fabric, httpbin-go).
- **Caddy Ingress Reverse Proxy (`roles/caddy`)**: Automated `xcaddy` compilation with PowerDNS DNS-01 ACME Let's Encrypt support, Garage S3 binary caching (`s3://os76-assets/caddy/...`), and `https-wrench` TLS validation.
- **SOPS & Secrets Management**: Configured Age key encryption workflow (`.sops.yaml`) for transparent Ansible variable decryption via `community.sops.sops`.
- **Control Plane Tools**: Automated installation of pinned `etcdctl`/`etcdutl` (`v3.5.16`) and dynamic kube-apiserver TLS certificate SAN address discovery.
- **Base OS Updates**: Added automated OS package upgrades during VM provisioning (`Vagrantfile`, `roles/common`).

### Changed

- Upgraded `k9s` to `v0.51.0` with transparent Nord themes for SSH sessions.
- Expanded default preprod inventory to 2 worker nodes (`kube-worker-2` at `192.168.56.22`).
- Rewrote `scripts/sync-kubeconfig.sh` in native Bash/kubectl subcommands, reducing execution time to ~1s.
- Relocated legacy CKA scripts under `/home/vagrant/cka/` directory structure.

### Removed

- Removed root-level `install-kube-metrics.sh` staging in favor of `roles/cka_lab`.

### Fixed

- Fixed LitmusChaos experiment CRDs, RBAC bindings, and containerd runtime socket integration.
- Fixed `sync-kubeconfig.sh` validation for stopped VMs and inventory management network address resolution.
- Fixed kube-apiserver TLS SAN mismatch handling with automatic SAN drift detection and non-destructive certificate re-issuance.
- Added automatic cleanup of `admin.conf` and `kubeconfig.preprod` on `make preprod-destroy`.

## [1.2.0] - 2026-09-27

### Added

- **Control Plane Tooling (`roles/control_plane_tools`)**: Automated bootstrap of Helm, `k9s` Debian package, and `scripts/install-kube-metrics.sh` for Metrics Server deployment.
- **Kubeconfig Synchronization**: Added `scripts/sync-kubeconfig.sh` helper and `make preprod-sync-kubeconfig` / `prod-sync-kubeconfig` targets for non-disruptive local `~/.kube/config` updates.
- **Environment Context Naming**: Configured environment-aware context naming in `group_vars` (`k8s-homelab-preprod`, `k8s-homelab`).
- **Script Documentation**: Standardized header docstrings and parameter specs across all `scripts/` helpers.

### Fixed

- Improved `scripts/sync-kubeconfig.sh` with robust `admin.conf` staging, dynamic TLS server address resolution, and reachable IP probing.
- Verified Helm GPG key fingerprints to reject untrusted primary keys.

## [1.1.0] - 2026-09-23

### Added

- Added OS76 custom APT repository (`repo.os76.xyz`) and automated `kubectl-netdrill` plugin installation.
- Automated `/etc/crictl.yaml` generation in `containerd` role and `scripts/common.sh`.
- Added `make preprod-provision` and `make preprod-recreate` Vagrant management targets.
- Added `playbook_version` variable and startup version announcement in `playbooks/site.yml`.

### Changed

- Flattened repository layout: moved `Vagrantfile` to `k8s-homelab/` root and unified scripts under `scripts/`.
- Unified Nix development environment into root `shell.nix`.
- Standardized Makefile targets with consistent `preprod-` prefix (`preprod-deploy`, `preprod-cni`, etc.).

### Fixed

- Fixed `kubelet` manifest directory permission error (`0755`) on worker nodes.
- Eliminated `crictl` deprecated endpoint warnings.

### Removed

- Removed redundant `make bootstrap` target in favor of `make preprod-up`.

## [1.0.0] - 2026-09-20

### Added

- Initial release of modular, production-grade Ansible automation for Kubernetes (`kubeadm` + `containerd` + `Cilium`).
- Ansible roles: `common`, `containerd`, `kubernetes_packages`, `control_plane`, `worker`, `cilium`, `upgrade`, `reset`.
- Multi-node preprod virtualization environment using Vagrant + Libvirt (KVM/QEMU).
- CKA training workflows: cluster deployment, rolling upgrade, etcd backup/restore, and cluster reset.
- Automated code quality validation via `yamllint` and `ansible-lint` (`production` profile).

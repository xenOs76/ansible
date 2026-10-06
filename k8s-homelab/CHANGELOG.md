# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **NFS Server Role & Preprod Provisioning (`roles/nfs_server`, `playbooks/nfs.yml`)**: Extracted NFS kernel server installation and daemon management out of `roles/cka_lab` into dedicated `roles/nfs_server`, enabled for both preprod and prod environments, automated on `make preprod-up`, added `preprod-nfs` / `prod-nfs` targets, and retained sample volume drill files within the CKA lab phase.
- **iSCSI Target Server & CKA Volume Drills (`roles/iscsi_target`, `roles/cka_lab`)**: Provisioned a standalone Linux-IO (`LIO`) kernel target subsystem role (`targetcli-fb`) with declarative file-backed LUNs (`lun1.img`, `lun2.img`), client initiator setup (`open-iscsi`, `iscsid`, `iscsi_tcp`), `playbooks/iscsi.yml`, `make preprod-iscsi` target, and hands-on CKA volume drills under `cka/volumes/07-iscsi/` (direct Pod mounts, static PV/PVC bindings, raw block devices, RWO single-writer fencing, CHAP secret references, and automated verification tests).
- **Ceph RBD Volume Scenarios (`roles/cka_lab`)**: Added Ceph RADOS Block Device (RBD) practice drills under `cka/volumes/06-rbd/`, featuring dynamic ext4 filesystem mounts, raw block device consumption (`volumeMode: Block` with `volumeDevices`), static Ceph CSI PV/PVC bindings, live online volume expansion, and automated non-interactive verification.
- **Glow Markdown CLI (`roles/control_plane_tools`)**: Consolidated `glow` CLI viewer installation into control plane bootstrap tools via official release `.deb` packages, eliminating custom APT repository setup and repeated package cache refreshes during CKA lab deployment.
- **Rook-Ceph Storage (`roles/rook_ceph`)**: Integrated Rook-Ceph operator (pinned Helm chart `v1.15.5`) with single-node OSD backed by a 20GB secondary disk (`/dev/vdb`), dynamic `rook-ceph-block` StorageClass, kernel `rbd` module tuning, `playbooks/ceph.yml`, `scripts/check-ceph-status.sh` diagnostic tool, and `make preprod-ceph` / `make preprod-ceph-status` targets.

### Fixed

- **iSCSI Static PV/PVC Binding (`roles/cka_lab`)**: Explicitly set `storageClassName: ""` across static iSCSI PersistentVolume and PersistentVolumeClaim manifests (`02-iscsi-pv-pvc-pod.yaml`, `03-iscsi-raw-block.yaml`) to prevent the default StorageClass admission plugin from mutating claims and causing PVC binding hangs (`FailedScheduling: pod has unbound immediate PersistentVolumeClaims`), and added idempotent pre-step resource cleanup in `test-iscsi-volumes.sh`.
- **Ceph CSI Provisioner Domain (`roles/rook_ceph`, `roles/cka_lab`)**: Corrected CSI provisioner domain from `.csi.ceph.io` to `.csi.ceph.com` across StorageClass definitions, static PV manifests, and drill scripts to resolve PVC binding hangs and pod mount failures (`error processing PVC: PVC is not bound`).
- **VM Root Disk Sizing & Disk Pressure (`Vagrantfile`, `scripts/common.sh`)**: Expanded default VM root disk virtual size to 25GB (`ROOT_DISK_SIZE`) via libvirt `machine_virtual_size` across all nodes to prevent Kubelet `DiskPressure` and ephemeral-storage evictions during container downloads, and added automatic `apt-get clean` to post-upgrade provisioning steps.
- **Orphaned Storage Volume Cleanup (`Makefile`)**: Added automatic removal of secondary volume `k8s-homelab_kube-control-plane-vdb.qcow2` to `make preprod-destroy` to prevent `virStorageVolCreateXML` collisions during VM recreation.

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

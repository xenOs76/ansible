# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-10-19

### Added

- **High-Availability (HA) Multi-Master Control Plane (`roles/ha_control_plane`, `Makefile`)**:

  Introduced a production-ready 3-node HA control plane profile (3 CPs @ 2560 MB RAM + 1 Worker @ 2048 MB RAM) within a
  10 GB memory budget. Automated co-located HAProxy load balancing on port 8443, Keepalived VRRP floating VIP
  (`192.168.56.9`), automated certificate key upload during `kubeadm init`, secondary control plane join orchestration,
  and dedicated Makefile targets (`make preprod-ha-up`, `make preprod-switch-ha`).
- **HAProxy Native Prometheus Metrics, Terminal Observability & Management (`roles/ha_control_plane`)**:
  Integrated native Prometheus metrics exporter on dedicated port `8405` (`/metrics`) with root redirection and log
  suppression, real-time web stats (`/stats`), administrative UNIX socket (`/run/haproxy/admin.sock`), and `hatop`
  interactive CLI terminal monitor with system-wide alias support.
- **Fibre Channel (FC) SAN Storage Emulator & Drills (`roles/fc_san`, `playbooks/fc.yml`, `roles/cka_lab`)**:
  Introduced enterprise dual-fabric Fibre Channel SAN storage emulator role with backing sparse LUNs (`/srv/fc/`),
  management CLI (`fc-san-ctl`), canonical udev path mappings (`/dev/disk/by-path/`), and CKA drills covering raw block
  volumes, static PV/PVC lifecycles, multipath failover, and online LUN expansion.
- **CKA Cluster Installation, HA Upgrade & Hands-on Modules (`roles/cka_lab`, `~/cka/`)**:
  Expanded training suite to 19 sequentially numbered modules (`00-cluster-installation` through `19-ha-cluster`).
  Added bare-node `kubeadm` bootstrapping, multi-master upgrade rehearsal scripts (`04-ha-upgrade-sequence.sh`,
  `mock-secondary-cp-upgrade.sh`), secondary join multi-NIC advertise IP guidance, and hands-on drills for
  Deployments, Pods, ConfigMaps, Secrets, Scheduling, and K8s v1.36 GA User Namespaces.
- **Kubernetes v1.36 Baseline & v1.37 Rolling Upgrade Suite (`group_vars`, `roles/upgrade`)**:
  Bumped baseline cluster installation to v1.36 across Vagrant provisioning and inventory defaults, and updated
  automated rolling upgrade playbooks to target v1.37 with serialized control plane upgrades and node drain/uncordon.
- **Documentation & Formatting Quality Gates (`scripts/check-readme-line-length.py`)**:
  Introduced automated 120-character line length validation for READMEs and markdown templates with pre-commit hooks,
  `scripts/format-readme-line-length.py`, cluster-wide `vim` editor defaults, and global YAML indentation standards.

### Changed

- **HA Control Plane Deep Layer 7 Health Checking & Split-Brain Mitigation (`roles/ha_control_plane`)**:
  Upgraded Keepalived to use active HTTP probes against HAProxy port 8443 (`curl -kfs ... /livez`) with priority
  penalization (`weight -20`), `script_user nobody` security, and unified `state BACKUP` across all nodes to eliminate
  split-brain election races. Upgraded HAProxy backend health checking to Layer 7 HTTP checks over SSL probing
  Kubernetes `/readyz` with status 200 and body `ok` assertions.
- **HA Preprod Scenarios, Make Aliases & NFS Decoupling (`group_vars/preprod_ha.yml`, `Makefile`)**:
  Decoupled NFS server automation from HA cluster boot to keep VM lifecycle focused, added on-demand `preprod-ha-nfs`,
  introduced `preprod-cka` and `preprod-ha-cka` Makefile aliases, and scoped enabled CKA lab scenarios dynamically
  for HA preprod testing.
- **Storage Export Standardization & Ceph Lab Consolidation (`roles/nfs_server`, `roles/cka_lab`)**:
  Standardized cluster NFS export root to `/srv/nfsroot` with backward-compatible symlinks (`/exports`), and
  consolidated Ceph block, CephFS, and Ceph NFS exercises into a unified on-demand storage module (`06-ceph/`).
- **CKA Lab Walkthrough Guides & Terminal Formatting (`roles/cka_lab`)**:
  Refactored all 22 walkthrough guides and master navigation templates to 120-character wrapping for optimized terminal
  rendering in `glow`, enhanced addon prerequisite reminders, and resolved Gateway Fabric/Ingress port collisions.

### Fixed

- **HAProxy & Keepalived Service Bootstrap Failures (`roles/ha_control_plane`)**:
  Resolved HAProxy listener timing by replacing deferred restarts with immediate syntax checks and port wait assertions.
  Fixed Keepalived startup issues via dynamic interface discovery, RFC 2338 8-character `auth_pass` truncation, and
  pre-flight configuration tests.
- **NGINX Gateway Fabric CRD Conflicts & Admission Syntax (`roles/cka_lab`)**:
  Resolved Helm Server-Side Apply manager conflicts for `gateway.nginx.org` CRDs, and corrected `kubectl run` admission
  flags in scheduling capacity governance tutorial guides.

## [1.4.3] - 2026-10-14

### Added

- **Automated Daily etcd Backup & Retention (`roles/control_plane`, `roles/cka_lab`, `scripts/etcd-backup.sh`)**: Added automated daily etcd snapshot backups scheduled via systemd timer (`etcd-backup.timer`, `OnCalendar=daily`, `Persistent=true`) with health validation, endpoint TLS extraction, timestamped filenames, `etcdctl` status verification, and automated 7-day retention pruning, backed by a dedicated practice scenario (`02-automated-backup/`) with automated test validation.

- **Hands-on CKA Exam Practice Scenarios & Curricula (`roles/cka_lab`, `~/cka/`)**: Expanded exam training suite with manual client certificate and context creation drills (`~/cka/rbac/manual-user/`), static pod TLS discovery and etcd restore workflows, kubeadm node maintenance drills, speed JSONPath challenge harnesses, CoreDNS break-fix scenarios, multi-namespace microsegmentation NetworkPolicies, faulty pod isolation autopsy patterns, and PriorityClass preemption testing, all cross-referenced with official CNCF exam documentation links.
- **Ceph Cloud-Native Storage & Dynamic StorageClasses (`roles/rook_ceph`, `roles/nfs_server`, `roles/cka_lab`, `playbooks/ceph.yml`)**: Added dual Ceph block (RBD) and shared filesystem (CephFS / CephNFS) provisioning for multi-replica ReadWriteMany workloads with dynamic StorageClasses (`03-ceph-nfs-sc.yaml`, `03-cephfs-sc.yaml`) and verification suites.
- **Control Plane CLI & Terminal Ergonomics (`roles/control_plane_tools`, `scripts/control-plane-tools.sh`)**: Configured system-wide and user bash alias (`glow="glow -s tokyo-night -w 150"`) for styled Tokyo-Night 150-column markdown rendering across `/etc/profile.d/glow.sh` and user `.bashrc`.

### Fixed

- **Kustomize Deprecated `commonLabels` Warning (`roles/cka_lab`)**: Migrated overlay `kustomization.yaml` templates to Kustomize v5 `labels` transformer directive (`includeSelectors: true`), eliminating deprecation warnings during `kubectl apply -k` and `kubectl kustomize`.
- **Vagrant Secondary Storage Volume Collisions (`Vagrantfile`)**: Configured `allow_existing: true` on the secondary disk definition (`/dev/vdb`) for `kube-control-plane` to prevent `virStorageVolCreateXML` collisions during cluster recreation.
- **Rook-Ceph CSI Provisioner Scheduling (`roles/rook_ceph`, `group_vars/all.yml`)**: Added control-plane tolerations and tuned provisioner replica counts to prevent memory exhaustion and unschedulable pod warnings on worker nodes.

## [1.4.2] - 2026-10-11

### Added

- **Confidential PowerDNS Resolvers for ACME (`roles/caddy`, `group_vars/all.yml`)**: Configured SOPS-encrypted DNS resolver settings (`caddy_resolvers` / `POWERDNS_RESOLVERS`) for Caddy's PowerDNS DNS-01 ACME challenge propagation, resolving DNS propagation timeouts in split-horizon and local LAN environments with secure file injection (`0600 root:caddy`) and `no_log: true` masking.

### Changed

- **Caddy Ingress Reverse Proxy (`group_vars/all.yml`)**: Updated default upstream Caddy version to `v2.11.7`.

## [1.4.1] - 2026-10-10

### Added

- **Dynamic NFS CSI Provisioning (`roles/nfs_csi`, `roles/cka_lab`, `playbooks/nfs_csi.yml`)**: Automated dynamic PV provisioning via the official Kubernetes SIG Storage NFS CSI Driver (`csi-driver-nfs`), supporting both production cluster rollouts (`playbooks/nfs_csi.yml`) and dedicated CKA hands-on drills (`~/cka/storage-classes/` and `~/cka/volumes/08-nfs-csi`) with ReadWriteMany shared workloads and automated test runners.
- **NGINX Gateway Fabric & Ingress Scenarios (`roles/cka_lab`)**: Comprehensive Gateway API drills with version-pinned CRDs, NodePort routing, and hostname filtering via `httpbingo`, complemented by an Ingress-NGINX practice installer for CKA exam coverage.

### Changed

- **NFS Server Export Directory (`roles/nfs_server`, `group_vars/all.yml`)**: Standardized root NFS share directory to `/exports` across lab environments, volume templates, and dynamic storage configurations.

### Fixed

- **CKA Lab Volume Directory Initialization (`roles/cka_lab`)**: Automatically create export directory paths with write permissions prior to copying sample files, ensuring clean isolated execution of `cka_lab.yml`.

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

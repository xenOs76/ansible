# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **ConfigMaps, Secrets & Pod Consumption Practice Module (`roles/cka_lab`, `~/cka/configmaps/`)**: Expanded CKA exam training lab with a comprehensive practice module synthesizing ConfigMap and Secret generation, granular environment variable binding (`valueFrom`), bulk environment variable binding with prefixes (`envFrom`), full directory volume mounts, single-file projections using `subPath`, specification immutability (`immutable: true`) with API server rejection tests, and an automated end-to-end verification test suite aligned with official Kubernetes documentation and CNCF curriculum competencies.
- **Kubernetes Secrets & Workload Consumption Practice Module (`roles/cka_lab`, `~/cka/secrets/`)**: Expanded CKA exam training lab with an end-to-end Secrets module covering imperative creation across generic, TLS, and docker-registry types, fast Base64 JSONPath and Go-template decoding, granular environment variable binding (`valueFrom.secretKeyRef`), bulk injection (`envFrom.secretRef` with prefixes), restrictive volume file permissions (`defaultMode: 0400`), NGINX HTTPS web termination, specification immutability enforcement, and an automated verification test suite.
- **Deployments & Workload Rollout Practice Module (`roles/cka_lab`, `~/cka/deployments/`)**: Expanded CKA exam training lab with an end-to-end Deployments module covering rapid imperative generation (`kubectl create deployment`, `kubectl set image`, `kubectl scale`), selector immutability diagnosis and pod quarantine autopsy debugging, zero-downtime rolling update strategy tuning (`maxSurge`, `maxUnavailable`) vs singleton `Recreate`, rollout revision history inspection with undo rollbacks, batch configuration changes via pause and resume, and an automated verification test suite.
- **Storage, Volumes & Lifecycle Practice Module (`roles/cka_lab`, `~/cka/volumes/`)**: Expanded CKA exam training lab with a comprehensive Storage module covering static PersistentVolume and PersistentVolumeClaim binding phases, live reclaim policy mutation (`Retain` vs `Delete`) with manual recovery, ephemeral and in-memory scratch storage (`emptyDir`), host filesystem mounts (`hostPath`), ConfigMap and Secret projected volume consumption, online volume expansion, and an end-to-end automated verification test suite.
- **Scheduling & Capacity Management Tutorial Guide (`roles/cka_lab`, `~/cka/05-scheduling/`)**: Enhanced the scheduling scenario master guide with an in-depth step-by-step tutorial covering node repellent taints (`NoSchedule`, `NoExecute`) and matching pod tolerations, hard and soft `nodeAffinity` with `podAntiAffinity` multi-replica spreading, Horizontal Pod Autoscaler metrics prerequisites and synthetic load generation, namespace capacity governance (`ResourceQuota` hard limits and `LimitRange` default injection/boundary enforcement), and `PriorityClass` workload preemption mechanics.
- **Kubernetes v1.35 Alignment & Upgrade Tracking (`roles/cka_lab`, `docs/`)**: Integrated Kubernetes v1.35 GA features across CKA practice drills, adding an in-place pod resource resizing verification script (`~/cka/04-pods/05-spec-immutability/inplace-resize-drill.sh`), node-local traffic routing demonstration (`trafficDistribution: PreferSameNode`), `kubeadm.k8s.io/v1beta4` configuration schema updates, and comprehensive cluster upgrade tracking documentation (`docs/cluster_upgrade_todos.md`).
- **Curriculum Architecture & Sequential Directory Numbering (`roles/cka_lab`, `~/cka/`)**: Restructured all 17 hands-on exam practice modules into a 2-digit zero-padded linear hierarchy (`01-jsonpath` through `17-cluster-troubleshooting`), ordered strictly by increasing architectural complexity and dependency prerequisites, accompanied by an interactive master index (`~/cka/README.md`) and automatic backward-compatibility symlinks for all legacy unnumbered paths.
- **Default System Editor Configuration & YAML Indentation Standards (`roles/common`, `scripts/common.sh`)**: Enforced `vim` as the cluster-wide default editor across all provisioning stages (Vagrant initial bootstrap, Ansible common role, and control plane user environments) via Debian alternatives (`update-alternatives --set editor /usr/bin/vim.basic`), system-wide profile scripts (`/etc/profile.d/editor.sh`), `/etc/environment`, user `.bashrc` profiles, and global YAML-optimized vim defaults (`set tabstop=2 shiftwidth=2 expandtab number` in `/etc/vim/vimrc.local`).
- **Networking Practice Module Tutorial Guide (`roles/cka_lab`, `~/cka/11-networking/`)**: Expanded the networking walkthrough drills with comprehensive step-by-step instructions, imperative `kubectl expose` and `kubectl create ingress` generation shortcuts, multi-port naming rules, EndpointSlice tracking, direct headless DNS resolution, Gateway API HTTPRoute URL rewriting, CoreDNS egress requirements, and multi-namespace NetworkPolicy isolation mechanics.
- **Storage & Volumes Practice Walkthrough Guide (`roles/cka_lab`, `~/cka/12-storage/`)**: Expanded the Storage domain exam walkthrough drills with manual creation instructions, imperative Pod skeleton generation patterns (`kubectl run --dry-run=client -o yaml`), 3-point PV/PVC binding criteria breakdowns, `emptyDir` sidecar sharing and in-memory `tmpfs` mounts, hostPath security permissions (`readOnly: true`, `DirectoryOrCreate`), imperative ConfigMap/Secret projected volumes with strict permissions (`defaultMode: 0400`), live PV reclaim policy mutation via `kubectl patch`, and manual volume recovery by clearing `spec.claimRef`.
- **StorageClasses & Dynamic Provisioning Practice Walkthrough Guide (`roles/cka_lab`, `~/cka/13-storage-classes/`)**: Expanded the Dynamic Provisioning exam walkthrough drills with manual StorageClass authoring, default provisioner designation via `is-default-class` annotations, detailed delayed binding diagnostics (`volumeBindingMode: WaitForFirstConsumer`), imperative consumer Pod skeletons triggering automated PV creation, live PVC storage expansion (`allowVolumeExpansion: true`), and dynamic ReadWriteMany NFS CSI shared deployment workflows.
- **Cluster Maintenance & Node Troubleshooting Walkthrough Guide (`roles/cka_lab`, `~/cka/17-cluster-troubleshooting/`)**: Expanded the master troubleshooting guide with comprehensive diagnostic workflows, safe node draining flags (`--ignore-daemonsets`, `--delete-emptydir-data`, `--force`), static pod recovery mechanics in `/etc/kubernetes/manifests/` with Container Runtime Interface (`crictl`) triage when API server is unavailable, worker node kubelet systemd diagnostics (`journalctl -u kubelet`) and `/var/lib/kubelet/config.yaml` fixes, resource telemetry sorting (`kubectl top --sort-by`), CoreDNS `Corefile` syntax recovery, service selector and targetPort mismatch triage, worker static pod placement via `staticPodPath`, and runtime engine debugging.
- **Manual Kubeadm Cluster Upgrade Walkthrough Guide (`roles/cka_lab`, `~/cka/16-upgrade/`)**: Expanded the upgrade guide with APT repository package discovery (`apt-cache madison kubeadm`), strict Kubernetes version skew rules, `kubeadm upgrade plan` diagnostic output interpretation, explicit control plane upgrade procedure (`kubeadm upgrade apply`), worker node kubelet upgrade steps (`kubeadm upgrade node`), and cluster-wide node status validation.

### Changed

- **CKA Lab Addon Prerequisites & Controller Collision Guidance (`roles/cka_lab`)**: Added explicit component prerequisite guidance and installer reminders across networking (`02-ingresses`, `03-gateway-api`, `04-network-policies`), scheduling (`03-hpa-autoscaling`), and troubleshooting (`04-metrics-monitoring`) scenarios. Documented NodePort `30080` mutual collision warnings between Ingress-NGINX and NGINX Gateway Fabric, added non-destructive prerequisite detection to `test-ingress.sh` and `test-gateway.sh`, added `nginx.ingress.kubernetes.io/rewrite-target` annotation to the Ingress template, and cross-referenced Metrics Server installer links for HPA and resource telemetry.
- **CKA Lab Tutorial Guides Markdown Rendering & Vertical Spacing (`roles/cka_lab`)**: Restructured walkthrough drill steps across the entire suite of 22 CKA scenario guides and master README templates from tight ordered list items to dedicated H4/H5 subheadings with zero-indented code blocks and strict blank line margins, ensuring clean vertical spacing and trailing paragraph separation in terminal markdown viewers (`glow`) and web interfaces.

### Fixed

- **CKA Lab Scheduling Quotas & Admission Drill (`roles/cka_lab`, `~/cka/10-scheduling/04-quotas-limits/`)**: Fixed invalid `kubectl run --limits` syntax in the capacity governance tutorial guide by introducing a dedicated manifest (`cka-lab-oversized-pod.yaml`) and documenting inline heredoc and `--overrides` methods, eliminating CLI flag parse failures and aligning with Kubernetes admission control semantics.

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

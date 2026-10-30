# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **CKA Training Lab - Advanced Kustomize Directives & Patching (`roles/cka_lab`, `~/cka/09-kustomize/`)**:
  Expanded Kustomize practice scenarios covering `secretGenerator` from key-value `.env` files, `commonAnnotations`,
  `nameSuffix`, and image transformers (`images:` with tag and digest overrides). Added exhaustive JSON 6902 RFC 6902
  patches (`replace` memory, `remove` probe, `add` sidecars, `add` environment variables, and label-targeted patches)
  alongside strategic merge patching, backed by an automated verification test suite and comprehensive options guide.
- **CKA Training Lab - Pod Topology Spread Constraints (`roles/cka_lab`, `~/cka/10-scheduling/06-topology-spread/`)**:
  Provisioned hands-on scenarios for fine-grained failure domain distribution using `topologySpreadConstraints`. Covers
  `maxSkew` calculations, `whenUnsatisfiable` policies (`DoNotSchedule` hard enforcement vs `ScheduleAnyway` soft
  balancing), and `matchLabelKeys: ["pod-template-hash"]` for rolling updates, complete with automated multi-node
  validation.
- **CKA Training Lab - In-Pod API Server Interrogation (`roles/cka_lab`, `~/cka/03-rbac/03-api-access/`)**:
  Implemented in-pod API interrogation drills using projected ServiceAccount tokens and CA certificates
  (`/var/run/secrets/kubernetes.io/serviceaccount/`). Covers core vs named API taxonomy (`/api/v1` vs `/apis`), namespace
  resource querying (`/api/v1/namespaces/{ns}/secrets`), base64 payload extraction, RBAC boundary enforcement (HTTP 403
  Forbidden), interactive inspection tooling, and `kubectl proxy` workflows.
- **CKA Training Lab - Inter-Node DNS Resolution & Passwordless SSH (`playbooks/cka_lab.yml`, `roles/cka_lab`)**:
  Automated cluster-wide `/etc/hosts` population across `k8s_cluster` and distributed a dedicated Ed25519 lab SSH
  keypair from `control_plane[0]` to all worker nodes (`~/.ssh/authorized_keys` and `~/.ssh/config`) exclusively for
  CKA training. Enables 1:1 CKA exam terminal fidelity (`ssh kube-worker-1`), eliminates DNS resolution failures during
  worker diagnostics (`break-cni.sh`, `break-kubelet.sh`), and adds dynamic Kubernetes Node API IP resolution
  fallbacks.
- **CKA Training Lab - Comprehensive Troubleshooting Drills Expansion (`roles/cka_lab`)**:
  Expanded Chapter 17 with 14 end-to-end break-fix drills covering control plane static pods (`kube-apiserver`,
  `kube-controller-manager`, `kube-scheduler`), worker node diagnostics (unparseable YAML, corrupted CRI socket,
  systemd drop-in mismatch, expired client certificates), CNI plugin recovery (`09-cni-recovery/`), RBAC authorization
  alignment (`10-rbac-recovery/`), storage & volume triage (`11-storage-recovery/`), Ingress routing triage
  (`06-service-endpoints-recovery/`), worker static mirror pod NodePort exposure, advanced scheduling taints
  (`12-scheduling-recovery/`), cluster reconnaissance (`13-cluster-recon/`), and PKI certificate renewal
  (`14-pki-certs/`).
- **CKA Training Lab - Pod Lifecycle & Upstream Dependency Probes (`roles/cka_lab`, `~/cka/04-pods/`)**:
  Added Killer.sh practice scenarios for pod lifecycle management, including upstream ClusterIP service readiness
  dependency validation via custom `exec` `readinessProbe` before marking pods Ready.
- **CKA Training Lab - Network Policies & Hubble Diagnostics (`roles/cka_lab`, `~/cka/11-networking/`)**:
  Restored comprehensive CKA NetworkPolicy scenarios covering default-deny ingress, client pod ingress allow rules,
  CoreDNS egress, and database egress restrictions. Includes real-time packet drop troubleshooting via Hubble CLI
  (`hubble observe --verdict DROPPED`) and non-interactive automated verification.
- **CKS Training Lab - Pod-to-Pod Security & Network Policies (`roles/cks_lab`, `~/cks/network-policies/`)**:
  Provisioned comprehensive CKS exam practice scenarios covering basic isolation and cloud metadata protection
  (`01-basic-isolation/`, `169.254.169.254/32` via `ipBlock.except`), progressive zero-trust microsegmentation
  (`02-progressive-microsegmentation/`), multi-tenant cross-namespace boundaries (`03-multi-tenant-isolation/`),
  and static policy auditing via `kubectl-cyclonus` (`04-policy-analysis-cyclonus/`). Includes non-interactive
  automated test suites, self-contained microservice test workloads, and Cilium Hubble eBPF drop analysis guides.
- **Krew & kubectl-cyclonus Tooling (`roles/control_plane_tools`, `scripts/control-plane-tools.sh`)**:
  Integrated `krew` (`v0.5.0`) kubectl plugin manager and `kubectl-cyclonus` (`v0.2.1`) NetworkPolicy analyzer into
  control plane bootstrap automation across Ansible tasks, Vagrant shell provisioning, user environment profile
  (`PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"`), and CKA training lab playbooks and scenario guides.
- **CKA Shell Shortcuts & etcdctl TLS Alias (`roles/control_plane`, `roles/cka_lab`)**:
  Added standard CKA productivity shortcuts and aliases across control plane shell profiles
  (`/etc/profile.d/k8s-completion.sh`, `~/.bashrc`) and the initial steps reminder MOTD (`~/cka` / `~/.motd`). Includes
  dry-run manifest generator (`export kdo="--dry-run=client -o yaml"`), fast deletion (`export know="--force
  --grace-period=0"`), and pre-configured static pod TLS alias for `etcdctl`.
- **Cilium Hubble CLI Installation & Vagrant Provisioning (`scripts/cni-install-hubble.sh`, `roles/cilium`)**:
  Added automated Hubble CLI installation script (`cni-install-hubble.sh`) with official upstream release checksum
  verification and optional cluster enablement. Co-located with `cni-install-cilium.sh` in repository `scripts/`,
  Vagrant VM provisioning (`/home/vagrant/cni-install-hubble.sh`), and the Ansible `cilium` role.

### Changed

- **CKA vs CKS Network Policy Curriculum Separation (`roles/cka_lab`, `roles/cks_lab`)**:
  Refined curriculum boundaries: CKA focuses on standard functional NetworkPolicy isolation (ingress/egress selectors,
  port rules, and Hubble packet drop analysis), while CKS focuses on hardened zero-trust security (cloud metadata
  endpoint isolation `169.254.169.254/32` and automated Cyclonus matrix auditing).
- **Static Pod Troubleshooting & Canary Diagnostics (`roles/cka_lab`, `02-static-pod-recovery/`)**:
  Modernized the control plane static pod recovery drill with multi-scenario failure injection (`--scenario=kubeconfig`,
  `mount`, `syntax`), automated canary workload verification (`cka-scheduler-probe`), robust recovery scripting
  (`fix-scheduler.sh`), automated self-testing (`test-static-pod-recovery.sh`), and real-world incident post-mortem
  citations from `hjacobs/kubernetes-failure-stories`, OpenAI, Datadog, and CNCF curriculum standards.
- **Storage Decoupling & Baseline Streamlining (`roles/common`, `playbooks/site.yml`, `scripts/common.sh`)**:
  Removed optional storage layers from the default baseline cluster installation to accelerate provisioning and simplify
  maintenance. Ceph (`rook_ceph`, `rbd.ko`) and iSCSI (`open-iscsi`, `iscsi_tcp.ko`, `iscsid.service`) are now strictly
  on-demand auxiliary layers with self-contained module and service preparation in `playbooks/ceph.yml` (`make
  preprod-ceph`) and `playbooks/iscsi.yml` (`make preprod-iscsi`). Classic NFS (`nfs-common`, `nfs-kernel-server`)
  remains the guaranteed core storage baseline.
- **Cross-Namespace Gateway Architecture & Simplified Network Policies (`roles/cka_lab`, `~/cka/11-networking`)**:
  Moved the Gateway resource to the dedicated infrastructure namespace (`nginx-gateway`) with cross-namespace routing
  allowed. Eliminated internal proxy lockdown boilerplate in tenant namespace `default`, reducing tenant policies to
  two clean cross-namespace rules: ingress to `httpbingo:8080` from `nginx-gateway` and egress to `nginx-gateway:80`
  from client pods. Updated `test-gateway.sh` and `test-advanced-netpol.sh` test suites, and documented in-cluster and
  external verification procedures in `README.md`.
- **Terminal Ergonomics & Walkthrough Guide Formatting (`roles/cka_lab`)**:
  Replaced wide multi-column markdown tables with structured incident and remediation lists across static pod and
  networking walkthrough guides for optimal rendering in `glow` terminal viewer, and updated the CKA master index.

### Fixed

- **Kubelet Diagnostics Drill & Modern Failure Injection (`roles/cka_lab`, `03-kubelet-diagnostics/`)**:
  Fixed `break-kubelet.sh` where injecting `cgroupDriver: invalidDriverName` into `/var/lib/kubelet/config.yaml`
  had no effect in Kubernetes v1.34+ due to `KubeletCgroupDriverFromCRI` reaching GA status and ignoring the field.
  Replaced with authentic multi-scenario failure injection (`--scenario=config` with unparseable YAML syntax in
  `config.yaml`, `--scenario=cri` with corrupted CRI runtime socket in `kubeadm-flags.env`, and `--scenario=systemd`
  with invalid config path in `10-kubeadm.conf`), added defensive verification to ensure service failure detection,
  and updated `fix-kubelet.sh` and guide documentation to restore all configuration layers.
- **Static Pod Failure Drills & Backup Path Isolation (`roles/cka_lab`, `02-static-pod-recovery/`)**:
  Fixed static pod recovery drills (`break-scheduler.sh`, `break-controller-manager.sh`, `break-apiserver.sh`) where
  manifest backups stored inside `/etc/kubernetes/manifests/*.bak` caused kubelet to parse and run the healthy backup
  manifest, preventing failure simulation. Relocated backup files outside the manifests directory
  (`/etc/kubernetes/*.yaml.bak`), added immediate container process reload (`crictl stop`), and ensured canary workloads
  consistently reflect scheduling and replica stalls.
- **Headless Service & Advanced Netpol Test Harnesses (`roles/cka_lab`, `~/cka/11-networking`)**:
  Corrected the headless service manifest path in `test-headless.sh` to match `cka-lab-headless-service.yaml`, and
  added pre-test cleanup to `test-advanced-netpol.sh` to prevent stale policies from invalidating baseline checks.

## [1.5.2] - 2026-10-20

### Changed

- **CKA Lab Execution Scope Optimization (`playbooks/cka_lab.yml`)**:
  Restricted CKA lab scenario deployment play to `control_plane[0]` instead of all control plane nodes. In HA
  topologies, staging `~/cka` and executing practice resource drills is now scoped exclusively to the primary
  controller (`kube-cp-1`), preventing redundant execution, unnecessary fact gathering, and duplicate drills across
  secondary control plane nodes.

## [1.5.1] - 2026-10-20

### Added

- **Pre-Upgrade API Deprecation Auditing & Two-Tier Simulation (`roles/cka_lab`, `~/cka/16-upgrade/`)**:
  Integrated Fairwinds Pluto pre-upgrade deprecation scanning as Phase 0 (`00-pre-upgrade-deprecations/`) before node
  upgrades. Implemented a two-tier architecture: Tier 1 offline static manifests and synthetic Helm release secrets for
  Pluto audits targeting Kubernetes v1.37 (`--target-versions k8s=v1.37.0`), and Tier 2 live loadable v1.36 resources
  (practice `AppService` CRD with deprecated `v1beta1` and GA `v1`, native `Service.spec.externalIPs`, and
  `Pod.spec.serviceAccount`) with automated loader, cleanup, and Prometheus metric auditing.
- **Chronological Node Upgrade Order Enforcement (`roles/cka_lab`, `~/cka/16-upgrade/`)**:
  Restructured upgrade drill workflow to strictly enforce all control planes (primary and secondary) reaching target
  version parity before worker node maintenance: Phase 0 Pre-Upgrade Deprecations, Phase 1 Primary Control Plane, Phase 2
  Secondary Control Planes, and Phase 3 Worker Nodes.

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

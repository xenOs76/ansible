# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Automated, idempotent installation of `etcdctl` and `etcdutl` (defaulting to
  `v3.5.16`) on the control plane node during `make preprod-up` provisioning.
- Added `etcd_tools.yml` tasks to the `control_plane_tools` Ansible role with
  system architecture detection and version-pinned archive extraction from official
  GitHub releases.
- Configured system-wide `ETCDCTL_API=3` via `/etc/profile.d/etcd.sh` for all
  interactive and login shells on the control plane VM.
- Added `ETCD_VERSION` environment variable lookup in `Vagrantfile` and
  `control_plane_tools_etcd_version` in Ansible role defaults.
- Documented CKA etcd health check and snapshot verification commands in `README.md`.
- Added `make preprod-cka-lab` target and dedicated `cka_lab` Ansible role (`playbooks/cka_lab.yml`) for provisioning isolated CKA training scenarios on the preprod control plane.
- Implemented CKA training scenario `user_rbac`: provisions Linux user `anna` with `sudo` group membership, generates 2048-bit RSA key and CSR in `/home/anna/certs`, signs client certificate using the cluster's local CA (`/etc/kubernetes/pki/ca.crt`), and configures `/home/anna/.kube/config` with active context `anna@kubernetes`.

### Changed

- Updated default preprod worker node count from 1 to 2 in `Vagrantfile`, added
  `kube-worker-2` (`192.168.56.22`) to `inventory/preprod/hosts.ini`, and updated
  topology references across documentation and helper scripts.
- Rewrote `scripts/sync-kubeconfig.sh` using native `kubectl config` subcommands and
  defensive Bash patterns: eliminated all Python dependencies and nested `nix-shell` launches,
  reducing execution time to ~1s. The script dynamically resolves the control plane endpoint
  from inventory or source config, configures certificate trust via `--insecure-skip-tls-verify=true`,
  and merges credentials into `~/.kube/config`.

### Fixed

- Fixed `scripts/sync-kubeconfig.sh` incorrectly synchronizing stale credentials
  from previous cluster deployments when running `make preprod-up`. The script
  now validates that the control plane VM is running and confirms that
  `/etc/kubernetes/admin.conf` actually exists inside the VM before attempting
  synchronization, properly invalidating stale cached files on the host.
- Fixed `scripts/sync-kubeconfig.sh` not resolving the control plane address from
  the Ansible inventory, causing preprod connections to fail against internal NAT IPs
  instead of the static management network address (`192.168.56.10`).
- Fixed kube-apiserver TLS certificate SAN mismatch (`x509: certificate is valid for 10.96.0.1, 192.168.121.117, not 192.168.56.10`) by adding `--apiserver-cert-extra-sans` to the `control_plane` Ansible role (`defaults/main.yml`, `tasks/main.yml`), `scripts/control-plane.sh`, and `README.md`. Added automatic SAN drift detection and non-destructive certificate re-issuance to the Ansible `control_plane` role.
- Added automatic cleanup of `admin.conf` and `kubeconfig.preprod` to `make preprod-destroy`.

## [1.2.0] - 2026-09-27

### Added

- Added `control_plane_tools` role to install Helm via official Debian/Ubuntu
  APT repository, k9s via official release `.deb` package, and stage
  `install-kube-metrics.sh` during cluster bootstrap.
- Added `scripts/install-kube-metrics.sh` helper script to deploy the
  Kubernetes Metrics Server Helm chart with `--kubelet-insecure-tls`.
- Integrated control plane tooling bootstrap phase into `playbooks/site.yml`
  and `playbooks/bootstrap.yml`.
- Added `install-kube-metrics.sh` and `control-plane-tools.sh` to `Vagrantfile`
  provisioning for the control plane VM.
- Added `scripts/sync-kubeconfig.sh` helper script and Makefile targets
  `preprod-sync-kubeconfig` and `prod-sync-kubeconfig` to non-disruptively
  synchronize cluster credentials to local `~/.kube/config`.
- Integrated environment-aware context naming configured via Ansible
  `group_vars` (`k8s_context_name`, `cluster_name`, `k8s_user_name`),
  defaulting to `k8s-homelab-preprod` for preprod and `k8s-homelab` for prod.
- Integrated automated credential staging and synchronization into
  `playbooks/site.yml`.
- Automatically invoke `scripts/sync-kubeconfig.sh --best-effort` at the
  completion of `make preprod-up` to ensure credentials stay up to date.
- Added comprehensive header docstrings, parameter specifications, and usage
  examples across all homelab helper scripts under `scripts/`.

### Fixed

- Improved `scripts/sync-kubeconfig.sh` with robust `admin.conf` staging, dynamic
  TLS server address resolution with reachable IP probing, and mode-aware sync.
- Refined Helm repository setup to verify GPG key fingerprints and reject extra
  primary keys.

## [1.1.0] - 2026-09-23

### Added

- OS76 custom APT repository configuration (`https://repo.os76.xyz/apt`) and
  automated installation of `kubectl-netdrill` plugin.
- Automated generation of `/etc/crictl.yaml` in the `containerd` role and
  `scripts/common.sh`.
- Makefile target `make preprod-provision` to re-run Vagrant provisioners on
  running VMs.
- Makefile target `make preprod-recreate` to cleanly destroy and boot fresh VMs
  in one step.
- Variable `playbook_version` in `group_vars/all.yml` and startup version
  announcement play in `playbooks/site.yml`.

### Changed

- Flattened directory layout: moved `Vagrantfile` to `k8s-homelab/` root and
  consolidated all helper scripts under `scripts/`.
- Unified Nix development environment into root `shell.nix`.
- Renamed all preprod playbook Makefile targets with consistent `preprod-`
  prefix (`preprod-deploy`, `preprod-cni`, `preprod-upgrade`, `preprod-reset`).

### Fixed

- Fixed `kubelet` journal error on worker nodes (`Unable to read config path
  /etc/kubernetes/manifests`) by ensuring the manifests directory is created
  with mode `0755`.
- Eliminated `crictl` deprecated endpoint warnings across cluster nodes.

### Removed

- Removed redundant `make bootstrap` target in favor of `make preprod-up` and
  direct playbook invocation.

## [1.0.0] - 2026-09-20

### Added

- Initial release of modular, production-grade Ansible automation for Kubernetes
  (`kubeadm` + `containerd` + `Cilium`).
- Ansible roles: `common`, `containerd`, `kubernetes_packages`, `control_plane`,
  `worker`, `cilium`, `upgrade`, `reset`.
- Multi-node preprod virtualization environment using Vagrant + Libvirt
  (KVM/QEMU).
- CKA training workflows: cluster deployment, rolling upgrade, ETCD
  backup/restore, and sub-minute cluster reset.
- Automated code quality validation via `yamllint` and `ansible-lint`
  (`production` profile).

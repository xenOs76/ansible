# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

# Changelog

All notable changes to the `k8s-homelab` Kubernetes Ansible automation
suite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added `glow` markdown CLI viewer installation to the CKA lab provisioning phase (`roles/cka_lab/tasks/scenario_glow.yml`):
  - Configures Charmbracelet's official APT repository (`https://repo.charm.sh/apt/`) with GPG key validation (`ED927B38BE981E53CA09153D03BBF595D4DFD35C`) and dearmored keyring at `/etc/apt/keyrings/charm.gpg`.
  - Installs `glow` on the control plane node to enable terminal-based rendering and reading of CKA drill guides with rich formatting.
- Implemented Rook-Ceph block storage orchestration (`roles/rook_ceph`):
  - Added dedicated role `roles/rook_ceph` to deploy the official Rook-Ceph operator (pinned Helm chart `v1.15.5`) and configure a Ceph cluster where block storage is provided from a dedicated unformatted volume on the control plane node.
  - Configured `CephCluster` with control plane placement and tolerations (`node-role.kubernetes.io/control-plane:NoSchedule`), single MON/MGR daemons, and target block devices (`rook_ceph_devices`).
  - Configured `CephBlockPool` (`replicapool`) with `failureDomain: osd`, single replica (`replicated.size: 1`), and `requireSafeReplicaSize: false` for single-node OSD topology.
  - Registered dynamic Kubernetes StorageClass `rook-ceph-block` backed by `rook-ceph.rbd.csi.ceph.io` with volume expansion enabled.
  - Updated `Vagrantfile` allocating 4096MB RAM and attaching a dedicated 20GB secondary disk (`/dev/vdb`) to `kube-control-plane`.
  - Added `rbd` kernel module persistence and initialization to `roles/common` (`k8s-modules.conf.j2`, `tasks/main.yml`) and `scripts/common.sh`.
  - Added standalone deployment script `scripts/install-rook-ceph.sh` and end-to-end worker volume verification drill `test-ceph-storage.sh`.
  - Added dedicated playbook `playbooks/ceph.yml`, integrated step into `playbooks/site.yml`, and added Makefile targets `preprod-ceph` and `prod-ceph`.

## [1.3.0] - 2026-10-02

### Added

- Implemented CKA training scenario `scheduling` (`roles/cka_lab/tasks/scenario_scheduling.yml`) covering node scheduling constraints, pod spreading, autoscaling, and namespace capacity governance:
  - `01-taints-tolerations/`: Applying and removing `NoSchedule` taints to nodes and configuring matching pod tolerations (`cka-lab-tolerating-pod`, `cka-lab-intolerant-pod`).
  - `02-affinities/`: Hard and soft `nodeAffinity` matching expressions (`cka-lab-node-affinity-pod`), and multi-replica hostname spreading via `podAntiAffinity` (`cka-lab-anti-affinity-deploy`).
  - `03-hpa-autoscaling/`: Dynamic pod replica autoscaling using `autoscaling/v2` based on target CPU utilization (`cka-lab-autoscale-app`, `cka-lab-hpa`).
  - `04-quotas-limits/`: Namespace boundary enforcement using `ResourceQuota` (`cka-lab-compute-quota`) and default limit/request injection via `LimitRange` (`cka-lab-limit-range`).
  - Added master guide `/home/vagrant/cka/scheduling/README.md` and automated test suite (`test-scheduling-drills.sh`).
- Implemented CKA training scenario `workloads_advanced` (`roles/cka_lab/tasks/scenario_workloads_advanced.yml`) covering background node daemons, batch workloads, and coordinated multi-container pods:
  - `01-daemonsets/`: Deploying node agents across all cluster nodes with control plane tolerations and hostPath inspection (`cka-lab-log-collector-ds`).
  - `02-batch-jobs/`: Parallel batch jobs (`cka-lab-parallel-job` with completions and parallelism) and scheduled CronJobs (`cka-lab-cronjob`).
  - `03-multi-container/`: Gated sequential initialization via `initContainers` (`cka-lab-init-pod`), and native persistent helper execution via Kubernetes 1.28+ native sidecar containers (`cka-lab-native-sidecar-pod` with `restartPolicy: Always`).
  - Added master guide `/home/vagrant/cka/workloads-advanced/README.md` and automated test suite (`test-workloads-advanced-drills.sh`).
- Implemented CKA training scenario `storage_classes` (`roles/cka_lab/tasks/scenario_storage_classes.yml`) covering dynamic storage provisioners, StorageClasses, and dynamic PVC lifecycles:
  - `01-provisioners/`: Deploying Rancher's lightweight `local-path-provisioner` (`install-local-path-provisioner.sh`).
  - `02-storage-classes/`: Configuring `reclaimPolicy` (`cka-lab-sc-retain` vs `cka-lab-sc-delete-wait`), delayed binding (`volumeBindingMode: WaitForFirstConsumer`), dynamic PVC binding upon first pod consumer (`cka-lab-dynamic-pvc`, `cka-lab-storage-consumer`), and PVC volume expansion.
  - Added master guide `/home/vagrant/cka/storage-classes/README.md` and automated test suite (`test-storage-classes-drills.sh`).
- Implemented CKA training scenario `cluster_troubleshooting` (`roles/cka_lab/tasks/scenario_cluster_troubleshooting.yml`) covering safe cluster node maintenance workflows, control plane static pod recovery, and resource telemetry:
  - `01-node-maintenance/`: Non-interactive node cordoning (`kubectl cordon`), workload eviction (`kubectl drain --ignore-daemonsets --delete-emptydir-data`), and return to service (`kubectl uncordon`).
  - `02-static-pod-recovery/`: Diagnosing and repairing corrupted control plane manifests in `/etc/kubernetes/manifests/` using `crictl` and system logs (`break-scheduler.sh`, `fix-scheduler.sh`, `break-apiserver.sh`, `fix-apiserver.sh`).
  - `03-kubelet-diagnostics/`: Interactive break-fix drills for diagnosing and repairing worker node systemd `kubelet.service` failures and configuration syntax errors (`break-kubelet.sh`, `fix-kubelet.sh`).
  - `04-metrics-monitoring/`: Live node and pod CPU/memory consumption inspection using `kubectl top nodes` and `kubectl top pods` (`test-metrics-top.sh`).
  - Added master guide `/home/vagrant/cka/cluster-troubleshooting/README.md` and automated test suite (`test-cluster-troubleshooting.sh`).
- Implemented CKA training scenario `crds` (`roles/cka_lab/tasks/scenario_crds.yml`) covering CustomResourceDefinition schemas, OpenAPI v3 structural validation, and custom resource lifecycle:
  - `01-crd-schema/`: Declaring group, version, kind, shortNames, additional printer columns, and OpenAPI v3 structural validation rules (`backupschedules.automation.cka.priv`).
  - Declarative custom resource instances (`cka-lab-daily-backup`) and automated admission webhook rejection testing on malformed specs.
  - Added master guide `/home/vagrant/cka/crds-operators/README.md` and automated test suite (`test-crds-drills.sh`).
- Implemented CKA training scenario `chaos_troubleshooting` (`roles/cka_lab/tasks/scenario_chaos_troubleshooting.yml`) covering on-demand dynamic runtime resilience and failure diagnostics via Headless LitmusChaos:
  - Minimal operator architecture without UI/MongoDB portal (`install-litmus-headless.sh`), maintaining a minimal ~60MB footprint suited for 2GB homelab worker VMs.
  - `01-memory-oom/`: Container memory starvation and cgroup OOMKilled diagnosis (`pod-memory-hog`), inspecting ExitCode 137, and adjusting deployment memory limits.
  - `02-network-latency/`: Inter-pod packet loss and timeout degradation (`pod-network-loss`), troubleshooting connectivity with ephemeral debug containers (`kubectl debug`).
  - `03-dns-chaos/`: Service discovery blackholing (`pod-dns-error`), investigating CoreDNS query paths and resolver configurations.
  - `04-node-pressure/`: Node memory saturation (`node-memory-hog`), analyzing `MemoryPressure` node conditions and QoS-based pod eviction prioritization.
  - Interactive drill launcher (`start-chaos-exercise.sh`), resolution verifier (`verify-chaos-exercise.sh`), and safe cleanup teardown (`stop-chaos-exercise.sh`).
  - Added master guide `/home/vagrant/cka/chaos-troubleshooting/README.md`, automated verification suite (`test-chaos-drills.sh`), and `make preprod-cka-chaos` target.

- Implemented CKA training scenario `networking` (`roles/cka_lab/tasks/scenario_networking.yml`) covering Service discovery and routing (`ClusterIP`, `NodePort`, multi-port endpoints, CoreDNS FQDN resolution), Ingress traffic routing with path-based and host-based rules, Gateway API architecture (`GatewayClass`, `Gateway`, and `HTTPRoute` integrated with NGINX Gateway Fabric and Caddy port 443 reverse proxy), and multi-tier NetworkPolicy enforcement (`default-deny-ingress`, namespace/pod selector ingress isolation, and egress rules preserving CoreDNS port 53).
- Scaffolded comprehensive networking manifests and non-interactive drills under `/home/vagrant/cka/networking/`:
  - `01-services/`: `cka-lab-backend-app` deployment, `cka-lab-clusterip-svc` (multi-port HTTP/metrics), `cka-lab-nodeport-svc` (NodePort 31080/31090), and verification script (`test-services.sh`).
  - `02-ingresses/`: `cka-lab-ingress-backends` (v1/v2), `cka-lab-ingress` with prefix path routing, and verification script (`test-ingress.sh`).
  - `03-gateway-api/`: `cka-lab-gateway` bound to `nginx` GatewayClass, `cka-lab-httproute` routing path `/api` to `httpbin-go` and `/` to backend, Caddy integration guide (`caddy-integration.md`), and automated Gateway probe script (`test-gateway.sh`).
  - `04-network-policies/`: isolated namespaces (`cka-lab-backend-ns`, `cka-lab-client-ns`), `cka-lab-backend-server` workload, client test pods (`cka-lab-allowed-client`, `cka-lab-blocked-client`), `cka-lab-default-deny-ingress` policy, `cka-lab-allow-client-to-backend` policy, `cka-lab-allow-egress-dns` policy, and end-to-end policy matrix verification script (`test-network-policies.sh`).
- Added master networking guide `/home/vagrant/cka/networking/README.md` and automated non-interactive end-to-end drill suite (`test-networking-drills.sh`).

- Implemented CKA training scenario `pods` (`roles/cka_lab/tasks/scenario_pods.yml`) covering imperative and declarative Pod management, lifecycle phase and container state diagnostics, stdout/stderr observability, ephemeral troubleshooting probes, spec immutability workflows, and namespace context preferences.
- Scaffolded comprehensive Pods and Namespaces exam practice manifests and interactive drills under `/home/vagrant/cka/pods/`: imperative command generation (`run-imperative.sh`), declarative manifests (`cka-lab-web-service`, `cka-lab-batch-task`), finite and failing lifecycle tasks (`cka-lab-finite-worker`, `cka-lab-failing-worker`), telemetry and container exec drills (`debug-drill.sh`), ephemeral network probes (`test-connectivity.sh` against `cka-lab-echo-server`), spec immutability replacement drills (`replace-drill.sh` for `cka-lab-immutable-app`), and namespace context preferences (`namespace-context-drill.sh` for `cka-lab-staging`).
- Added master guide `/home/vagrant/cka/pods/README.md`, lifecycle deep-dive `02-lifecycle-and-restarts/README.md`, and automated test suite (`test-pods-drills.sh`).

- Implemented CKA training scenario `deployments` (`roles/cka_lab/tasks/scenario_deployments.yml`) covering Kubernetes Deployment primitives, ReplicaSet controllers, rollout lifecycle management, update strategies, and configuration troubleshooting.
- Scaffolded comprehensive Deployments and ReplicaSets exam practice manifests and interactive drills under `/home/vagrant/cka/deployments/`: declarative creation (`cka-lab-web-frontend`, `cka-lab-api-service`), selector mismatch troubleshooting and immutability diagnostics (`cka-lab-order-processor`), rolling updates with revision undo (`cka-lab-catalog-service`), rollout strategies (`RollingUpdate` zero-downtime/burst vs `Recreate`), and pause/resume batch configuration updates (`cka-lab-batch-pipeline`).
- Added master guide `/home/vagrant/cka/deployments/README.md`, troubleshooting walkthrough `02-troubleshooting-labels/README.md`, interactive drills (`rollout-drill.sh`, `pause-resume-drill.sh`), and automated test suite (`test-deployments-drills.sh`).
- Added automated `apt-get upgrade` step at the end of the VM provisioning phase (`Vagrantfile` shell provisioner, `scripts/common.sh`, and `roles/common/tasks/main.yml`) ensuring base OS packages are upgraded to current security fixes while preserving held Kubernetes binaries.

- Implemented CKA training scenario `volumes` (`roles/cka_lab/tasks/scenario_volumes.yml`): provisions an NFS server (`nfs-kernel-server`) on `kube-control-plane` exporting `/srv/nfsroot` with sample data (`index.html`, `shared-data.txt`, `reports/cluster-nodes.txt`) to the Kubernetes worker subnet (`192.168.56.0/24`).
- Configured automated `nfs-server.local` DNS host mapping in `/etc/hosts` and `nfs-common` client package across all cluster nodes (`playbooks/cka_lab.yml` and `roles/common/tasks/main.yml`).
- Scaffolded comprehensive CKA storage and volume exam practice manifests under `/home/vagrant/cka/volumes/`: direct inline NFS Pod mounts, multi-replica Nginx shared storage (`ReadWriteMany`), static PersistentVolume/PersistentVolumeClaim binding, multi-container `emptyDir` sidecars, in-memory `emptyDir` tmpfs, `hostPath` (`DirectoryOrCreate` and `/var/log` inspection), projected ConfigMap and Secret volumes with custom permissions, and PVC volume expansion.
- Added `/home/vagrant/cka/volumes/README.md` guide and automated end-to-end verification script (`test-nfs-mounts.sh`).

- Implemented Caddy ingress reverse proxy role (`roles/caddy`) with automated compilation via `xcaddy` (`v0.4.4`) to include the PowerDNS DNS-01 provider plugin (`github.com/caddy-dns/powerdns`).
- Added Caddy status test script (`check-caddy-status.sh` with convenience symlink `test-caddy-status.sh`) in the home directory of the control plane user (`/home/vagrant`), executing `https-wrench certinfo --tls-endpoint 127.0.0.1:443 --tls-info --tls-servername <domain>` to verify certificate negotiation and SNI endpoint health.
- Added `https-wrench` package to custom OS76 APT repository dependencies in `group_vars/all.yml` and `roles/caddy/tasks/prerequisites.yml`.
- Added Garage S3 binary caching for Caddy (`s3://os76-assets/caddy/...` via `amazon.aws.s3_object`), checking for existing binaries before compiling to eliminate CPU-intensive builds on subsequent installations, uploading newly compiled binaries automatically, with encrypted S3 credentials managed via SOPS in `secrets.sops.yaml`.
- Configured Caddy to terminate TLS on port 443 with Let's Encrypt certificates managed via PowerDNS DNS-01 challenges and reverse proxy requests for `*.k8s-pre.os76.xyz` (preprod) and `*.k8s.os76.xyz` (prod) to cluster nodes on NodePort `30443`.
- Added upstream Caddy release notifier (`tasks/check_version.yml`) querying the GitHub API during playbook execution to detect and announce when a newer Caddy release is available upstream.
- Integrated Caddy ingress deployment into the main deployment pipeline (`playbooks/site.yml` step 6) and added standalone playbook `playbooks/caddy.yml` and Makefile target `make preprod-caddy` for isolated execution and CKA lab practice.
- Configured SOPS secrets encryption with multi-recipient Age keys (`xeno@zero`, `xeno@nemo`, `server_zero`, `server_nemo` via `.sops.yaml`) for transparent in-memory secret decryption in Ansible via `community.sops.sops`.
- Added `README.sops.md` documenting manual workflows for inspecting, editing, creating, and re-keying SOPS-encrypted files.
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
- Implemented CKA training scenario `user_rbac`: provisions Linux user `anna` with `sudo` group membership, generates 2048-bit RSA key and CSR in `/home/anna/certs`, signs client certificate via Kubernetes `CertificateSigningRequest` (`certificates.k8s.io/v1`) with `kubectl certificate approve`, and configures `/home/anna/.kube/config` with active context `anna@kubernetes`.
- Implemented CKA training scenario `secrets` (`scenario_secrets.yml`): provisions sample Secrets across `default` and `development` namespaces covering `Opaque`, `kubernetes.io/basic-auth`, and `kubernetes.io/ssh-auth` types, base64 data encoding, and copies the rendered manifest to `/home/vagrant/cka/secrets/sample-secrets.yaml`.
- Implemented CKA training scenario `configmaps` (`scenario_configmaps.yml`): dynamically renders sample ConfigMaps across `default` and `development` namespaces via Jinja2 iteration over structured definitions (`cka_lab_configmaps_definitions`), outputting both a combined manifest (`sample-configmaps.yaml`) and individual per-ConfigMap YAML files into `/home/vagrant/cka/configmaps/{default,development}/`.
- Added self-contained Kustomize training lab in `/home/vagrant/cka/kustomize/` featuring `base/`, `overlays/development/`, and `overlays/production/`, with a comprehensive `README.md` guide covering `configMapGenerator`, `behavior: merge`, `disableNameSuffixHash`, name prefixes, common labels, strategic merge patches, and CKA/CKAD exam drills.
- Implemented CKA training scenario `helm` (`scenario_helm.yml`): provisions `/home/vagrant/cka/helm/` containing `install-kube-metrics.sh` (Metrics Server with `--kubelet-insecure-tls`) and `install-kube-prometheus.sh` (lightweight Prometheus Operator deployment with Grafana, Alertmanager, node-exporter, and kube-state-metrics disabled).
- Added `/home/vagrant/cka/helm/README.md` guide explaining Helm addon deployment, verification via `kubectl top` and Prometheus port-forwarding, and CKA drills.
- Added NGINX Gateway Fabric Helm installer script (`install-nginx-gateway-fabric.sh`) to the `cka_lab` Helm scenario (`roles/cka_lab/templates/helm_install_nginx_gateway_fabric.sh.j2`), deploying the official OCI Helm chart (`oci://ghcr.io/nginx/charts/nginx-gateway-fabric`) with automatic Gateway API CRD prerequisite provisioning, host port bindings, and deterministic NodePort configurations (`30080` for HTTP and `30443` for HTTPS).
- Added httpbin-go Helm installer script (`install-httpbin-go.sh` with convenience symlink `install-httpbingo.sh`) to the `cka_lab` Helm scenario (`roles/cka_lab/templates/helm_install_httpbin_go.sh.j2`), deploying `mccutchen/go-httpbin` via `estahn/httpbingo` with minimal resource requests (10m CPU / 16Mi RAM) for hands-on Gateway API, Ingress, and NetworkPolicy CKA drills.
- Added automatic IPv4 interface address discovery to the `control_plane` Ansible role, automatically including all VM network interface IPs in the kube-apiserver TLS certificate SANs and propagating `admin.conf` to the SSH user's home directory (`~/.kube/config`).
- Added `create-user-context.sh` script and practice guide in `/home/vagrant/cka/rbac/` (with convenience symlink in `/home/vagrant/cka/`) during the CKA lab provisioning phase, following the `bmuschko/cka-crash-course` (Exercise 04) pattern to generate private keys, request and approve CSR certificates, and add a minimal-permission user context (`vagrant`) to `~/.kube/config`.
- Added CKA training initial steps reminder MOTD (`~/.motd` and `/etc/update-motd.d/99-cka-training`) activated during `make preprod-cka-lab` (`roles/cka_lab`) to guide trainees through manual preliminary setup drills (~/.kube backup, kubectl completion, alias k, completion for k, and safe deletion via ~/.kube/kuberc).
- Automated user shell preferences (autocompletion, `k` alias, `export koyaml="--dry-run=client -o yaml"`, and `~/.kube/kuberc` interactive deletion) during the Ansible cluster initialization phase (`roles/control_plane`, triggered by `make preprod-deploy`), with automatic cleanup of `~/.motd`.

### Changed

- Upgraded `k9s` to `v0.51.0` (from `v0.40.10`) across Ansible group variables, `control_plane_tools` defaults, and provisioning scripts. Added pre-configured transparent `nord` and `transparent` skins in `~/.config/k9s/skins/` to eliminate opaque background rendering over SSH sessions.
- Updated default preprod worker node count from 1 to 2 in `Vagrantfile`, added

  `kube-worker-2` (`192.168.56.22`) to `inventory/preprod/hosts.ini`, and updated
  topology references across documentation and helper scripts.

- Rewrote `scripts/sync-kubeconfig.sh` using native `kubectl config` subcommands and
  defensive Bash patterns: eliminated all Python dependencies and nested `nix-shell` launches,
  reducing execution time to ~1s. The script dynamically resolves the control plane endpoint
  from inventory or source config, configures certificate trust via `--insecure-skip-tls-verify=true`,
  and merges credentials into `~/.kube/config`.
- Moved `install-kube-metrics.sh` from the control plane VM home root (`/home/vagrant/`) to the CKA practice environment at `/home/vagrant/cka/helm/install-kube-metrics.sh`.
- Updated `scripts/help.sh` to reference `./cka/helm/install-kube-metrics.sh` and `./cka/helm/install-kube-prometheus.sh`.

### Removed

- Removed `install-kube-metrics.sh` file provisioning from `Vagrantfile` during `make preprod-up`.
- Removed `kube_metrics.yml` tasks, installer script file, and `control_plane_tools_script_dest` from the `control_plane_tools` Ansible role and `group_vars/all.yml`.

### Fixed

- Fixed LitmusChaos `ChaosExperiment not found` error during chaos drill executions by updating the generic experiments manifest URL to raw GitHub (`faults/kubernetes/experiments.yaml`), replacing the deprecated ChaosHub endpoint. Added defensive auto-provisioning of missing experiment CRDs inside `start-chaos-exercise.sh`.
- Fixed `litmus-admin` ServiceAccount and RBAC errors in application namespaces by embedding the dedicated `ServiceAccount` and `ClusterRoleBinding` directly into `00-target-app/target-app.yaml`, allowing the Chaos runner pod to operate seamlessly within `cka-troubleshooting`.
- Fixed container runtime integration in dynamic OOM chaos drills: configured `CONTAINER_RUNTIME: containerd`, `SOCKET_PATH: /run/containerd/containerd.sock`, and explicit `TARGET_CONTAINER: payment-api` within `engine-oom.yaml`. Updated `start-chaos-exercise.sh` to purge stale `ChaosEngine` instances and wait for runner pod startup, ensuring container terminations and ExitCode 137 (`OOMKilled`) are correctly registered and observable in `kubectl describe pod`.
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

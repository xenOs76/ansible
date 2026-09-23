# Kubernetes Homelab (kubeadm + Cilium) with Modular Ansible

This repository provides a modular, production-grade Ansible automation suite
to bootstrap, configure, manage, upgrade, and reset a functional
Kubernetes cluster (1 control plane, 1 worker node by default, configurable)
running Ubuntu.

The implementation directly aligns with the official
[Kubernetes Production Environment](https://kubernetes.io/docs/setup/production-environment/)
documentation and the **Certified Kubernetes Administrator (CKA)** syllabus:

- **Cluster Bootstrapping**: Official `kubeadm` initialization and joins.
- **Container Runtime (CRI)**: `containerd.io` with `SystemdCgroup = true`.
- **CNI**: [Cilium](https://cilium.io/) installed via official Cilium CLI.
- **Node Topology**: 1 Control Plane and 1 Worker Node (scalable via `WORKER_COUNT`).
- **Preprod Environment**: Integrated Vagrant + Libvirt lab.
- **Code Quality**: Built-in support for `ansible-lint` and `yamllint`.

---

## Table of Contents

- [CKA Training Workflows & Repeatable Practice](#cka-training-workflows--repeatable-practice)
  - [1. Full Cluster Deployment Drill](#1-full-cluster-deployment-drill)
  - [2. Component & Subsystem Isolation Drills](#2-component--subsystem-isolation-drills)
  - [3. Automated Cluster Upgrade Playbook](#3-automated-cluster-upgrade-playbook)
  - [4. Fast Cluster Reset & Repeatable Practice Loop](#4-fast-cluster-reset--repeatable-practice-loop)
- [Quickstart: Preprod Lab (Vagrant + Libvirt)](#quickstart-preprod-lab-vagrant--libvirt)
  - [1. Boot the Virtual Machines](#1-boot-the-virtual-machines)
  - [2. Deploy Kubernetes Cluster](#2-deploy-kubernetes-cluster)
  - [3. Verify Cluster](#3-verify-cluster)
- [Directory Layout](#directory-layout)
- [Role & Tag Reference](#role--tag-reference)
- [Prerequisites & Dependencies](#prerequisites--dependencies)
- [Code Quality & Independent Linting](#code-quality--independent-linting)
  - [.ansible-lint Configuration](#ansible-lint-configuration)
- [References & Documentation](#references--documentation)

---

## CKA Training Workflows & Repeatable Practice

This homelab is engineered specifically to provide **reproducible,
rapid-iteration training cycles** for the Certified Kubernetes Administrator
(CKA) exam and production day-2 operations. You can rehearse every exam
requirement repeatedly without rebuilding VMs.

### 1. Full Cluster Deployment Drill

Bootstrap the complete cluster from scratch, including OS hardening, CRI setup,
kubeadm initialization, worker join, and Cilium CNI verification:

```bash
# Automated deployment via Makefile
make preprod-deploy

# Or via parameterized wrapper
./scripts/run-playbook.sh -e preprod -p site.yml

# Or standard Ansible command
ansible-playbook -i inventory/preprod/hosts.ini playbooks/site.yml
```

### 2. Component & Subsystem Isolation Drills

Isolate and practice individual architectural subsystems for targeted debugging
and verification:

<!-- markdownlint-disable MD033 MD013 -->
<details>
<summary><b>Stage nodes right before <code>kubeadm init</code> &amp; CNI (Hands-on CKA Exam Drill)</b></summary>

Prepare the OS, disable swap, configure kernel networking parameters,
install `containerd` with `SystemdCgroup = true`, and install pinned
`kubeadm`, `kubelet`, and `kubectl` on all nodes. This stops immediately
before cluster initialization, leaving `kubeadm init`, worker `kubeadm join`,
and Cilium CNI for manual execution:

```bash
# In Preprod (Vagrant):
# Booting fresh VMs automatically provisions them to this exact pre-init state:
make preprod-up
# (Or if VMs already exist and need a clean slate: make preprod-recreate)

# In Existing / Bare-Metal nodes (via Ansible):
ansible-playbook -i inventory/preprod/hosts.ini playbooks/bootstrap.yml

# Or run site.yml targeting prerequisite tags only:
ansible-playbook -i inventory/preprod/hosts.ini playbooks/site.yml --tags "common,cri,k8s_packages"
```

Once completed, SSH to the nodes to practice the hands-on CKA exam sequence:

```bash
# 1. SSH into the control plane
./scripts/shell.sh --run "vagrant ssh kube-control-plane"

# 2. Run kubeadm init manually
sudo kubeadm init \
  --pod-network-cidr=10.1.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --apiserver-advertise-address=192.168.56.10

# 3. Configure ~/.kube/config for vagrant user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 4. SSH to worker (vagrant ssh kube-worker-1) and run the printed join command:
sudo kubeadm join 192.168.56.10:6443 \
  --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# 5. Install Cilium CNI (manually via cilium-cli or via Ansible playbooks/cni.yml)
cilium install --set cluster.name=homelab-k8s
# Or from your host workstation:
make preprod-cni
```

</details>

<details>
<summary><b>Stage cluster at pre-upgrade baseline (Hands-on CKA Upgrade &amp; ETCD Drills)</b></summary>

To practice cluster maintenance, rolling upgrades, and ETCD operations, first
bring the cluster to a healthy, operational baseline at version `1.34.1-1.1`:

```bash
make preprod-deploy
```

Verify all nodes and Cilium pods are in `Ready` / `Running` state:

```bash
./scripts/shell.sh --run "vagrant ssh kube-control-plane"
kubectl get nodes -o wide
cilium status
```

#### Next Steps & References

Once the cluster is running, practice the two highest-weighted maintenance
topics from the CKA syllabus, following the official documentation and the
Benjamin Muschko crash-course solutions:

- **Official Kubernetes Documentation**:
  - [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
  - [Operating etcd clusters for Kubernetes (Backup & Restore)](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
- **Reference Exercise Solutions**:
  - [bmuschko/cka-crash-course Exercise 02: Cluster Version Upgrade](https://github.com/bmuschko/cka-crash-course/blob/master/exercises/02-cluster-version-upgrade/solution/solution.md)
  - [bmuschko/cka-crash-course Exercise 03: ETCD Backup and Restore](https://github.com/bmuschko/cka-crash-course/blob/master/exercises/03-etcd-backup-restore/solution/solution.md)

#### Hands-on Drill: ETCD Backup & Restore

1. **Inspect etcd static pod and discover certificates**:
   Examine `/etc/kubernetes/manifests/etcd.yaml` (or run `kubectl describe
   pod etcd-kube-control-plane -n kube-system`) to find
   `--listen-client-urls`, `--cert-file`, `--key-file`, and
   `--trusted-ca-file`.

2. **Install etcd-client & capture snapshot**:

   ```bash
   # Install client tools if needed
   sudo apt-get update && sudo apt-get install -y etcd-client

   # Save snapshot
   sudo ETCDCTL_API=3 etcdctl \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     snapshot save /opt/etcd-backup.db
   ```

3. **Verify snapshot integrity**:

   ```bash
   sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status /opt/etcd-backup.db
   ```

4. **Restore etcd data to a new directory (Exam Simulation)**:

   ```bash
   sudo ETCDCTL_API=3 etcdutl \
     --data-dir=/var/lib/from-backup snapshot restore /opt/etcd-backup.db
   ```

5. **Update static pod manifest to point to restored data**:
   Edit `/etc/kubernetes/manifests/etcd.yaml` and update the `etcd-data`
   volume `hostPath`:

   ```yaml
   spec:
     volumes:
     - hostPath:
         path: /var/lib/from-backup
         type: DirectoryOrCreate
       name: etcd-data
   ```

   Kubelet will automatically recreate the `etcd-kube-control-plane` static
   pod using the restored data. Verify with `kubectl get pod
   etcd-kube-control-plane -n kube-system`.

#### Hands-on Drill: Cluster Version Upgrade (`1.34.1` → `1.34.2`)

Follow the step-by-step rolling upgrade pattern without downtime:

1. **Control Plane (`kube-control-plane`)**:

   ```bash
   # 1. Upgrade kubeadm
   sudo apt-mark unhold kubeadm
   sudo apt-get update && sudo apt-get install -y kubeadm=1.34.2-1.1
   sudo apt-mark hold kubeadm

   # 2. Check upgrade plan and apply
   sudo kubeadm upgrade plan
   sudo kubeadm upgrade apply v1.34.2 -y

   # 3. Upgrade kubelet and kubectl
   sudo apt-mark unhold kubelet kubectl
   sudo apt-get install -y kubelet=1.34.2-1.1 kubectl=1.34.2-1.1
   sudo apt-mark hold kubelet kubectl

   # 4. Restart kubelet
   sudo systemctl daemon-reload && sudo systemctl restart kubelet
   ```

2. **Worker Node (`kube-worker-1`)**:

   ```bash
   # From control plane: safely drain worker node
   kubectl drain kube-worker-1 --ignore-daemonsets --delete-emptydir-data --force

   # SSH into kube-worker-1:
   ./scripts/shell.sh --run "vagrant ssh kube-worker-1"

   # 1. Upgrade kubeadm
   sudo apt-mark unhold kubeadm
   sudo apt-get update && sudo apt-get install -y kubeadm=1.34.2-1.1
   sudo apt-mark hold kubeadm

   # 2. Upgrade node configuration
   sudo kubeadm upgrade node

   # 3. Upgrade kubelet and kubectl
   sudo apt-mark unhold kubelet kubectl
   sudo apt-get install -y kubelet=1.34.2-1.1 kubectl=1.34.2-1.1
   sudo apt-mark hold kubelet kubectl

   # 4. Restart kubelet
   sudo systemctl daemon-reload && sudo systemctl restart kubelet

   # From control plane: uncordon the worker node
   kubectl uncordon kube-worker-1
   ```

3. **Verify cluster state**:

   ```bash
   kubectl get nodes -o wide
   cilium status
   ```

</details>

<details>
<summary><b>OS preparation and container runtime (containerd) only</b></summary>

```bash
ansible-playbook -i inventory/preprod/hosts.ini playbooks/site.yml --tags "common,cri"
```

</details>

<details>
<summary><b>Kernel modules (<code>overlay</code>, <code>br_netfilter</code>) and sysctl network parameters</b></summary>

```bash
ansible-playbook -i inventory/preprod/hosts.ini playbooks/site.yml --tags "modules,sysctl"
```

</details>

<details>
<summary><b>Kubernetes Debian repository and package pinning</b></summary>

```bash
ansible-playbook -i inventory/preprod/hosts.ini playbooks/site.yml --tags "k8s_packages"
```

</details>

<details>
<summary><b>Deploy and test Cilium CNI independently</b></summary>

```bash
ansible-playbook -i inventory/preprod/hosts.ini playbooks/cni.yml
```

</details>
<!-- markdownlint-enable MD033 MD013 -->

### 3. Automated Cluster Upgrade Playbook

To rehearse or validate cluster upgrades automatically, the `upgrade.yml`
playbook automates the entire multi-node CKA sequence:

```bash
ansible-playbook -i inventory/preprod/hosts.ini playbooks/upgrade.yml \
  -e "upgrade_target_k8s_version=1.34.2-1.1"
```

**Key automation guarantees**:

- **Control plane first**: Automatically unholds `kubeadm`, runs
  `kubeadm upgrade apply`, upgrades `kubelet`/`kubectl`, and restores
  package holds.
- **Sequential worker upgrades (`serial: 1`)**: Safely drains each worker,
  executes `kubeadm upgrade node`, upgrades binaries, and uncordons the node
  before advancing to the next host.
- **Granular tag execution**: Use `--tags "upgrade_control_plane"` or
  `--tags "upgrade_worker"` to test individual stages.

### 4. Fast Cluster Reset & Repeatable Practice Loop

The key strength of this training lab is the ability to **wipe and reset
within seconds** without destroying or re-downloading virtual machines:

```bash
# Clean reset back to bare OS state
make preprod-reset

# Or directly via playbook
ansible-playbook -i inventory/preprod/hosts.ini playbooks/reset.yml
```

**What this teardown executes**:

- Invokes `kubeadm reset -f` to clear cluster state.
- Flushes `iptables` NAT/mangle tables and cleans IPVS rules.
- Removes Cilium network interfaces (`cilium_host`, `cilium_net`, `cilium_vxlan`).
- Cleans runtime directories (`/etc/cni/net.d`, `/var/lib/kubelet`,
  `/var/lib/cni`, `/etc/kubernetes`).
- Leaves containerd and kernel settings intact, ready for an immediate
  new `make preprod-deploy` run.

[↑ Back to Table of Contents](#table-of-contents)

---

## Directory Layout

```text
k8s-homelab/
├── .ansible-lint                  # Strict ansible-lint rules configuration
├── ansible.cfg                   # Pipelining, role dirs, YAML output callback
├── Makefile                      # Quick targets for lint, preprod, deploy
├── Vagrantfile                   # 1 CP (192.168.56.10) + 1 Worker (configurable)
├── shell.nix                     # Nix environment with Ansible, Vagrant & libvirt
├── .envrc                        # Direnv integration (use nix)
├── scripts/                      # Helper & cluster lifecycle scripts
│   ├── shell.sh                  # Nix-shell launcher
│   ├── help.sh                   # Cluster operations & Vagrant cheatsheet
│   ├── lint.sh                   # yamllint, syntax check, ansible-lint
│   ├── run-playbook.sh           # Playbook execution wrapper
│   ├── common.sh                 # VM provisioning: containerd & k8s packages
│   ├── control-plane.sh          # VM provisioning: kubeadm init helper
│   ├── worker.sh                 # VM provisioning: kubeadm join helper
│   ├── cni-install-cilium.sh     # Cilium CLI installer
│   └── cni-install-calico.sh     # Calico CNI installer
├── inventory/
│   ├── preprod/
│   │   └── hosts.ini             # Inventory for Vagrant libvirt VMs
│   └── prod/
│       └── hosts.ini             # Template for physical homelab nodes
├── group_vars/
│   ├── all.yml                   # Global variables (k8s version, CIDRs)
│   ├── preprod.yml               # Preprod environment overrides
│   ├── control_plane.yml         # Control plane settings
│   └── workers.yml               # Worker node settings
├── roles/
│   ├── common/                   # Swap off, kernel modules, sysctl
│   ├── containerd/               # Docker apt repo, containerd.io
│   ├── kubernetes_packages/      # pkgs.k8s.io repo, kubeadm, kubelet, kubectl
│   ├── control_plane/            # kubeadm init, kubeconfig, join token
│   ├── worker/                   # kubeadm join execution, kubelet node-ip
│   ├── cilium/                   # Cilium CLI download, deployment
│   ├── upgrade/                  # CKA-style rolling cluster upgrade
│   └── reset/                    # kubeadm reset, iptables flush, cleanup
├── playbooks/
│   ├── site.yml                  # End-to-end master deployment
│   ├── bootstrap.yml             # Common OS prep + CRI + k8s packages
│   ├── init.yml                  # Control plane initialization
│   ├── join.yml                  # Worker node join execution
│   ├── cni.yml                   # Deploy & verify Cilium
│   ├── upgrade.yml               # Rolling upgrade for CP and workers
│   └── reset.yml                 # Cluster teardown for repeat practice
├── CHANGELOG.md                  # Release notes & version history (SemVer)
└── README.md
```

[↑ Back to Table of Contents](#table-of-contents)

---

## Role & Tag Reference

The playbook is built with fine-grained tags allowing you to trigger only
specific tasks:

<!-- markdownlint-disable MD013 -->
| Role | Responsibility | Tags |
| :--- | :--- | :--- |
| `common` | Disable swap persistently, load `overlay`/`br_netfilter`, set sysctl, install utils | `common`, `swap`, `modules`, `sysctl`, `packages` |
| `containerd` | Setup Docker repository, install `containerd.io`, configure `SystemdCgroup = true` | `cri`, `containerd` |
| `kubernetes_packages` | Add `pkgs.k8s.io` repository, install `kubeadm`/`kubelet`/`kubectl`, hold | `k8s_packages`, `kubeadm`, `kubelet`, `kubectl` |
| `control_plane` | Run `kubeadm init`, configure root/user kubeconfig, generate join token | `control_plane`, `init`, `kubeconfig`, `join_token` |
| `worker` | Execute `kubeadm join`, configure node IP in `/etc/default/kubelet` | `worker`, `join`, `kubelet` |
| `cilium` | Download Cilium CLI, install Cilium daemonset, wait for status, verify nodes | `cni`, `cilium`, `verify` |
| `upgrade` | Unhold, upgrade kubeadm, `kubeadm upgrade apply`, upgrade kubelet, hold | `upgrade`, `upgrade_control_plane`, `upgrade_worker` |
| `reset` | `kubeadm reset -f`, flush iptables, clean CNI & `/var/lib/kubelet` | `reset` |
<!-- markdownlint-enable MD013 -->

[↑ Back to Table of Contents](#table-of-contents)

---

## Prerequisites & Dependencies

Install or verify the required Ansible collections from `requirements.yml`:

```bash
# Verify required collections are installed:
make check-deps

# Install missing collections:
make deps
```

[↑ Back to Table of Contents](#table-of-contents)

---

## Code Quality & Independent Linting

Validate playbook and role code independently using the provided tools:

```bash
# Run all quality checks (yamllint, syntax, inventory, ansible-lint):
make lint
# Or directly:
./scripts/lint.sh

# Run only playbook syntax validation:
make syntax
```

### `.ansible-lint` Configuration

The included `.ansible-lint` config enforces:

- Fully Qualified Collection Names (`ansible.builtin.*`).
- Validated YAML schemas and line length constraints.
- Safe file modes and idempotency checks.
- Exclusion of Vagrant state directories (`.vagrant/`).

[↑ Back to Table of Contents](#table-of-contents)

---

## Quickstart: Preprod Lab (Vagrant + Libvirt)

### 1. Boot the Virtual Machines

Enter the nix-shell environment and launch the 2 Ubuntu VMs:

```bash
make preprod-up
```

or

```bash
make preprod-recreate
```

in case Vagrant VMs already exist and you want to start from scratch.

Or even

```bash
make preprod-reset
```

in case you do not want to destroy the VMs but just reset the k8s cluster.

The first two options will create:

- `kube-control-plane`: `192.168.56.10`
- `kube-worker-1`: `192.168.56.21`
*(Additional workers can be spawned by setting `WORKER_COUNT=2` before `make preprod-up`)*

### 2. Deploy Kubernetes Cluster

Run the master orchestrator against the preprod inventory:

```bash
make preprod-deploy
# Or via wrapper:
./scripts/run-playbook.sh -e preprod -p site.yml
# Or standard ansible-playbook:
ansible-playbook -i inventory/preprod/hosts.ini playbooks/site.yml
```

### 3. Verify Cluster

Once finished, the playbook outputs the cluster nodes and pod summary. You
can also SSH to the control plane:

```bash
./scripts/shell.sh --run "vagrant ssh kube-control-plane"
kubectl get nodes -o wide
cilium status
```

[↑ Back to Table of Contents](#table-of-contents)

---

## References & Documentation

### Official Kubernetes Documentation

- [Kubernetes Production Environment](https://kubernetes.io/docs/setup/production-environment/)
  – Guidelines and node setup requirements.
- [Creating a Cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
  – Initializing the control plane and joining nodes.
- [Container Runtimes (containerd)](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)
  – Systemd cgroup driver configuration.
- [Upgrading kubeadm Clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
  – Sequential rolling cluster version upgrades.
- [Operating etcd Clusters for Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)
  – Built-in snapshot backup and disaster recovery.

### CKA Curriculum & Exercise Repositories

- [CNCF CKA Exam Curriculum](https://github.com/cncf/curriculum) – Official
  Linux Foundation / CNCF certification domains.
- [Benjamin Muschko CKA Crash Course](https://github.com/bmuschko/cka-crash-course)
  – Hands-on CKA preparation repository.
- [Sander van Vugt CKA Repository](https://github.com/sandervanvugt/cka)
  – Certified Kubernetes Administrator course labs, exercises, and exam
  preparation materials.

### Networking & Container Ecosystem

- [Cilium Documentation](https://docs.cilium.io/) – eBPF-powered CNI
  networking, security, and observability.
- [Cilium CLI GitHub Repository](https://github.com/cilium/cilium-cli)
  – Command-line installer and cluster verification tooling.
- [containerd Project](https://containerd.io/) – Industry-standard core
  container runtime.

### Infrastructure & Automation Tooling

- [Ansible Documentation](https://docs.ansible.com/) – Playbooks, roles,
  variable precedence, and automation best practices.
- [cemakpolat/ansible-kubernetes](https://github.com/cemakpolat/ansible-kubernetes)
  – Automated Kubernetes cluster installation and role architecture patterns
  with Ansible.
- [ansible-lint Rules & Schemas](https://ansible.readthedocs.io/projects/lint/)
  – Code quality, syntax enforcement, and linting profiles.
- [Vagrant Documentation](https://developer.hashicorp.com/vagrant/docs)
  – Virtualized lab orchestration.
- [vagrant-libvirt Provider](https://github.com/vagrant-libvirt/vagrant-libvirt)
  – Vagrant provider for Linux KVM/QEMU libvirt hypervisors.

[↑ Back to Table of Contents](#table-of-contents)

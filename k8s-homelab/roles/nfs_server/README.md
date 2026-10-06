# NFS Storage Server Role (`nfs_server`)

Ansible role for deploying and managing the Linux kernel NFS storage server (`nfs-kernel-server`) on the Kubernetes control plane node, exporting `/srv/nfsroot` to cluster worker nodes across preproduction and production environments.

---

## 1. Role Overview

- **Host Target**: `control_plane`
- **Daemon**: `nfs-kernel-server` (systemd service)
- **Default Export Path**: `/srv/nfsroot` (with subdirectories `/srv/nfsroot/data` and `/srv/nfsroot/reports`)
- **DNS Mapping**: Registers `nfs-server.local` in `/etc/hosts` pointing to the control plane IP address.
- **Environment Support**:
  - **Preprod (Vagrant/Libvirt)**: Exports to `192.168.56.0/24`.
  - **Prod (Bare Metal)**: Exports to cluster network CIDR (`pod_network_cidr` or `10.0.0.0/8`).

---

## 2. Variables & Defaults

| Variable | Default | Description |
| :--- | :--- | :--- |
| `nfs_server_enabled` | `true` | Enables or bypasses the NFS server deployment. |
| `nfs_server_hostname` | `nfs-server.local` | FQDN/local hostname for NFS endpoints in Pods and PVs. |
| `nfs_server_ip` | Dynamic (`node_ip`) | IP address of the NFS server (defaults to control plane IP). |
| `nfs_server_export_dir` | `/srv/nfsroot` | Root directory path exported by the NFS server. |
| `nfs_server_export_subnet` | Auto-detected | Client subnet permitted to mount (`192.168.56.0/24` in preprod). |
| `nfs_server_export_options` | `rw,sync,no_subtree_check,no_root_squash,insecure` | NFS export options in `/etc/exports`. |

---

## 3. Usage & Playbooks

### Standalone Playbook Execution

```bash
# Deploy NFS server and configure cluster client nodes in preprod
./scripts/run-playbook.sh -e preprod -p nfs.yml

# Deploy NFS server in prod
./scripts/run-playbook.sh -e prod -p nfs.yml
```

### Makefile Targets

```bash
# Automatically executed on preprod VM boot:
make preprod-up

# Dedicated targets:
make preprod-nfs
make prod-nfs
```

---

## 4. Manual Verification Commands

Run on `kube-control-plane`:

```bash
# Verify NFS kernel service status
systemctl status nfs-kernel-server

# Inspect active exports
exportfs -s
showmount -e localhost
```

Run on worker nodes:

```bash
# Verify DNS resolution of nfs-server.local
ping -c 1 nfs-server.local

# Query exported mounts from worker
showmount -e nfs-server.local
```

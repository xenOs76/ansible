# Ansible Role: `iscsi_target`

Automates the provisioning and configuration of a Linux-IO (`LIO`) kernel target subsystem using `targetcli-fb` on the Kubernetes control plane to serve file-backed LUNs (or Logical Volumes / raw block devices) to worker nodes over iSCSI.

---

## 1. Overview

The `iscsi_target` role provisions a kernel-native iSCSI target portal listening on port `3260` of `kube-control-plane` (`192.168.56.10`) via the Linux kernel target framework (LIO / `target_core_mod` / `iscsi_target_mod`).

By default, the role serves two 512 MiB sparse disk images from `/srv/iscsi/`:

- **LUN 1 (`lun1.img`)**: Intended for standard filesystem volume mounts (`ext4`, `ReadWriteOnce`).
- **LUN 2 (`lun2.img`)**: Intended for raw block mode volume mounts (`volumeMode: Block`).

Access control is configured in permissive demo mode (`generate_node_acls=1`, `demo_mode_write_protect=0`, `cache_dynamic_acls=1`, `authentication=0`), allowing seamless integration with Kubernetes in-tree iSCSI volume plugins and CKA certification practice exercises without requiring pre-registered initiator IQNs.

---

## 2. Role Variables

### Core Configuration (`defaults/main.yml`)

| Variable | Default Value | Description |
| --- | --- | --- |
| `iscsi_target_enabled` | `true` | Toggle role execution |
| `iscsi_target_framework` | `lio` | Target implementation framework |
| `iscsi_target_service` | `rtslib-fb-targetctl` | Systemd service restoring configuration on boot |
| `iscsi_target_iqn` | `iqn.2026-10.xyz.os76:storage.target01` | SCSI Qualified Name for the target portal |
| `iscsi_target_storage_dir` | `/srv/iscsi` | Base directory holding file-backed image LUNs |
| `iscsi_target_tpg_tag` | `1` | Target Portal Group (TPG) tag identifier |
| `iscsi_target_luns` | *(List of LUN definitions)* | List of LUN objects with ID, name, type, and size |
| `iscsi_target_chap_enabled` | `false` | Enable CHAP incoming credentials check |
| `iscsi_target_incoming_user` | `""` | CHAP username |
| `iscsi_target_incoming_password` | `""` | CHAP secret password |

---

## 3. Future Refactoring Options

The role is designed to be easily extensible beyond tiny sparse files:

### A. LVM Backstores (iblock plugin)

To back LUNs with dynamic Logical Volumes rather than sparse files:

1. Provision an LVM Volume Group (e.g. `vg_storage`) on a dedicated device.
2. Update `iscsi_target_luns` in `group_vars/` or inventory:

   ```yaml
   iscsi_target_luns:
     - id: 1
       name: "lv_storage_lun1"
       type: "block"
       path: "/dev/vg_storage/lv_storage_lun1"
       description: "LVM Logical Volume for CKA storage"
   ```

### B. Dedicated Virtual Disks / Raw Partitions

To use dedicated virtual disks attached via Vagrant/Libvirt (e.g. `/dev/vdc`):

```yaml
iscsi_target_luns:
  - id: 1
    name: "vdc"
    type: "block"
    path: "/dev/vdc"
    description: "Dedicated raw virtual disk"
```

### C. Mutual / One-Way CHAP Authentication

To enforce CHAP authentication:

```yaml
iscsi_target_chap_enabled: true
iscsi_target_incoming_user: "ckatrainee"
iscsi_target_incoming_password: "SuperSecretPassword123!"
```

---

## 4. Verification & Diagnostics

Verify the running LIO target, backstores, and exposed LUNs on the control plane:

```bash
# Check service status
systemctl status rtslib-fb-targetctl

# View complete LIO target hierarchy (backstores, targets, TPGs, LUNs, portals)
sudo targetcli ls

# Verify TCP listening port
ss -tlpn | grep 3260
```

Verify discovery and login from a worker node (`kube-worker-1`):

```bash
# Discover portals
sudo iscsiadm -m discovery -t sendtargets -p 192.168.56.10

# Login to target
sudo iscsiadm -m node -T iqn.2026-10.xyz.os76:storage.target01 -p 192.168.56.10:3260 --login

# Inspect active sessions and block device nodes
sudo iscsiadm -m session -P 3
lsblk
```

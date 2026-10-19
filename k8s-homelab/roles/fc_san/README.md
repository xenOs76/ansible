# Ansible Role: `fc_san`

Automates the provisioning and configuration of a **Fibre Channel (FC) SAN storage emulator** on Kubernetes cluster
nodes, enabling hands-on practice with the Kubernetes in-tree `fc` volume plugin, dual-fabric multipathing, and raw
block volumes.

---

## 1. Overview & Architecture

The `fc_san` role simulates an enterprise Fibre Channel SAN storage array across the cluster nodes:

- **Target WWNN**: `20000025b5000001` (World Wide Node Name)
- **Fabric A WWPN**: `5001438024266301` (Primary Fabric path)
- **Fabric B WWPN**: `5001438024266302` (Secondary Fabric path for multipathing)
- **Backing Storage Directory**: `/srv/fc/`
- **LUN 0** (512 MiB): Filesystem volume target (ext4, formatted on first mount)
- **LUN 1** (512 MiB): Raw block volume target (`volumeMode: Block`)
- **LUN 2** (1024 MiB): Dynamic expansion & reclaim recovery target

The role configures custom udev rules that map backing block devices to the canonical device path formats required by
the Kubernetes in-tree `pkg/volume/fc` driver:

- `/dev/disk/by-path/pci-0000:00:03.0-fc-0x5001438024266301-lun-0`
- `/dev/disk/by-path/pci-0000:00:04.0-fc-0x5001438024266302-lun-0`
- `/dev/disk/by-id/wwn-0x50014380242663010000000000000000`

---

## 2. Role Variables

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `fc_san_enabled` | `true` | Enable or disable role execution |
| `fc_san_storage_dir` | `"/srv/fc"` | Directory storing backing sparse disk images |
| `fc_san_target_wwnn` | `"20000025b5000001"` | Simulated SAN target WWNN |
| `fc_san_target_wwns` | `["5001438024266301", "5001438024266302"]` | Target WWPNs for dual-fabric access |
| `fc_san_pci_slot_a` | `"0000:00:03.0"` | Simulated PCI slot for Fabric A |
| `fc_san_pci_slot_b` | `"0000:00:04.0"` | Simulated PCI slot for Fabric B |

---

## 3. Management CLI (`fc-san-ctl`)

The role installs `/usr/local/bin/fc-san-ctl` on each node:

```bash
# Check SAN target status and active device mappings
fc-san-ctl status

# List configured LUNs and device paths
fc-san-ctl list-luns

# Resize a LUN on the SAN (e.g., grow LUN 0 to 1024 MiB)
sudo fc-san-ctl grow-lun 0 1024M

# Rescan FC bus and refresh block devices
sudo fc-san-ctl rescan
```

---

## 4. Usage in Playbooks

Deploy the FC SAN emulator across cluster nodes:

```bash
cd k8s-homelab
make preprod-fc
```

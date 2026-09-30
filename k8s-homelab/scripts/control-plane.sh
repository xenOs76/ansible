#!/usr/bin/env bash
# ==============================================================================
# Script: control-plane.sh
# Purpose: Initialize Kubernetes control plane node via kubeadm init.
#
# Context:
#   Must be executed inside the 'kube-control-plane' VM with superuser
#   privileges (root / sudo). Typically executed during manual CKA cluster
#   bootstrapping drills or automated provisioning.
#
# Usage:
#   sudo /vagrant/scripts/control-plane.sh [POD_CIDR] [API_ADV_ADDRESS]
#
# Arguments:
#   $1 - POD_CIDR         (Optional) Pod network CIDR block.
#                         Default: 172.18.0.0/16 (matches Cilium / homelab default).
#   $2 - API_ADV_ADDRESS  (Optional) IP address the API server will advertise.
#                         Default: 192.168.56.10 (kube-control-plane host-only IP).
#
# Key Operations & Side Effects:
#   1. Runs `kubeadm init` with specified pod CIDR and apiserver advertise IP.
#   2. Streams and captures output to `/vagrant/kubeadm-init.out` (persisted
#      to host so worker nodes can extract the `kubeadm join` token).
#   3. Sets kubelet extra args (`--node-ip` and `--cgroup-driver=systemd`)
#      in `/etc/default/kubelet` and restarts kubelet.
#   4. Populates `~/.kube/config` for both 'vagrant' and 'root' users.
#   5. Exports `/etc/kubernetes/admin.conf` to `/vagrant/admin.conf` for
#      host tools and worker nodes.
#
# Manual Verification:
#   kubectl get nodes -o wide
#   kubectl get pods -A
#
# Next Steps after Control Plane Init:
#   1. Install CNI plugin:
#      /home/vagrant/cni-install-cilium.sh   (or cni-install-calico.sh)
#   2. Join worker node(s) on worker VM:
#      sudo /vagrant/scripts/worker.sh 1
#   3. Sync credentials to host:
#      make preprod-sync-kubeconfig (on host)
# ==============================================================================
set -euo pipefail

POD_CIDR="${1:-172.18.0.0/16}"
API_ADV_ADDRESS="${2:-192.168.56.10}"

echo "==> [control-plane.sh] Initializing Kubernetes Control Plane..."
echo "    Pod CIDR:          ${POD_CIDR}"
echo "    Advertise Address: ${API_ADV_ADDRESS}"

# 1. Discover all non-loopback, non-CNI IPv4 interface addresses for certificate SANs
INTERFACE_IPS=$(ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" && $2 !~ /^(cilium|lxc|flannel|cbr|docker|calico|cni|veth|tunl|dummy|kube-ipvs)/ {print $4}' | cut -d/ -f1 | sort -u || true)
EXTRA_SANS=$(printf '%s\n' "${API_ADV_ADDRESS}" "192.168.56.10" "kube-control-plane" "127.0.0.1" "localhost" "${INTERFACE_IPS}" | grep -v '^[[:space:]]*$' | sort -u | paste -sd, -)

# 2. Run kubeadm init and capture join token output to shared /vagrant folder
kubeadm init \
  --pod-network-cidr "${POD_CIDR}" \
  --apiserver-advertise-address "${API_ADV_ADDRESS}" \
  --apiserver-cert-extra-sans "${EXTRA_SANS}" \
  | tee /vagrant/kubeadm-init.out

# 3. Configure node IP for kubelet and restart daemon
systemctl daemon-reload
echo "KUBELET_EXTRA_ARGS=--node-ip=${API_ADV_ADDRESS} --cgroup-driver=systemd" > /etc/default/kubelet
systemctl restart kubelet

# 4. Configure kubectl credentials for vagrant and root users
mkdir -p /home/vagrant/.kube
cp -f /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config

# 5. Copy admin.conf to shared /vagrant directory for host & worker node access
cp -f /etc/kubernetes/admin.conf /vagrant/admin.conf
chmod 0644 /vagrant/admin.conf

echo "==> [control-plane.sh] Control plane initialized successfully."
echo "    Next: Install CNI via /home/vagrant/cni-install-cilium.sh or cni-install-calico.sh"

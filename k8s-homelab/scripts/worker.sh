#!/usr/bin/env bash
# ==============================================================================
# Script: worker.sh
# Purpose: Join a worker node to the Kubernetes cluster via kubeadm join.
#
# Context:
#   Must be executed inside a worker VM (e.g. 'kube-worker-1') with superuser
#   privileges (root / sudo). Typically executed during manual CKA cluster
#   bootstrapping drills or automated worker provisioning.
#
# Usage:
#   sudo /vagrant/scripts/worker.sh [NODE_INDEX]
#
# Arguments:
#   $1 - NODE_INDEX  (Optional) 1-based index of the worker node.
#                    Used to compute the host-only IP: 192.168.56.(20 + NODE_INDEX).
#                    Default: 1 (results in IP 192.168.56.21).
#
# Prerequisites:
#   - Control plane node must have completed 'control-plane.sh'.
#   - '/vagrant/kubeadm-init.out' must exist and contain the 'kubeadm join' command.
#   - '/vagrant/admin.conf' should exist if local worker kubectl inspection is desired.
#
# Key Operations & Side Effects:
#   1. Extracts and sanitizes the multi-line 'kubeadm join ...' command from
#      '/vagrant/kubeadm-init.out'.
#   2. Executes join command to register node with the control plane.
#   3. Creates '/etc/kubernetes/manifests' directory (mode 0755) to avoid
#      kubelet journal warnings.
#   4. Sets kubelet extra args ('--node-ip' and '--cgroup-driver=systemd')
#      in '/etc/default/kubelet' and restarts kubelet.
#   5. Copies '/vagrant/admin.conf' to '/etc/kubernetes/admin.conf' and sets
#      KUBECONFIG in '/etc/environment' for convenient on-node troubleshooting.
#
# Troubleshooting & Verification:
#   - Check kubelet service:
#       systemctl status kubelet -l
#       journalctl -u kubelet -e --no-pager
#   - On control plane node:
#       kubectl get nodes -o wide
#   - If join token expired (>24h):
#       On control plane: kubeadm token create --print-join-command
#       On worker node:   sudo <output_join_command>
# ==============================================================================
set -euo pipefail

NODE="${1:-1}"
NODE_HOST_IP="192.168.56.$((20 + NODE))"

echo "==> [worker.sh] Joining worker node #${NODE} (IP: ${NODE_HOST_IP}) to cluster..."

# 1. Verify existence of kubeadm-init.out
if [[ ! -f /vagrant/kubeadm-init.out ]]; then
  echo "Error: /vagrant/kubeadm-init.out not found!" >&2
  echo "       Please run 'control-plane.sh' on kube-control-plane first." >&2
  exit 1
fi

# 2. Extract and execute join command from kubeadm-init output
JOIN_CMD=$(grep -A 2 "kubeadm join" /vagrant/kubeadm-init.out | sed -e 's/^[ \t]*//' | tr '\n' ' ' | sed -e 's/ \\ / /g')

if [[ -z "${JOIN_CMD}" ]]; then
  echo "Error: Could not extract 'kubeadm join' command from /vagrant/kubeadm-init.out" >&2
  exit 1
fi

echo "    Executing join command..."
eval "${JOIN_CMD}"

# 3. Configure manifests directory and kubelet extra arguments
mkdir -p /etc/kubernetes/manifests
systemctl daemon-reload
echo "KUBELET_EXTRA_ARGS=--node-ip=${NODE_HOST_IP} --cgroup-driver=systemd" > /etc/default/kubelet
systemctl restart kubelet

# 4. Stage admin.conf on worker for debugging convenience
if [[ -f /vagrant/admin.conf ]]; then
  cp -f /vagrant/admin.conf /etc/kubernetes/admin.conf
  chmod ugo+r /etc/kubernetes/admin.conf
  if ! grep -q "KUBECONFIG=" /etc/environment 2>/dev/null; then
    echo "KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/environment
  fi
fi

echo "==> [worker.sh] Worker node #${NODE} successfully joined."

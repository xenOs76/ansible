#!/usr/bin/env bash
# ==============================================================================
# Script: common.sh
# Purpose: Bootstrap foundational node prerequisites across all Kubernetes nodes:
#          OS dependencies, containerd CRI, CNI plugins, pinned Kubernetes
#          binaries (kubeadm, kubelet, kubectl), kernel networking, and swap disable.
#
# Context:
#   Executed inside all Vagrant nodes (control-plane and workers) during VM
#   initialization (Vagrantfile provisioner) or for manual bare-metal/VM
#   staging prior to 'kubeadm init' / 'kubeadm join'. Requires root/sudo.
#
# Usage:
#   sudo /vagrant/scripts/common.sh
#   # Or with explicit Kubernetes version:
#   sudo K8S_VERSION="1.34.1-1.1" /vagrant/scripts/common.sh
#
# Environment Variables:
#   K8S_VERSION - Pinned package version for kubeadm, kubelet, and kubectl.
#                 Default: 1.34.1-1.1
#
# Key Subsystems Configured:
#   1. Container Runtime:
#      - Docker APT repository configured.
#      - containerd.io installed and configured with SystemdCgroup = true.
#      - /etc/crictl.yaml generated for containerd socket endpoints.
#   2. CNI Core Binaries:
#      - Reference CNI plugins (bridge, loopback, portmap, etc.) downloaded
#        from containernetworking/plugins and installed to /opt/cni/bin/.
#   3. Kubernetes APT Repository & Packages:
#      - pkgs.k8s.io repository key imported.
#      - kubeadm, kubelet, kubectl installed and marked on apt-mark hold.
#   4. Kernel Networking & Sysctl:
#      - Kernel modules 'overlay' and 'br_netfilter' loaded and persisted.
#      - sysctl values for bridge-nf-call-iptables and ip_forward applied.
#   5. System Hardening:
#      - Linux swap disabled immediately and commented out in /etc/fstab.
#   6. Homelab Tooling:
#      - OS76 custom APT repo configured for kubectl-netdrill.
#      - Base diagnostic packages (socat, kubectl-netdrill, bash-completion) installed.
#
# Manual Verification:
#   systemctl status containerd
#   crictl --timeout 5s version
#   kubeadm version
#   sysctl net.ipv4.ip_forward
#   swapon --show  (must return empty)
# ==============================================================================
set -euo pipefail

if [ -z "${K8S_VERSION+x}" ]; then
  K8S_VERSION="1.34.1-1.1"
fi

echo "==> [common.sh] Starting common node provisioning (Kubernetes ${K8S_VERSION})..."

# ------------------------------------------------------------------------------
# 1. Container Runtime (containerd.io)
# ------------------------------------------------------------------------------
echo "==> [1/6] Installing and configuring containerd..."
sudo apt-get update -y
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update -y
sudo apt-get install -y containerd.io
sudo systemctl start containerd
sudo systemctl enable containerd

# Generate containerd config and enforce SystemdCgroup
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.orig 2>/dev/null || true
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Configure crictl default endpoints to avoid CLI warnings
cat <<EOF | sudo tee /etc/crictl.yaml >/dev/null
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# ------------------------------------------------------------------------------
# 2. Reference CNI Plugins (/opt/cni/bin)
# ------------------------------------------------------------------------------
echo "==> [2/6] Installing standard CNI plugins..."
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" == "aarch64" ]; then
  ARCH="arm64"
elif [ "$ARCH" == "armv7l" ]; then
  ARCH="arm"
else
  echo "Error: Unsupported architecture: $ARCH" >&2
  exit 1
fi

CNI_PLUGINS_URL="https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-${ARCH}-v1.1.1.tgz"
wget -q "$CNI_PLUGINS_URL" -O "/tmp/cni-plugins.tgz"
mkdir -p /opt/cni/bin
tar -xzf "/tmp/cni-plugins.tgz" -C /opt/cni/bin
rm -f "/tmp/cni-plugins.tgz" /home/vagrant/cni-plugins-*.tgz* 2>/dev/null || true
sudo systemctl restart containerd

# ------------------------------------------------------------------------------
# 3. Kubernetes APT Repository & Binaries
# ------------------------------------------------------------------------------
echo "==> [3/6] Installing pinned Kubernetes packages (${K8S_VERSION})..."
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION:0:4}/deb/Release.key" \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION:0:4}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt-get update -y
sudo apt-get install -y \
  kubeadm="$K8S_VERSION" \
  kubelet="$K8S_VERSION" \
  kubectl="$K8S_VERSION"
sudo apt-mark hold kubelet kubeadm kubectl

# ------------------------------------------------------------------------------
# 4. Kernel Modules & Sysctl Networking Settings
# ------------------------------------------------------------------------------
echo "==> [4/6] Configuring kernel networking and sysctl..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system >/dev/null

# ------------------------------------------------------------------------------
# 5. Disable Swap Permanently
# ------------------------------------------------------------------------------
echo "==> [5/6] Disabling swap..."
sudo swapoff -a
sudo sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab

# ------------------------------------------------------------------------------
# 6. Diagnostic Tooling
# ------------------------------------------------------------------------------
echo "==> [6/6] Installing diagnostic tools..."
echo "deb [trusted=yes] https://repo.os76.xyz/apt stable main" | sudo tee /etc/apt/sources.list.d/os76.list >/dev/null
sudo apt-get update -y
sudo apt-get -y install socat kubectl-netdrill bash-completion

echo "==> [common.sh] Node prerequisites installed successfully."


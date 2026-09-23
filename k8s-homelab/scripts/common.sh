#!/usr/bin/env bash

if [ -z ${K8S_VERSION+x} ]; then
  K8S_VERSION=1.34.1-1.1
fi

# Install containerd container runtime
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y containerd.io
sudo systemctl start containerd
sudo systemctl enable containerd
sudo systemctl status containerd
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.orig 2>/dev/null || true
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Configure crictl default endpoints
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" == "aarch64" ]; then
  ARCH="arm64"
elif [ "$ARCH" == "armv7l" ]; then
  ARCH="arm"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

CNI_PLUGINS_URL="https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-${ARCH}-v1.1.1.tgz"
wget -q "$CNI_PLUGINS_URL" -O "/tmp/cni-plugins.tgz"
mkdir -p /opt/cni/bin
tar -xzf "/tmp/cni-plugins.tgz" -C /opt/cni/bin
rm -f "/tmp/cni-plugins.tgz" /home/vagrant/cni-plugins-*.tgz*
sudo systemctl restart containerd

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION:0:4}/deb/Release.key" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION:0:4}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes binaries
sudo apt-get update
sudo apt-get install -y \
  kubeadm="$K8S_VERSION" \
  kubelet="$K8S_VERSION" \
  kubectl="$K8S_VERSION"
sudo apt-mark hold kubelet kubeadm kubectl

# Load kernel modules required by containerd and Kubernetes, and persist across reboots
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl parameters required by Kubernetes networking (persists across reboots)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameters immediately without rebooting
sudo sysctl --system

# Disable swap permanently
sudo swapoff -a
sudo sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab

# Configure OS76 APT repository (kubectl-netdrill, etc.)
echo "deb [trusted=yes] https://repo.os76.xyz/apt stable main" | sudo tee /etc/apt/sources.list.d/os76.list

sudo apt-get update
sudo apt-get -y install socat kubectl-netdrill

# Set alias for kubectl command (idempotent)
grep -qxF 'alias k=kubectl' /home/vagrant/.bashrc || echo "alias k=kubectl" >>/home/vagrant/.bashrc

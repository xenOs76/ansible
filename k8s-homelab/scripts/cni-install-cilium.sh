#!/usr/bin/env bash
# ==============================================================================
# Script: cni-install-cilium.sh
# Purpose: Download, verify, and install the Cilium CLI, then deploy the
#          Cilium eBPF-based Container Network Interface (CNI) to the cluster.
#
# Context:
#   Executed on the 'kube-control-plane' node after 'control-plane.sh' (kubeadm init)
#   has completed. Typically run as 'vagrant' user with sudo permissions.
#
# Usage:
#   /home/vagrant/cni-install-cilium.sh
#   # Or directly from the shared mount:
#   /vagrant/scripts/cni-install-cilium.sh
#
# Key Operations:
#   1. Queries upstream GitHub for latest stable Cilium CLI version tag.
#   2. Detects architecture (amd64 / arm64).
#   3. Downloads CLI archive alongside official sha256sum and verifies integrity.
#   4. Installs 'cilium' binary into /usr/local/bin.
#   5. Runs 'cilium install' to roll out the Cilium DaemonSet and operator.
#
# Manual Verification:
#   cilium status --wait
#   kubectl get pods -n kube-system -l k8s-app=cilium -o wide
#   kubectl get nodes -o wide   # (Nodes will transition from NotReady to Ready)
#
# Troubleshooting:
#   - If cilium CLI download fails: Check outbound internet connectivity.
#   - To inspect Cilium health: cilium status --verbose
#   - To run connectivity test drill: cilium connectivity test
# ==============================================================================
set -euo pipefail

echo "=== [cni-install-cilium.sh] Installing Cilium CNI ==="

# 1. Determine latest stable CLI version and system architecture
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH="amd64"
if [ "$(uname -m)" = "aarch64" ]; then
  CLI_ARCH="arm64"
fi

echo "    Cilium CLI Version: ${CILIUM_CLI_VERSION} (${CLI_ARCH})"

# 2. Download and verify Cilium CLI binary
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

cd "${TMP_DIR}"
echo "    Downloading Cilium CLI and verifying SHA256 checksum..."
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"

echo "    Installing cilium binary to /usr/local/bin..."
sudo tar -C /usr/local/bin -xzvf "cilium-linux-${CLI_ARCH}.tar.gz"

# 3. Deploy Cilium into the Kubernetes cluster
echo "    Deploying Cilium CNI into cluster..."
cilium install

echo "=== [cni-install-cilium.sh] Cilium CNI installation initiated ==="
echo "    Monitor status via: cilium status --wait"

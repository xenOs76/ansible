#!/usr/bin/env bash
# ==============================================================================
# Script: cni-install-hubble.sh
# Purpose: Download, verify, and install the Cilium Hubble CLI, then optionally
#          enable Hubble observability on an active Cilium deployment.
#
# Context:
#   Executed on the 'kube-control-plane' node after 'cni-install-cilium.sh'
#   (or Ansible role 'cilium') has rolled out the Cilium CNI.
#   Typically run as 'vagrant' user with sudo permissions.
#
# Usage:
#   /home/vagrant/cni-install-hubble.sh
#   # Or directly from the shared mount:
#   /vagrant/scripts/cni-install-hubble.sh
#
# Key Operations:
#   1. Queries upstream GitHub for latest stable Hubble CLI version tag.
#   2. Detects system architecture (amd64 / arm64).
#   3. Downloads CLI archive alongside official sha256sum and verifies integrity.
#   4. Installs 'hubble' binary into /usr/local/bin.
#   5. Enables Hubble via 'cilium hubble enable' if Cilium is active in cluster.
#
# Manual Verification:
#   hubble version
#   cilium status
#   cilium hubble port-forward&
#   hubble status
#   hubble observe
#
# Troubleshooting:
#   - If Hubble CLI download fails: Check outbound internet connectivity.
#   - If Hubble fails to connect: Ensure 'cilium hubble enable' has completed.
# ==============================================================================
set -euo pipefail

echo "=== [cni-install-hubble.sh] Installing Cilium Hubble CLI ==="

# 1. Determine latest stable CLI version and system architecture
DEFAULT_HUBBLE_VERSION="v1.20.2"
HUBBLE_VERSION=$(curl -s --fail https://raw.githubusercontent.com/cilium/hubble/master/stable.txt || true)
if [ -z "${HUBBLE_VERSION}" ]; then
  echo "    Warning: Unable to query upstream stable.txt, falling back to ${DEFAULT_HUBBLE_VERSION}"
  HUBBLE_VERSION="${DEFAULT_HUBBLE_VERSION}"
fi

CLI_ARCH="amd64"
if [ "$(uname -m)" = "aarch64" ]; then
  CLI_ARCH="arm64"
fi

echo "    Hubble CLI Version: ${HUBBLE_VERSION} (${CLI_ARCH})"

# 2. Download and verify Hubble CLI binary
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

cd "${TMP_DIR}"
echo "    Downloading Hubble CLI and verifying SHA256 checksum..."
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "hubble-linux-${CLI_ARCH}.tar.gz.sha256sum"

echo "    Installing hubble binary to /usr/local/bin..."
sudo tar -C /usr/local/bin -xzvf "hubble-linux-${CLI_ARCH}.tar.gz"
sudo chmod 0755 /usr/local/bin/hubble

# 3. Enable Hubble in Cilium cluster if cluster is reachable
if command -v cilium >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1; then
  if kubectl get nodes >/dev/null 2>&1; then
    echo "    Cluster is accessible. Checking Cilium status..."
    if cilium status --wait=false >/dev/null 2>&1; then
      echo "    Enabling Hubble observability in Cilium cluster..."
      cilium hubble enable || true
      echo "    Cilium cluster status:"
      cilium status || true
    fi
  fi
fi

echo "=== [cni-install-hubble.sh] Cilium Hubble CLI installation complete ==="
echo "    Verify installation via: hubble version"
echo "    Inspect cluster status via: cilium status"
echo "    Check Hubble relay via:  cilium hubble port-forward & followed by: hubble status"

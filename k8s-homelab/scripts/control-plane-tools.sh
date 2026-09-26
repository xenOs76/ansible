#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Control Plane Tools (Helm, k9s) ==="

# 1. Install Helm via official APT repository
if ! command -v helm >/dev/null 2>&1; then
  echo "Installing Helm via official APT repository..."
  mkdir -p /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/helm.gpg ]; then
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor --yes -o /etc/apt/keyrings/helm.gpg
    chmod 0644 /etc/apt/keyrings/helm.gpg
  fi
  echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
  apt-get update -y
  apt-get install -y helm
else
  echo "Helm is already installed."
fi

# 2. Install k9s via official .deb package
if ! command -v k9s >/dev/null 2>&1; then
  K9S_VERSION="${K9S_VERSION:-v0.40.10}"
  ARCH=$(dpkg --print-architecture)
  echo "Installing k9s (${K9S_VERSION}) via official release .deb package..."
  TMP_K9S_DEB="/tmp/k9s_linux_${ARCH}.deb"
  curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_linux_${ARCH}.deb" -o "$TMP_K9S_DEB"
  apt-get install -y "$TMP_K9S_DEB"
  rm -f "$TMP_K9S_DEB"
else
  echo "k9s is already installed."
fi

echo "=== Control Plane Tools Installed Successfully ==="

#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Control Plane Tools (Helm, k9s) ==="

# 1. Install Helm via official APT repository
if ! command -v helm >/dev/null 2>&1; then
  echo "Installing Helm via official APT repository..."
  mkdir -p /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/helm.gpg ]; then
    HELM_KEY_FINGERPRINT="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"  # gitleaks:allow
    TMP_HELM_KEY=$(mktemp /tmp/helm.XXXXXX.gpg)
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey -o "$TMP_HELM_KEY"
    PUB_COUNT=$(gpg --show-keys --with-colons "$TMP_HELM_KEY" | grep -c '^pub:' || true)
    DETECTED_FPR=$(gpg --show-keys --with-colons "$TMP_HELM_KEY" | awk -F: '$1 == "pub" {getline; if ($1 == "fpr") print $10}')
    if [ "$PUB_COUNT" -ne 1 ] || [ "$DETECTED_FPR" != "$HELM_KEY_FINGERPRINT" ]; then
      echo "ERROR: Helm APT key validation failed: found ${PUB_COUNT} primary keys (expected 1), fingerprint='${DETECTED_FPR}'" >&2
      rm -f "$TMP_HELM_KEY"
      exit 1
    fi
    gpg --dearmor --yes -o /etc/apt/keyrings/helm.gpg "$TMP_HELM_KEY"
    chmod 0644 /etc/apt/keyrings/helm.gpg
    rm -f "$TMP_HELM_KEY"
  fi
  echo "deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
  apt-get update -y
  apt-get install -y helm
else
  echo "Helm is already installed."
fi

# 2. Install k9s via official .deb package
K9S_VERSION="${K9S_VERSION:-v0.40.10}"
NORMALIZED_TARGET="${K9S_VERSION#v}"
INSTALLED_K9S_VERSION=""

if command -v k9s >/dev/null 2>&1; then
  INSTALLED_K9S_VERSION=$(k9s version --short 2>/dev/null | awk '$1 == "Version" {print $2}' | sed 's/^v//')
  if [ -z "$INSTALLED_K9S_VERSION" ]; then
    INSTALLED_K9S_VERSION=$(dpkg-query -W -f='${Version}' k9s 2>/dev/null || true)
  fi
fi

if [ "$INSTALLED_K9S_VERSION" != "$NORMALIZED_TARGET" ]; then
  ARCH=$(dpkg --print-architecture)
  echo "Installing k9s (${K9S_VERSION}) via official release .deb package..."
  TMP_K9S_DEB="/tmp/k9s_linux_${ARCH}.deb"
  curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_linux_${ARCH}.deb" -o "$TMP_K9S_DEB"
  apt-get install -y "$TMP_K9S_DEB"
  rm -f "$TMP_K9S_DEB"
else
  echo "k9s version ${K9S_VERSION} is already installed."
fi

echo "=== Control Plane Tools Installed Successfully ==="

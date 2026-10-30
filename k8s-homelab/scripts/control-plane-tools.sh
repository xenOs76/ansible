#!/usr/bin/env bash
# ==============================================================================
# Script: control-plane-tools.sh
# Purpose: Install essential Kubernetes administration and operations CLI tools
#          (Helm v3, k9s, etcdctl, etcdutl, glow, krew, and kubectl-cyclonus) on the control plane node.
#
# Context:
#   Executed inside the 'kube-control-plane' VM with superuser privileges
#   (root / sudo). Run during Vagrant initial provisioning or manually on any
#   control plane node requiring administration utilities.
#
# Usage:
#   sudo /vagrant/scripts/control-plane-tools.sh
#   # Or with custom versions:
#   sudo K9S_VERSION="v0.51.0" ETCD_VERSION="v3.5.16" KREW_VERSION="v0.5.0" /vagrant/scripts/control-plane-tools.sh
#
# Environment Variables:
#   K9S_VERSION      - Target release tag of k9s to install from GitHub releases.
#                      Default: v0.51.0
#   ETCD_VERSION     - Target release tag of etcd tools (etcdctl, etcdutl) from
#                      official GitHub releases.
#                      Default: v3.5.16
#   GLOW_VERSION     - Target release tag of glow markdown reader.
#                      Default: 2.1.1
#   KREW_VERSION     - Target release tag of krew plugin manager from GitHub releases.
#                      Default: v0.5.0
#   CYCLONUS_VERSION - Target release tag of kubectl-cyclonus network policy tool.
#                      Default: v0.2.1
#
# Key Subsystems Installed:
#   1. Helm v3:
#      - Verifies and imports official Helm Debian APT repository signing key.
#      - Validates key against published fingerprint:
#        DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6
#      - Installs helm package via apt-get.
#   2. k9s Terminal UI:
#      - Detects current installed version to ensure idempotency.
#      - Downloads official architecture-specific .deb from GitHub releases.
#      - Installs package via apt-get and removes temporary installer.
#   3. etcdctl & etcdutl:
#      - Note: Ubuntu universe repository only provides etcd-client (v3.4.x)
#        and omits etcdutl entirely. To match Kubernetes 1.34 and CKA standards,
#        version-matched binaries are installed from official GitHub releases.
#      - Installs binaries to /usr/local/bin with mode 0755.
#      - Exports ETCDCTL_API=3 in /etc/profile.d/etcd.sh for all shells.
#   4. glow Markdown CLI reader:
#      - Downloads and installs official architecture-specific .deb package.
#      - Configures 'alias glow="glow -s tokyo-night -w 150"' in /etc/profile.d/glow.sh and user .bashrc.
#   5. krew kubectl plugin manager:
#      - Downloads and installs official architecture-specific binary to /usr/local/bin/kubectl-krew.
#      - Configures PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH" in /etc/profile.d/krew.sh and user .bashrc.
#   6. kubectl-cyclonus NetworkPolicy analyzer:
#      - Downloads and installs official architecture-specific binary to /usr/local/bin/kubectl-cyclonus.
#
# Manual Verification:
#   helm version --short
#   k9s version --short
#   etcdctl version
#   etcdutl version
#   glow --version
#   kubectl-krew version
#   kubectl cyclonus -h
#
# Troubleshooting:
#   - If Helm key verification fails: Check curl connectivity to packages.buildkite.com.
#   - If k9s download fails: Verify GitHub access or inspect /tmp/k9s_linux_*.deb.
#   - If etcd tools download fails: Verify GitHub access or release tag existence.
#   - If krew or cyclonus download fails: Verify GitHub access or release tag existence.
# ==============================================================================
set -euo pipefail

echo "=== Installing Control Plane Tools (Helm, k9s, etcdctl, etcdutl, glow, krew, cyclonus) ==="

# ------------------------------------------------------------------------------
# 1. Install Helm via official APT repository with GPG fingerprint verification
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# 2. Install k9s via official release .deb package
# ------------------------------------------------------------------------------
K9S_VERSION="${K9S_VERSION:-v0.51.0}"
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

# Configure transparent Nord theme for SSH readability
K9S_CONFIG_DIR="/home/vagrant/.config/k9s"
mkdir -p "${K9S_CONFIG_DIR}/skins"

cat <<'EOF' > "${K9S_CONFIG_DIR}/skins/nord.yaml"
# -----------------------------------------------------------------------------
# Nord skin (Transparent background for crystal-clear SSH rendering)
# -----------------------------------------------------------------------------
foreground: &foreground "#DADEE8"
current_line: &current_line "#383D4A"
selection: &selection "#D9DEE8"
comment: &comment "#8891A7"
cyan: &cyan "#88C0D0"
green: &green "#A3BE8C"
orange: &orange "#D08770"
blue: &blue "#81A1C1"
magenta: &magenta "#B48EAD"
red: &red "#BF616A"
yellow: &yellow "#EBCB8B"

k9s:
  body:
    fgColor: *foreground
    bgColor: default
    logoColor: *magenta
  prompt:
    fgColor: *foreground
    bgColor: default
    suggestColor: *orange
  info:
    fgColor: *blue
    sectionColor: *foreground
  dialog:
    fgColor: *foreground
    bgColor: default
    buttonFgColor: *foreground
    buttonBgColor: *magenta
    buttonFocusFgColor: *yellow
    buttonFocusBgColor: *blue
    labelFgColor: *orange
    fieldFgColor: *foreground
  frame:
    border:
      fgColor: *selection
      focusColor: *current_line
    menu:
      fgColor: *foreground
      keyColor: *blue
      numKeyColor: *blue
    crumbs:
      fgColor: *foreground
      bgColor: default
      activeColor: *current_line
    status:
      newColor: *cyan
      modifyColor: *magenta
      addColor: *green
      errorColor: *red
      highlightColor: *orange
      killColor: *comment
      completedColor: *comment
    title:
      fgColor: *foreground
      bgColor: default
      highlightColor: *orange
      counterColor: *magenta
      filterColor: *blue
  views:
    charts:
      bgColor: default
      defaultDialColors:
        - *magenta
        - *red
      defaultChartColors:
        - *magenta
        - *red
    table:
      fgColor: *foreground
      bgColor: default
      header:
        fgColor: *foreground
        bgColor: default
        sorterColor: *cyan
    xray:
      fgColor: *foreground
      bgColor: default
      cursorColor: *current_line
      graphicColor: *magenta
      showIcons: false
    yaml:
      keyColor: *blue
      colonColor: *magenta
      valueColor: *foreground
    logs:
      fgColor: *foreground
      bgColor: default
      indicator:
        fgColor: *foreground
        bgColor: *magenta
        toggleOnColor: *magenta
        toggleOffColor: *blue
    help:
      fgColor: *foreground
      bgColor: default
      indicator:
        fgColor: *red
EOF

cat <<'EOF' > "${K9S_CONFIG_DIR}/config.yaml"
k9s:
  ui:
    skin: nord
EOF
chown -R vagrant:vagrant "/home/vagrant/.config"

# ------------------------------------------------------------------------------
# 3. Install etcdctl and etcdutl via official release archive
# ------------------------------------------------------------------------------
ETCD_VERSION="${ETCD_VERSION:-v3.5.16}"
if [[ "$ETCD_VERSION" != v* ]]; then
  ETCD_VERSION="v${ETCD_VERSION}"
fi
NORMALIZED_ETCD_VERSION="${ETCD_VERSION#v}"

INSTALLED_ETCDCTL_VERSION=""
if command -v etcdctl >/dev/null 2>&1; then
  INSTALLED_ETCDCTL_VERSION=$(etcdctl version 2>/dev/null | awk '$1 == "etcdctl" && $2 == "version:" {print $3}' | sed 's/^v//' || true)
fi

INSTALLED_ETCDUTL_VERSION=""
if command -v etcdutl >/dev/null 2>&1; then
  INSTALLED_ETCDUTL_VERSION=$(etcdutl version 2>/dev/null | awk '$1 == "etcdutl" && $2 == "version:" {print $3}' | sed 's/^v//' || true)
fi

if [ "$INSTALLED_ETCDCTL_VERSION" != "$NORMALIZED_ETCD_VERSION" ] || [ "$INSTALLED_ETCDUTL_VERSION" != "$NORMALIZED_ETCD_VERSION" ]; then
  ARCH=$(dpkg --print-architecture)
  echo "Installing etcdctl and etcdutl (${ETCD_VERSION}) via official release archive..."
  TMP_ETCD_DIR=$(mktemp -d /tmp/etcd.XXXXXX)
  TMP_ETCD_TGZ="${TMP_ETCD_DIR}/etcd.tar.gz"
  ETCD_DOWNLOAD_URL="https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz"

  curl -fsSL "$ETCD_DOWNLOAD_URL" -o "$TMP_ETCD_TGZ"
  tar -xzf "$TMP_ETCD_TGZ" -C "$TMP_ETCD_DIR" --strip-components=1
  install -m 0755 "${TMP_ETCD_DIR}/etcdctl" /usr/local/bin/etcdctl
  install -m 0755 "${TMP_ETCD_DIR}/etcdutl" /usr/local/bin/etcdutl
  rm -rf "$TMP_ETCD_DIR"
else
  echo "etcdctl and etcdutl version ${ETCD_VERSION} are already installed."
fi

# Configure ETCDCTL_API=3 system-wide for interactive and login shells
cat <<'EOF' > /etc/profile.d/etcd.sh
export ETCDCTL_API=3
EOF
chmod 0644 /etc/profile.d/etcd.sh

# ------------------------------------------------------------------------------
# 4. Install glow Markdown CLI reader via official release .deb package
# ------------------------------------------------------------------------------
GLOW_VERSION="${GLOW_VERSION:-2.1.1}"
if ! command -v glow >/dev/null 2>&1; then
  ARCH=$(dpkg --print-architecture)
  echo "Installing glow (${GLOW_VERSION}) via official release .deb package..."
  TMP_GLOW_DEB="/tmp/glow_${ARCH}.deb"
  curl -fsSL "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_${ARCH}.deb" -o "$TMP_GLOW_DEB"
  apt-get install -y "$TMP_GLOW_DEB"
  rm -f "$TMP_GLOW_DEB"
else
  echo "glow is already installed."
fi

# Configure glow alias system-wide and in user .bashrc
cat <<'EOF' > /etc/profile.d/glow.sh
alias glow="glow -s tokyo-night -w 150"
EOF
chmod 0644 /etc/profile.d/glow.sh

if [ -f /home/vagrant/.bashrc ]; then
  if grep -q '^alias glow=' /home/vagrant/.bashrc; then
    sed -i 's|^alias glow=.*|alias glow="glow -s tokyo-night -w 150"|' /home/vagrant/.bashrc
  else
    echo 'alias glow="glow -s tokyo-night -w 150"' >> /home/vagrant/.bashrc
  fi
fi

if [ -f /root/.bashrc ]; then
  if grep -q '^alias glow=' /root/.bashrc; then
    sed -i 's|^alias glow=.*|alias glow="glow -s tokyo-night -w 150"|' /root/.bashrc
  else
    echo 'alias glow="glow -s tokyo-night -w 150"' >> /root/.bashrc
  fi
fi

# ------------------------------------------------------------------------------
# 5. Install krew kubectl plugin manager via official release archive
# ------------------------------------------------------------------------------
KREW_VERSION="${KREW_VERSION:-v0.5.0}"
NORMALIZED_KREW_TARGET="${KREW_VERSION#v}"
INSTALLED_KREW_VERSION=""
if command -v kubectl-krew >/dev/null 2>&1; then
  INSTALLED_KREW_VERSION=$(kubectl-krew version 2>/dev/null | awk '$1 == "GitTag" {print $2}' | sed 's/^v//')
fi

if [ "$INSTALLED_KREW_VERSION" != "$NORMALIZED_KREW_TARGET" ]; then
  ARCH=$(dpkg --print-architecture)
  echo "Installing krew (${KREW_VERSION}) via official release archive..."
  TMP_KREW_DIR=$(mktemp -d)
  curl -fsSL "https://github.com/kubernetes-sigs/krew/releases/download/${KREW_VERSION}/krew-linux_${ARCH}.tar.gz" -o "${TMP_KREW_DIR}/krew.tar.gz"
  tar -zxvf "${TMP_KREW_DIR}/krew.tar.gz" -C "${TMP_KREW_DIR}"
  install -m 0755 "${TMP_KREW_DIR}/krew-linux_${ARCH}" /usr/local/bin/kubectl-krew
  ln -sf /usr/local/bin/kubectl-krew /usr/local/bin/krew
  rm -rf "${TMP_KREW_DIR}"
else
  echo "krew is already installed."
fi

# Configure krew PATH environment profile
cat <<'EOF' > /etc/profile.d/krew.sh
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
EOF
chmod 0644 /etc/profile.d/krew.sh

if [ -f /home/vagrant/.bashrc ]; then
  if ! grep -q '\.krew/bin' /home/vagrant/.bashrc; then
    # shellcheck disable=SC2016
    echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> /home/vagrant/.bashrc
  fi
fi

if [ -f /root/.bashrc ]; then
  if ! grep -q '\.krew/bin' /root/.bashrc; then
    # shellcheck disable=SC2016
    echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> /root/.bashrc
  fi
fi

# ------------------------------------------------------------------------------
# 6. Install kubectl-cyclonus NetworkPolicy analysis tool via official release archive
# ------------------------------------------------------------------------------
CYCLONUS_VERSION="${CYCLONUS_VERSION:-v0.2.1}"
INSTALLED_CYCLONUS_VERSION=""
if [ -f /etc/kubectl-cyclonus-version ]; then
  INSTALLED_CYCLONUS_VERSION=$(cat /etc/kubectl-cyclonus-version)
fi

if [ "$INSTALLED_CYCLONUS_VERSION" != "$CYCLONUS_VERSION" ] || ! command -v kubectl-cyclonus >/dev/null 2>&1; then
  ARCH=$(dpkg --print-architecture)
  echo "Installing kubectl-cyclonus (${CYCLONUS_VERSION}) via official release archive..."
  TMP_CYCLONUS_DIR=$(mktemp -d)
  curl -fsSL "https://github.com/mattfenwick/kubectl-cyclonus/releases/download/${CYCLONUS_VERSION}/kubectl-cyclonus_linux_${ARCH}.tar.gz" -o "${TMP_CYCLONUS_DIR}/cyclonus.tar.gz"
  tar -zxvf "${TMP_CYCLONUS_DIR}/cyclonus.tar.gz" -C "${TMP_CYCLONUS_DIR}"
  install -m 0755 "${TMP_CYCLONUS_DIR}/kubectl-cyclonus" /usr/local/bin/kubectl-cyclonus
  echo "${CYCLONUS_VERSION}" > /etc/kubectl-cyclonus-version
  chmod 0644 /etc/kubectl-cyclonus-version
  rm -rf "${TMP_CYCLONUS_DIR}"
else
  echo "kubectl-cyclonus is already installed."
fi

echo "=== Control Plane Tools Installed Successfully ==="


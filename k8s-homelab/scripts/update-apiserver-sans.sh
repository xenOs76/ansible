#!/usr/bin/env bash
# ==============================================================================
# Script: update-apiserver-sans.sh
# Purpose: Ensure the Kubernetes API server serving certificate on the control
#          plane node contains all local network interface IPs and hostnames,
#          and propagate the updated credentials to the SSH user and root.
#
# Context:
#   Must be executed on the 'kube-control-plane' VM with root/sudo privileges.
#   Invoked automatically by 'make preprod-sync-kubeconfig' or manually during
#   troubleshooting of TLS certificate verification errors.
#
# Operations:
#   1. Discovers all host IPv4 interface addresses (eth0, eth1, etc.), excluding
#      loopback and CNI virtual interfaces.
#   2. Inspects /etc/kubernetes/pki/apiserver.crt for existing SAN entries.
#   3. If any interface IP or required hostname is missing:
#      a. Backs up apiserver.crt and apiserver.key.
#      b. Reissues apiserver.crt with all discovered IPs and SANs via kubeadm.
#      c. Restarts kube-apiserver static Pod by cycling its manifest.
#      d. Waits for /livez health probe to report 'ok'.
#   4. Propagates the updated /etc/kubernetes/admin.conf to the home directories
#      of the active SSH user ($SUDO_USER), vagrant, and root.
# ==============================================================================
set -euo pipefail

CERT_FILE="/etc/kubernetes/pki/apiserver.crt"
KEY_FILE="/etc/kubernetes/pki/apiserver.key"
MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
ADMIN_CONF="/etc/kubernetes/admin.conf"

if [[ ! -f "${CERT_FILE}" ]]; then
  # Kubernetes control plane is not initialized yet; nothing to update.
  exit 0
fi

# Function to propagate admin.conf to the home of target users
propagate_kubeconfig() {
  local candidate_users=("root" "vagrant")
  if [[ -n "${SUDO_USER:-}" ]]; then
    candidate_users+=("${SUDO_USER}")
  fi
  if [[ -n "${USER:-}" ]]; then
    candidate_users+=("${USER}")
  fi

  local unique_users=()
  read -r -a unique_users <<< "$(printf '%s\n' "${candidate_users[@]}" | sort -u | tr '\n' ' ')"

  for u in "${unique_users[@]}"; do
    local user_info user_home user_gid user_group
    if user_info=$(getent passwd "${u}" 2>/dev/null); then
      user_home=$(echo "${user_info}" | cut -d: -f6)
      user_gid=$(echo "${user_info}" | cut -d: -f4)
      user_group=$(getent group "${user_gid}" 2>/dev/null | cut -d: -f1 || echo "${u}")

      if [[ -n "${user_home}" && -d "${user_home}" && -f "${ADMIN_CONF}" ]]; then
        mkdir -p "${user_home}/.kube"
        if ! cmp -s "${ADMIN_CONF}" "${user_home}/.kube/config" 2>/dev/null; then
          cp -f "${ADMIN_CONF}" "${user_home}/.kube/config"
          echo "==> [update-apiserver-sans] Propagated updated kubeconfig to ${u} (${user_home}/.kube/config)"
        fi
        chown "${u}:${user_group}" "${user_home}/.kube" "${user_home}/.kube/config" 2>/dev/null || true
        chmod 0700 "${user_home}/.kube"
        chmod 0600 "${user_home}/.kube/config"
      fi
    fi
  done

  # Export to /vagrant if mounted and writable
  if [[ -d "/vagrant" && -w "/vagrant" && -f "${ADMIN_CONF}" ]]; then
    if ! cmp -s "${ADMIN_CONF}" "/vagrant/admin.conf" 2>/dev/null; then
      cp -f "${ADMIN_CONF}" /vagrant/admin.conf 2>/dev/null || true
      chmod 0644 /vagrant/admin.conf 2>/dev/null || true
    fi
  fi
}

# 1. Discover all non-loopback, non-CNI IPv4 interface addresses
INTERFACE_IPS=$(ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" && $2 !~ /^(cilium|lxc|flannel|cbr|docker|calico|cni|veth|tunl|dummy|kube-ipvs)/ {print $4}' | cut -d/ -f1 | sort -u || true)

# Target SANs to ensure
TARGET_SANS=()
for ip in ${INTERFACE_IPS}; do
  if [[ -n "${ip}" ]]; then
    TARGET_SANS+=("${ip}")
  fi
done
TARGET_SANS+=("127.0.0.1" "192.168.56.10" "kube-control-plane" "localhost")

HOST_SHORT="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
HOST_FQDN="$(hostname -f 2>/dev/null || true)"
if [[ -n "${HOST_SHORT}" ]]; then TARGET_SANS+=("${HOST_SHORT}"); fi
if [[ -n "${HOST_FQDN}" && "${HOST_FQDN}" != "${HOST_SHORT}" ]]; then TARGET_SANS+=("${HOST_FQDN}"); fi

# Any optional extra SANs passed as arguments
for extra in "$@"; do
  if [[ -n "${extra}" ]]; then
    TARGET_SANS+=("${extra}")
  fi
done

# 2. Extract existing Subject Alternative Names from active apiserver certificate
CURRENT_SANS=$(openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null \
  | grep -v 'X509v3' \
  | tr ',' '\n' \
  | sed -E 's/^\s*(DNS:|IP Address:|IP:)//g' \
  | tr -d ' ' || true)

# 3. Check for any missing SANs
MISSING_SANS=()
for san in "${TARGET_SANS[@]}"; do
  if ! echo "${CURRENT_SANS}" | grep -Fxq "${san}"; then
    MISSING_SANS+=("${san}")
  fi
done

if [[ ${#MISSING_SANS[@]} -eq 0 ]]; then
  # Certificate already contains all interface IPs; ensure kubeconfigs are synced
  propagate_kubeconfig
  exit 0
fi

echo "==> [update-apiserver-sans] Missing SANs detected: ${MISSING_SANS[*]}"
echo "    Reissuing API server certificate with all interface IPs..."

# Combine current and target SANs into a sorted, comma-separated list
COMBINED_SANS=$(printf '%s\n' "${CURRENT_SANS}" "${TARGET_SANS[@]}" | grep -v '^[[:space:]]*$' | sort -u | paste -sd, -)

# Extract advertise address and service cluster IP range from manifest if present
ADV_ADDR=$(grep -E '^\s*-\s*--advertise-address=' "${MANIFEST_FILE}" 2>/dev/null | cut -d= -f2 || true)
SVC_CIDR=$(grep -E '^\s*-\s*--service-cluster-ip-range=' "${MANIFEST_FILE}" 2>/dev/null | cut -d= -f2 || true)

# Backup existing certificate files before reissue
cp -f "${CERT_FILE}" "${CERT_FILE}.bak"
if [[ -f "${KEY_FILE}" ]]; then
  cp -f "${KEY_FILE}" "${KEY_FILE}.bak"
fi

# Remove stale certificate and key so kubeadm generates new ones instead of skipping
rm -f "${CERT_FILE}" "${KEY_FILE}"

# Reissue certificate via kubeadm
KUBEADM_ARGS=(init phase certs apiserver --apiserver-cert-extra-sans="${COMBINED_SANS}")
if [[ -n "${ADV_ADDR}" ]]; then
  KUBEADM_ARGS+=(--apiserver-advertise-address="${ADV_ADDR}")
fi
if [[ -n "${SVC_CIDR}" ]]; then
  KUBEADM_ARGS+=(--service-cidr="${SVC_CIDR}")
fi

if ! kubeadm "${KUBEADM_ARGS[@]}" >/dev/null 2>&1; then
  echo "Error: kubeadm failed to reissue apiserver certificate. Restoring backup..." >&2
  mv -f "${CERT_FILE}.bak" "${CERT_FILE}"
  if [[ -f "${KEY_FILE}.bak" ]]; then
    mv -f "${KEY_FILE}.bak" "${KEY_FILE}"
  fi
  exit 1
fi

# Clean up backups on success
rm -f "${CERT_FILE}.bak" "${KEY_FILE}.bak"

# Restart kube-apiserver static Pod by cycling manifest
if [[ -f "${MANIFEST_FILE}" ]]; then
  TMP_MANIFEST="/tmp/kube-apiserver-restart.yaml"
  mv -f "${MANIFEST_FILE}" "${TMP_MANIFEST}"
  sleep 2
  mv -f "${TMP_MANIFEST}" "${MANIFEST_FILE}"

  # Wait for apiserver to resume responding to health probe
  READY=false
  for _ in $(seq 1 45); do
    if curl -sk https://127.0.0.1:6443/livez 2>/dev/null | grep -q "ok"; then
      READY=true
      break
    fi
    sleep 1
  done

  if [[ "${READY}" != "true" ]]; then
    echo "Warning: API server did not respond to /livez within 45s after certificate reissue." >&2
  fi
fi

# Propagate updated credentials to target users
propagate_kubeconfig

echo "==> [update-apiserver-sans] Certificate reissued and kubeconfigs updated successfully."

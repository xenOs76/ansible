#!/usr/bin/env bash
# ==============================================================================
# Script: sync-kubeconfig.sh
# Purpose: Import and synchronize Kubernetes admin credentials from the
#          control plane into standalone and workstation kubeconfigs (~/.kube/config).
#
# Context:
#   Executed on the HOST machine. Invoked by 'make preprod-sync-kubeconfig',
#   'make prod-sync-kubeconfig', or automatically during cluster deployment.
#
# Usage:
#   ./scripts/sync-kubeconfig.sh [-e preprod|prod] [-b|--best-effort]
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BASE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

ENV="preprod"
BEST_EFFORT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)
      ENV="${2:-preprod}"
      shift 2
      ;;
    -b|--best-effort)
      BEST_EFFORT=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-e preprod|prod] [-b|--best-effort]"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

# ANSI color codes
BOLD=$(printf '\033[1m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m')
CYAN=$(printf '\033[0;36m')
RED=$(printf '\033[0;31m')
RESET=$(printf '\033[0m')

# Check required commands
if ! command -v kubectl >/dev/null 2>&1; then
  echo "${YELLOW}Warning: 'kubectl' not found in PATH. Skipping kubeconfig sync.${RESET}" >&2
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Determine cluster names and defaults based on environment
if [[ "${ENV}" == "preprod" ]]; then
  DEFAULT_CTX="k8s-homelab-preprod"
  DEFAULT_CLUSTER="k8s-homelab-preprod"
  DEFAULT_USER="k8s-homelab-preprod-admin"
else
  DEFAULT_CTX="k8s-homelab"
  DEFAULT_CLUSTER="k8s-homelab"
  DEFAULT_USER="k8s-homelab-admin"
fi

CONTEXT_NAME="${CONTEXT_NAME:-${DEFAULT_CTX}}"
CLUSTER_NAME="${CLUSTER_NAME:-${DEFAULT_CLUSTER}}"
USER_NAME="${USER_NAME:-${DEFAULT_USER}}"
STANDALONE_KUBECONFIG="${BASE_DIR}/kubeconfig.${ENV}"
CLIENT_KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
STAGED_CONF="${BASE_DIR}/admin.conf"

echo "${BOLD}${CYAN}[sync-kubeconfig]${RESET} Synchronizing '${ENV}' Kubernetes admin credentials..."

# 1. Locate or fetch admin.conf
SRC_CONF="${TMP_DIR}/source-admin.conf"
if [[ -f "${STAGED_CONF}" && -s "${STAGED_CONF}" ]]; then
  cp -f "${STAGED_CONF}" "${SRC_CONF}"
elif [[ "${ENV}" == "preprod" ]]; then
  # Fetch admin.conf from running Vagrant VM in a single fast call
  FETCH_SUCCESS=false
  if command -v vagrant >/dev/null 2>&1; then
    if vagrant ssh kube-control-plane -c "sudo cat /etc/kubernetes/admin.conf" > "${SRC_CONF}" 2>/dev/null; then
      FETCH_SUCCESS=true
    fi
  elif [[ -x "${BASE_DIR}/scripts/shell.sh" ]]; then
    if "${BASE_DIR}/scripts/shell.sh" --run "vagrant ssh kube-control-plane -c 'sudo cat /etc/kubernetes/admin.conf'" > "${SRC_CONF}" 2>/dev/null; then
      FETCH_SUCCESS=true
    fi
  fi

  if [[ "${FETCH_SUCCESS}" == "true" && -s "${SRC_CONF}" ]]; then
    # Strip carriage returns and non-YAML banner headers (e.g. from nix-shell or vagrant)
    sed -i 's/\r$//' "${SRC_CONF}"
    sed -i -n '/^\(apiVersion\|kind\):/,$p' "${SRC_CONF}"
  fi

  if [[ "${FETCH_SUCCESS}" == "true" && -s "${SRC_CONF}" ]] && grep -q "apiVersion:" "${SRC_CONF}"; then
    cp -f "${SRC_CONF}" "${STAGED_CONF}"
    chmod 0600 "${STAGED_CONF}"
  else
    rm -f "${STAGED_CONF}" "${STANDALONE_KUBECONFIG}"
    if [[ "${BEST_EFFORT}" == "true" ]]; then
      echo "${CYAN}[sync-kubeconfig]${RESET} Cluster not initialized or VM not running. Skipping credentials sync."
      exit 0
    else
      echo "${RED}Error:${RESET} No initialized Kubernetes cluster found on kube-control-plane." >&2
      echo "       Please start the cluster first: ${BOLD}make preprod-up${RESET} or ${BOLD}make preprod-deploy${RESET}" >&2
      exit 1
    fi
  fi
else
  if [[ "${BEST_EFFORT}" == "true" ]]; then
    echo "${CYAN}[sync-kubeconfig]${RESET} admin.conf not found. Skipping production credentials sync."
    exit 0
  else
    echo "${RED}Error:${RESET} admin.conf not found at ${STAGED_CONF}." >&2
    echo "       Stage the cluster admin.conf or run: ${BOLD}./scripts/run-playbook.sh -e prod -p site.yml${RESET}" >&2
    exit 1
  fi
fi

# Ensure source config is sanitized of any extraneous leading lines
sed -i 's/\r$//' "${SRC_CONF}"
sed -i -n '/^\(apiVersion\|kind\):/,$p' "${SRC_CONF}"

# 2. Resolve Server Endpoint (User Override -> Inventory -> Detected server)
DETECTED_SERVER="$(kubectl --kubeconfig="${SRC_CONF}" config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
API_PORT="$(echo "${DETECTED_SERVER}" | grep -oE '[0-9]+$' || echo "6443")"

# Lookup control plane host from inventory dynamically
INV_HOST=""
INV_FILE="${BASE_DIR}/inventory/${ENV}/hosts.ini"
if [[ -f "${INV_FILE}" ]]; then
  INV_HOST="$(awk '/^\[control_plane\]/{flag=1;next}/^\[/{flag=0}flag && NF{for(i=1;i<=NF;i++)if($i ~ /^ansible_host=/){split($i,a,"=");print a[2];exit}}' "${INV_FILE}" 2>/dev/null || true)"
fi

if [[ -n "${API_SERVER:-}" ]]; then
  EFFECTIVE_SERVER="${API_SERVER}"
elif [[ -n "${INV_HOST}" ]]; then
  EFFECTIVE_SERVER="https://${INV_HOST}:${API_PORT}"
elif [[ -n "${DETECTED_SERVER}" ]]; then
  EFFECTIVE_SERVER="${DETECTED_SERVER}"
else
  EFFECTIVE_SERVER="https://127.0.0.1:6443"
fi

# 3. Extract credentials and assemble standalone kubeconfig
CLIENT_CERT="$(kubectl --kubeconfig="${SRC_CONF}" config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' 2>/dev/null || true)"
CLIENT_KEY="$(kubectl --kubeconfig="${SRC_CONF}" config view --raw -o jsonpath='{.users[0].user.client-key-data}' 2>/dev/null || true)"

if [[ -z "${CLIENT_CERT}" || -z "${CLIENT_KEY}" ]]; then
  echo "${RED}Error:${RESET} Failed to extract client certificate credentials from ${SRC_CONF}." >&2
  echo "       Please verify the cluster is properly initialized." >&2
  exit 1
fi

rm -f "${STANDALONE_KUBECONFIG}"
kubectl --kubeconfig="${STANDALONE_KUBECONFIG}" config set-cluster "${CLUSTER_NAME}" \
  --server="${EFFECTIVE_SERVER}" \
  --insecure-skip-tls-verify=true >/dev/null

kubectl --kubeconfig="${STANDALONE_KUBECONFIG}" config set "users.${USER_NAME}.client-certificate-data" "${CLIENT_CERT}" >/dev/null
kubectl --kubeconfig="${STANDALONE_KUBECONFIG}" config set "users.${USER_NAME}.client-key-data" "${CLIENT_KEY}" >/dev/null

kubectl --kubeconfig="${STANDALONE_KUBECONFIG}" config set-context "${CONTEXT_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --user="${USER_NAME}" >/dev/null

kubectl --kubeconfig="${STANDALONE_KUBECONFIG}" config use-context "${CONTEXT_NAME}" >/dev/null
chmod 0600 "${STANDALONE_KUBECONFIG}"
echo "${GREEN}✔${RESET} Standalone kubeconfig written to: ${STANDALONE_KUBECONFIG}"

# 4. Merge into User's workstation kubeconfig (~/.kube/config)
CLIENT_DIR="$(dirname "${CLIENT_KUBECONFIG}")"
mkdir -p "${CLIENT_DIR}"

if [[ ! -f "${CLIENT_KUBECONFIG}" ]]; then
  cp -f "${STANDALONE_KUBECONFIG}" "${CLIENT_KUBECONFIG}"
  chmod 0600 "${CLIENT_KUBECONFIG}"
  echo "${GREEN}✔${RESET} Created ${CLIENT_KUBECONFIG} (active context: ${CONTEXT_NAME})"
else
  BACKUP_DIR="${CLIENT_DIR}/backups"
  mkdir -p "${BACKUP_DIR}"
  BACKUP_FILE="${BACKUP_DIR}/config.backup.$(date +%Y%m%d_%H%M%S)"
  cp -p "${CLIENT_KUBECONFIG}" "${BACKUP_FILE}"
  chmod 0600 "${BACKUP_FILE}"
  echo "${GREEN}✔${RESET} Backed up existing kubeconfig to: ${BACKUP_FILE}"

  CURRENT_CTX="$(kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config current-context 2>/dev/null || true)"

  # Remove existing entries for this specific cluster/user/context to avoid duplicates
  kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config delete-context "${CONTEXT_NAME}" >/dev/null 2>&1 || true
  kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config delete-cluster "${CLUSTER_NAME}" >/dev/null 2>&1 || true
  kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config delete-user "${USER_NAME}" >/dev/null 2>&1 || true

  # Merge using kubectl config view --flatten
  MERGED_FILE="${TMP_DIR}/merged_config"
  KUBECONFIG="${CLIENT_KUBECONFIG}:${STANDALONE_KUBECONFIG}" kubectl config view --flatten > "${MERGED_FILE}"
  mv -f "${MERGED_FILE}" "${CLIENT_KUBECONFIG}"
  chmod 0600 "${CLIENT_KUBECONFIG}"

  if [[ -n "${CURRENT_CTX}" ]]; then
    kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config use-context "${CURRENT_CTX}" >/dev/null 2>&1 || true
    echo "${GREEN}✔${RESET} Merged context '${CONTEXT_NAME}' into ${CLIENT_KUBECONFIG}"
    echo "  (Active context preserved: '${CURRENT_CTX}')"
  else
    kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config use-context "${CONTEXT_NAME}" >/dev/null 2>&1 || true
    echo "${GREEN}✔${RESET} Merged context '${CONTEXT_NAME}' into ${CLIENT_KUBECONFIG} (active: '${CONTEXT_NAME}')"
  fi
fi

# 5. Verification Probe: Test Host Connectivity
echo ""
echo "Testing host connectivity to cluster endpoint (${EFFECTIVE_SERVER})..."
if kubectl --context="${CONTEXT_NAME}" get nodes -o wide --request-timeout=3s; then
  echo ""
  echo "${BOLD}${GREEN}✔ Kubernetes credentials (${ENV}) synchronized and verified successfully!${RESET}"
else
  echo ""
  echo "${YELLOW}Warning: Credentials synchronized, but cluster endpoint did not respond within 3s.${RESET}"
  echo "         Please ensure kube-apiserver is running on ${EFFECTIVE_SERVER}."
fi

echo ""
echo "Summary:"
echo "  - Environment: ${CYAN}${ENV}${RESET}"
echo "  - Cluster:     ${CYAN}${CLUSTER_NAME}${RESET}"
echo "  - Context:     ${CYAN}${CONTEXT_NAME}${RESET}"
echo "  - User:        ${CYAN}${USER_NAME}${RESET}"
echo "  - Server:      ${CYAN}${EFFECTIVE_SERVER}${RESET}"
echo ""
echo "Usage options:"
echo "  1. Direct context execution:"
echo "     ${GREEN}kubectl --context=${CONTEXT_NAME} get nodes${RESET}"
echo "  2. Switch active context:"
echo "     ${GREEN}kubectl config use-context ${CONTEXT_NAME}${RESET}"
echo "  3. Use standalone config:"
echo "     ${GREEN}export KUBECONFIG=${STANDALONE_KUBECONFIG}${RESET}"

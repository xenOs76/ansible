#!/usr/bin/env bash
# ==============================================================================
# Script: sync-kubeconfig.sh
# Purpose: Non-disruptively synchronize Kubernetes cluster admin credentials
#          from the preprod Vagrant environment to the local client machine.
#
# Context:
#   Executed on the HOST machine (not inside VMs). Can be invoked manually,
#   via 'make preprod-sync-kubeconfig', or automatically at the completion
#   of 'make preprod-up'.
#
# Non-Disruptive Safety Guarantees:
#   1. Zero Data Loss: Automatically backs up existing ~/.kube/config to
#      ~/.kube/backups/config.backup.<YYYYMMDD_HHMMSS> prior to any mutation.
#   2. Namespacing: Renames generic 'kubernetes' cluster, 'kubernetes-admin' user,
#      and context to 'homelab-k8s' / 'homelab-k8s-admin'.
#   3. Context Preservation: Captures the active current-context before merging
#      and restores it immediately afterwards, ensuring no interruption to
#      unrelated cluster workflows.
#   4. Standalone File: Generates 'kubeconfig.preprod' (mode 0600) in the
#      repo root for isolated cluster interaction via KUBECONFIG export.
#   5. Idempotent & Safe: Safe to run repeatedly; refreshes tokens/certs without
#      duplicating entries. Exits 0 if the cluster is not yet initialized.
#
# Usage:
#   ./scripts/sync-kubeconfig.sh
#   # Or via Makefile:
#   make preprod-sync-kubeconfig
#
# Configurable Environment Variables:
#   CLUSTER_NAME     - Name for the cluster entry (default: homelab-k8s).
#   USER_NAME        - Name for the user credential entry (default: homelab-k8s-admin).
#   CONTEXT_NAME     - Name for the context entry (default: homelab-k8s).
#   API_SERVER       - External HTTPS URL of the Kubernetes API server
#                      (default: https://192.168.56.10:6443).
#   KUBECONFIG       - Target client kubeconfig file (default: ~/.kube/config).
#
# Prerequisites:
#   - 'kubectl' and 'python3' available in PATH on the host machine.
#   - Control plane node initialized with '/etc/kubernetes/admin.conf' or
#     'admin.conf' cached in repository root.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-homelab-k8s}"
USER_NAME="${USER_NAME:-homelab-k8s-admin}"
CONTEXT_NAME="${CONTEXT_NAME:-homelab-k8s}"
API_SERVER="${API_SERVER:-https://192.168.56.10:6443}"
STANDALONE_KUBECONFIG="${BASE_DIR}/kubeconfig.preprod"
CLIENT_KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"

# ANSI color codes
BOLD=$(printf '\033[1m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m')
CYAN=$(printf '\033[0;36m')
RESET=$(printf '\033[0m')

# Check required commands
if ! command -v kubectl >/dev/null 2>&1; then
  echo "${YELLOW}Warning: 'kubectl' not found in PATH. Skipping kubeconfig sync.${RESET}" >&2
  echo "Hint: Install kubectl or enter nix-shell to sync credentials." >&2
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "${YELLOW}Warning: 'python3' not found in PATH. Skipping kubeconfig sync.${RESET}" >&2
  exit 0
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

RAW_ADMIN="${TMP_DIR}/raw-admin.conf"

# ------------------------------------------------------------------------------
# 1. Discover admin.conf source (local cache or live VM)
# ------------------------------------------------------------------------------
if [[ -f "${BASE_DIR}/admin.conf" && -s "${BASE_DIR}/admin.conf" ]]; then
  cp -f "${BASE_DIR}/admin.conf" "${RAW_ADMIN}"
elif [[ -x "${BASE_DIR}/scripts/shell.sh" ]]; then
  # Fast check: if virsh is available and VM is not running, skip vagrant ssh
  vm_running=true
  if command -v virsh >/dev/null 2>&1; then
    if ! virsh list --state-running --name 2>/dev/null | grep -q "kube-control-plane"; then
      vm_running=false
    fi
  fi

  if [[ "${vm_running}" == "true" ]]; then
    # Try pulling from kube-control-plane VM if running
    if "${BASE_DIR}/scripts/shell.sh" --run "vagrant ssh kube-control-plane -c 'sudo cat /etc/kubernetes/admin.conf'" > "${RAW_ADMIN}" 2>/dev/null \
      && [[ -s "${RAW_ADMIN}" ]] && grep -q "apiVersion" "${RAW_ADMIN}"; then
      cp -f "${RAW_ADMIN}" "${BASE_DIR}/admin.conf"
      chmod 0600 "${BASE_DIR}/admin.conf" 2>/dev/null || true
    fi
  fi
fi

# If no valid admin config is available, notify gracefully and exit 0
if [[ ! -s "${RAW_ADMIN}" ]] || ! grep -q "apiVersion" "${RAW_ADMIN}"; then
  echo "${CYAN}[sync-kubeconfig]${RESET} No initialized cluster credentials found (admin.conf)."
  echo "                  If this is a fresh cluster, initialize the control plane first:"
  echo "                    vagrant ssh kube-control-plane -c 'sudo /vagrant/scripts/control-plane.sh 172.18.0.0/16 192.168.56.10'"
  echo "                  Then run ${BOLD}make preprod-sync-kubeconfig${RESET} to sync credentials."
  exit 0
fi

echo "${BOLD}${CYAN}[sync-kubeconfig]${RESET} Processing Kubernetes admin credentials..."

# ------------------------------------------------------------------------------
# 2. Extract JSON representation
# ------------------------------------------------------------------------------
kubectl --kubeconfig="${RAW_ADMIN}" config view --raw -o json > "${TMP_DIR}/admin.json"

# ------------------------------------------------------------------------------
# 3. Transform config: namespace cluster, user, and context
# ------------------------------------------------------------------------------
python3 - "${TMP_DIR}/admin.json" "${API_SERVER}" "${CLUSTER_NAME}" "${USER_NAME}" "${CONTEXT_NAME}" <<'PYEOF'
import json
import sys

json_file = sys.argv[1]
api_server = sys.argv[2]
cluster_name = sys.argv[3]
user_name = sys.argv[4]
context_name = sys.argv[5]

with open(json_file, "r", encoding="utf-8") as f:
    data = json.load(f)

for c in data.get("clusters", []):
    c["name"] = cluster_name
    if "cluster" in c:
        c["cluster"]["server"] = api_server

for u in data.get("users", []):
    u["name"] = user_name

for ctx in data.get("contexts", []):
    ctx["name"] = context_name
    if "context" in ctx:
        ctx["context"]["cluster"] = cluster_name
        ctx["context"]["user"] = user_name

data["current-context"] = context_name

with open(json_file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
PYEOF

# ------------------------------------------------------------------------------
# 4. Generate standalone kubeconfig (mode 0600)
# ------------------------------------------------------------------------------
kubectl --kubeconfig="${TMP_DIR}/admin.json" config view --raw > "${STANDALONE_KUBECONFIG}"
chmod 0600 "${STANDALONE_KUBECONFIG}"
echo "${GREEN}✔${RESET} Standalone kubeconfig written to: ${STANDALONE_KUBECONFIG}"

# ------------------------------------------------------------------------------
# 5. Non-disruptive merge into local client kubeconfig
# ------------------------------------------------------------------------------
CLIENT_DIR="$(dirname "${CLIENT_KUBECONFIG}")"
mkdir -p "${CLIENT_DIR}"

if [[ ! -f "${CLIENT_KUBECONFIG}" ]]; then
  cp -f "${STANDALONE_KUBECONFIG}" "${CLIENT_KUBECONFIG}"
  chmod 0600 "${CLIENT_KUBECONFIG}"
  echo "${GREEN}✔${RESET} Created ${CLIENT_KUBECONFIG} (active context: ${CONTEXT_NAME})"
else
  # Backup existing kubeconfig
  BACKUP_DIR="${CLIENT_DIR}/backups"
  mkdir -p "${BACKUP_DIR}"
  BACKUP_FILE="${BACKUP_DIR}/config.backup.$(date +%Y%m%d_%H%M%S)"
  cp -p "${CLIENT_KUBECONFIG}" "${BACKUP_FILE}"
  chmod 0600 "${BACKUP_FILE}"
  echo "${GREEN}✔${RESET} Backed up existing kubeconfig to: ${BACKUP_FILE}"

  # Capture current active context
  CURRENT_CTX="$(kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config current-context 2>/dev/null || true)"

  # Remove existing homelab entries to ensure updated credentials take precedence
  kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config delete-context "${CONTEXT_NAME}" >/dev/null 2>&1 || true
  kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config delete-cluster "${CLUSTER_NAME}" >/dev/null 2>&1 || true
  kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config delete-user "${USER_NAME}" >/dev/null 2>&1 || true

  # Merge using kubectl config view --flatten
  MERGED_FILE="${TMP_DIR}/merged_config"
  KUBECONFIG="${CLIENT_KUBECONFIG}:${STANDALONE_KUBECONFIG}" kubectl config view --flatten > "${MERGED_FILE}"
  mv -f "${MERGED_FILE}" "${CLIENT_KUBECONFIG}"
  chmod 0600 "${CLIENT_KUBECONFIG}"

  # Restore active context without disrupting user's current workflow
  if [[ -n "${CURRENT_CTX}" ]]; then
    kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config use-context "${CURRENT_CTX}" >/dev/null 2>&1 || true
    echo "${GREEN}✔${RESET} Merged context '${CONTEXT_NAME}' into ${CLIENT_KUBECONFIG}"
    echo "  (Active context preserved: '${CURRENT_CTX}')"
  else
    kubectl --kubeconfig="${CLIENT_KUBECONFIG}" config use-context "${CONTEXT_NAME}" >/dev/null 2>&1 || true
    echo "${GREEN}✔${RESET} Merged context '${CONTEXT_NAME}' into ${CLIENT_KUBECONFIG} (active: '${CONTEXT_NAME}')"
  fi
fi

echo ""
echo "${BOLD}${GREEN}Kubernetes credentials synchronized successfully!${RESET}"
echo "  - Cluster: ${CYAN}${CLUSTER_NAME}${RESET}"
echo "  - Context: ${CYAN}${CONTEXT_NAME}${RESET}"
echo "  - User:    ${CYAN}${USER_NAME}${RESET}"
echo "  - Server:  ${CYAN}${API_SERVER}${RESET}"
echo ""
echo "Usage options:"
echo "  1. Direct context execution:"
echo "     ${GREEN}kubectl --context=${CONTEXT_NAME} get nodes${RESET}"
echo "  2. Switch active context:"
echo "     ${GREEN}kubectl config use-context ${CONTEXT_NAME}${RESET}"
echo "  3. Use standalone config:"
echo "     ${GREEN}export KUBECONFIG=${STANDALONE_KUBECONFIG}${RESET}"

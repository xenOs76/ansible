#!/usr/bin/env bash
# ==============================================================================
# Script: sync-kubeconfig.sh
# Purpose: Non-disruptively synchronize Kubernetes cluster admin credentials
#          from the preprod Vagrant environment to the local client machine.
#
# Context:
#   Executed on the HOST machine (not inside VMs). Can be invoked manually via
#   'make preprod-sync-kubeconfig' (strict mode) or automatically at the completion
#   of 'make preprod-up' (--best-effort mode).
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
#      duplicating entries.
#   6. Clean File Transfer: Directs the VM to write '/vagrant/admin.conf' on the
#      shared mount, completely eliminating stdout terminal/nix banner pollution.
#   7. Dynamic TLS Server Resolution: Automatically detects the server IP from
#      the cluster certificates so TLS SAN validation succeeds whether kubeadm
#      bound to 192.168.121.x (default NAT) or 192.168.56.10 (host-only).
#
# Usage:
#   ./scripts/sync-kubeconfig.sh [--best-effort]
#   # Or via Makefile:
#   make preprod-sync-kubeconfig
#
# Arguments:
#   --best-effort, -b  (Optional) Suppress non-zero exit codes if cluster is
#                      uninitialized. Used during automated 'make preprod-up'.
#
# Configurable Environment Variables:
#   CLUSTER_NAME     - Name for the cluster entry (default: homelab-k8s).
#   USER_NAME        - Name for the user credential entry (default: homelab-k8s-admin).
#   CONTEXT_NAME     - Name for the context entry (default: homelab-k8s).
#   API_SERVER       - External HTTPS URL of the Kubernetes API server.
#                      Default: Auto-detected from cluster admin.conf to match TLS SANs.
#   KUBECONFIG       - Target client kubeconfig file (default: ~/.kube/config).
#
# Prerequisites:
#   - 'kubectl' and 'python3' available in PATH on the host machine.
#   - Control plane VM running and initialized with /etc/kubernetes/admin.conf.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BEST_EFFORT=false
if [[ "${1:-}" == "--best-effort" || "${1:-}" == "-b" ]]; then
  BEST_EFFORT=true
fi

CLUSTER_NAME="${CLUSTER_NAME:-homelab-k8s}"
USER_NAME="${USER_NAME:-homelab-k8s-admin}"
CONTEXT_NAME="${CONTEXT_NAME:-homelab-k8s}"
USER_OVERRIDE_API_SERVER="${API_SERVER:-}"
STANDALONE_KUBECONFIG="${BASE_DIR}/kubeconfig.preprod"
CLIENT_KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"

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

# ------------------------------------------------------------------------------
# 1. Discover admin.conf source (local cache or live VM)
# ------------------------------------------------------------------------------
staged_local_conf="${BASE_DIR}/admin.conf"

# If local admin.conf doesn't exist or is invalid, attempt to fetch from running VM
needs_fetch=true
if [[ -f "${staged_local_conf}" && -s "${staged_local_conf}" ]]; then
  if grep -q "apiVersion:" "${staged_local_conf}"; then
    needs_fetch=false
  fi
fi

if [[ "${needs_fetch}" == "true" ]]; then
  # Check if kube-control-plane VM is running
  vm_running=true
  if command -v virsh >/dev/null 2>&1; then
    if ! virsh list --state-running --name 2>/dev/null | grep -q "kube-control-plane"; then
      vm_running=false
    fi
  fi

  if [[ "${vm_running}" == "false" ]]; then
    if [[ "${BEST_EFFORT}" == "true" ]]; then
      echo "${CYAN}[sync-kubeconfig]${RESET} kube-control-plane VM is not running yet. Skipping credentials sync."
      exit 0
    else
      echo "${RED}Error:${RESET} kube-control-plane VM is shut off." >&2
      echo "       Please start the environment first: ${BOLD}make preprod-up${RESET}" >&2
      exit 1
    fi
  fi

  # VM is running: copy /etc/kubernetes/admin.conf directly to shared /vagrant mount
  # This completely eliminates stdout banner corruption from nix-shell / vagrant ssh
  if [[ -x "${BASE_DIR}/scripts/shell.sh" ]]; then
    "${BASE_DIR}/scripts/shell.sh" --run \
      "vagrant ssh kube-control-plane -c 'sudo cp -f /etc/kubernetes/admin.conf /vagrant/admin.conf 2>/dev/null && sudo chmod 0644 /vagrant/admin.conf'" \
      >/dev/null 2>&1 || true
  fi
fi

# Validate discovered admin.conf
if [[ ! -f "${staged_local_conf}" || ! -s "${staged_local_conf}" ]] || ! grep -q "apiVersion:" "${staged_local_conf}"; then
  if [[ "${BEST_EFFORT}" == "true" ]]; then
    echo "${CYAN}[sync-kubeconfig]${RESET} Kubernetes cluster not initialized yet. Skipping credentials sync."
    exit 0
  else
    echo "${RED}Error:${RESET} No initialized Kubernetes credentials found on kube-control-plane." >&2
    echo "       If this is a fresh cluster, initialize the control plane inside the VM:" >&2
    echo "         ${GREEN}vagrant ssh kube-control-plane -c 'sudo /vagrant/scripts/control-plane.sh 172.18.0.0/16 192.168.56.10'${RESET}" >&2
    echo "         # Or follow the manual CKA drill steps in README.md" >&2
    echo "       Then run: ${BOLD}make preprod-sync-kubeconfig${RESET}" >&2
    exit 1
  fi
fi

echo "${BOLD}${CYAN}[sync-kubeconfig]${RESET} Processing Kubernetes admin credentials..."

# ------------------------------------------------------------------------------
# 2. Sanitize and Extract YAML (Defense-in-depth: strip any non-YAML header lines)
# ------------------------------------------------------------------------------
RAW_ADMIN="${TMP_DIR}/sanitized-admin.conf"
sed -n '/^apiVersion:/,$p' "${staged_local_conf}" > "${RAW_ADMIN}"
if [[ ! -s "${RAW_ADMIN}" ]]; then
  sed -n '/^kind:/,$p' "${staged_local_conf}" > "${RAW_ADMIN}"
fi

# Convert to JSON representation for programmatic editing
kubectl --kubeconfig="${RAW_ADMIN}" config view --raw -o json > "${TMP_DIR}/admin.json"

# ------------------------------------------------------------------------------
# 3. Dynamic API Server URL Resolution (Preserve TLS certificate SAN validity)
# ------------------------------------------------------------------------------
DETECTED_SERVER=$(python3 - "${TMP_DIR}/admin.json" <<'PYEOF'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
for c in data.get("clusters", []):
    server = c.get("cluster", {}).get("server", "")
    if server:
        print(server)
        sys.exit(0)
print("")
PYEOF
)

if [[ -n "${USER_OVERRIDE_API_SERVER}" ]]; then
  EFFECTIVE_API_SERVER="${USER_OVERRIDE_API_SERVER}"
elif [[ -n "${DETECTED_SERVER}" && "${DETECTED_SERVER}" != *"127.0.0.1"* && "${DETECTED_SERVER}" != *"localhost"* ]]; then
  # Preserve the server IP that matches the TLS certificate SANs generated by kubeadm
  EFFECTIVE_API_SERVER="${DETECTED_SERVER}"
else
  EFFECTIVE_API_SERVER="https://192.168.56.10:6443"
fi

# ------------------------------------------------------------------------------
# 4. Transform config: namespace cluster, user, and context
# ------------------------------------------------------------------------------
python3 - "${TMP_DIR}/admin.json" "${EFFECTIVE_API_SERVER}" "${CLUSTER_NAME}" "${USER_NAME}" "${CONTEXT_NAME}" <<'PYEOF'
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
# 5. Generate standalone kubeconfig (mode 0600)
# ------------------------------------------------------------------------------
kubectl --kubeconfig="${TMP_DIR}/admin.json" config view --raw > "${STANDALONE_KUBECONFIG}"
chmod 0600 "${STANDALONE_KUBECONFIG}"
echo "${GREEN}✔${RESET} Standalone kubeconfig written to: ${STANDALONE_KUBECONFIG}"

# ------------------------------------------------------------------------------
# 6. Non-disruptive merge into local client kubeconfig
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

# ------------------------------------------------------------------------------
# 7. Verification Probe: Test Host Connectivity to Cluster
# ------------------------------------------------------------------------------
echo ""
echo "Testing host connectivity to cluster endpoint (${EFFECTIVE_API_SERVER})..."
if kubectl --context="${CONTEXT_NAME}" get nodes -o wide --request-timeout=5s; then
  echo ""
  echo "${BOLD}${GREEN}✔ Kubernetes credentials synchronized and verified successfully!${RESET}"
else
  echo ""
  echo "${YELLOW}Warning: Credentials synchronized, but cluster endpoint did not respond within 5s.${RESET}"
  echo "         Please ensure kube-apiserver is running on kube-control-plane."
fi

echo ""
echo "Summary:"
echo "  - Cluster: ${CYAN}${CLUSTER_NAME}${RESET}"
echo "  - Context: ${CYAN}${CONTEXT_NAME}${RESET}"
echo "  - User:    ${CYAN}${USER_NAME}${RESET}"
echo "  - Server:  ${CYAN}${EFFECTIVE_API_SERVER}${RESET}"
echo ""
echo "Usage options:"
echo "  1. Direct context execution:"
echo "     ${GREEN}kubectl --context=${CONTEXT_NAME} get nodes${RESET}"
echo "  2. Switch active context:"
echo "     ${GREEN}kubectl config use-context ${CONTEXT_NAME}${RESET}"
echo "  3. Use standalone config:"
echo "     ${GREEN}export KUBECONFIG=${STANDALONE_KUBECONFIG}${RESET}"

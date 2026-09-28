#!/usr/bin/env bash
# ==============================================================================
# Script: sync-kubeconfig.sh
# Purpose: Non-disruptively synchronize Kubernetes cluster admin credentials
#          from preprod (Vagrant) or production environments to the local
#          client machine (~/.kube/config).
#
# Context:
#   Executed on the HOST machine (not inside VMs). Can be invoked manually via
#   'make preprod-sync-kubeconfig', automatically at the completion of
#   'make preprod-up' (--best-effort mode), or directly via Ansible playbooks.
#
# Environment Integration & Defaults:
#   - Preprod Environment (-e preprod):
#       Context: k8s-homelab-preprod
#       Cluster: k8s-homelab-preprod
#       User:    k8s-homelab-preprod-admin
#       File:    k8s-homelab/kubeconfig.preprod
#   - Production Environment (-e prod):
#       Context: k8s-homelab
#       Cluster: k8s-homelab
#       User:    k8s-homelab-admin
#       File:    k8s-homelab/kubeconfig.prod
#
#   All settings dynamically inherit configuration values from Ansible:
#   group_vars/<env>.yml -> group_vars/all.yml (k8s_context_name, cluster_name, k8s_user_name).
#   Values can also be overridden via environment variables (CONTEXT_NAME, CLUSTER_NAME, USER_NAME).
#
# Non-Disruptive Safety Guarantees:
#   1. Zero Data Loss: Automatically backs up existing ~/.kube/config to
#      ~/.kube/backups/config.backup.<YYYYMMDD_HHMMSS> prior to any mutation.
#   2. Environment Isolation: Keeps preprod (k8s-homelab-preprod) and prod (k8s-homelab)
#      distinct so developers can seamlessly manage both clusters from one machine.
#   3. Context Preservation: Captures the active current-context before merging
#      and restores it immediately afterwards, ensuring no interruption to
#      unrelated cluster workflows.
#   4. Standalone Files: Generates 'kubeconfig.<env>' (mode 0600) in the
#      repo root for isolated cluster interaction via KUBECONFIG export.
#   5. Dynamic TLS Server Resolution: Automatically detects the server IP from
#      the cluster certificates so TLS SAN validation succeeds whether kubeadm
#      bound to 192.168.121.x (default NAT) or 192.168.56.10 (host-only).
#
# Usage:
#   ./scripts/sync-kubeconfig.sh [-e <preprod|prod>] [--best-effort]
#   # Or via Makefile:
#   make preprod-sync-kubeconfig
#   make prod-sync-kubeconfig
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV="preprod"
BEST_EFFORT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)
      ENV="$2"
      shift 2
      ;;
    -b|--best-effort)
      BEST_EFFORT=true
      shift
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
# 1. Resolve Configuration from Ansible group_vars & Environment Variables
# ------------------------------------------------------------------------------
RESOLVED_VARS=$(python3 - "${BASE_DIR}" "${ENV}" <<'PYEOF'
import os, sys, yaml

base_dir = sys.argv[1]
env = sys.argv[2]

default_ctx = "k8s-homelab-preprod" if env == "preprod" else "k8s-homelab"
default_cluster = "k8s-homelab-preprod" if env == "preprod" else "k8s-homelab"
default_user = "k8s-homelab-preprod-admin" if env == "preprod" else "k8s-homelab-admin"

def lookup(key, fallback):
    for rel_path in [f"group_vars/{env}.yml", "group_vars/all.yml"]:
        full_path = os.path.join(base_dir, rel_path)
        if os.path.isfile(full_path):
            try:
                with open(full_path, "r", encoding="utf-8") as f:
                    data = yaml.safe_load(f) or {}
                    if key in data and data[key]:
                        return str(data[key])
            except Exception:
                pass
    return fallback

ctx = os.environ.get("CONTEXT_NAME") or lookup("k8s_context_name", default_ctx)
cluster = os.environ.get("CLUSTER_NAME") or lookup("cluster_name", default_cluster)
user = os.environ.get("USER_NAME") or lookup("k8s_user_name", default_user)

print(f"{ctx}|{cluster}|{user}")
PYEOF
)

IFS='|' read -r CONTEXT_NAME CLUSTER_NAME USER_NAME <<< "${RESOLVED_VARS}"
STANDALONE_KUBECONFIG="${BASE_DIR}/kubeconfig.${ENV}"
CLIENT_KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
USER_OVERRIDE_API_SERVER="${API_SERVER:-}"

# ------------------------------------------------------------------------------
# 2. Discover admin.conf source (local file or preprod Vagrant VM)
# ------------------------------------------------------------------------------
staged_local_conf="${BASE_DIR}/admin.conf"

if [[ "${ENV}" == "preprod" ]]; then
  # In preprod: probe live kube-control-plane VM to avoid using stale leftover credentials
  vm_running=false
  if command -v virsh >/dev/null 2>&1; then
    if virsh list --state-running --name 2>/dev/null | grep -q "kube-control-plane"; then
      vm_running=true
    fi
  fi
  if [[ "${vm_running}" == "false" ]] && [[ -x "${BASE_DIR}/scripts/shell.sh" ]]; then
    if "${BASE_DIR}/scripts/shell.sh" --run "vagrant status kube-control-plane" 2>/dev/null | grep -E "kube-control-plane\s+running" >/dev/null 2>&1; then
      vm_running=true
    fi
  fi

  if [[ "${vm_running}" == "false" ]]; then
    # Invalidate stale credentials left on host from earlier runs
    rm -f "${staged_local_conf}" "${STANDALONE_KUBECONFIG}"
    if [[ "${BEST_EFFORT}" == "true" ]]; then
      echo "${CYAN}[sync-kubeconfig]${RESET} kube-control-plane VM is not running. Skipping credentials sync."
      exit 0
    else
      echo "${RED}Error:${RESET} kube-control-plane VM is shut off." >&2
      echo "       Please start the environment first: ${BOLD}make preprod-up${RESET}" >&2
      exit 1
    fi
  fi

  # VM is running: check whether Kubernetes has actually been initialized inside it
  has_cluster=false
  if [[ -x "${BASE_DIR}/scripts/shell.sh" ]]; then
    if "${BASE_DIR}/scripts/shell.sh" --run "vagrant ssh kube-control-plane -c 'sudo test -s /etc/kubernetes/admin.conf'" >/dev/null 2>&1; then
      has_cluster=true
    fi
  fi

  if [[ "${has_cluster}" == "false" ]]; then
    # Cluster not initialized yet: purge stale files so they never trick the host
    rm -f "${staged_local_conf}" "${STANDALONE_KUBECONFIG}"
    if [[ "${BEST_EFFORT}" == "true" ]]; then
      echo "${CYAN}[sync-kubeconfig]${RESET} Kubernetes cluster (${ENV}) not initialized yet. Skipping credentials sync."
      exit 0
    else
      echo "${RED}Error:${RESET} No initialized Kubernetes cluster found on kube-control-plane (/etc/kubernetes/admin.conf missing)." >&2
      echo "       Initialize the control plane inside the VM first:" >&2
      echo "         ${GREEN}make preprod-deploy${RESET}" >&2
      echo "         # or: vagrant ssh kube-control-plane -c 'sudo /vagrant/scripts/control-plane.sh 172.18.0.0/16 192.168.56.10'${RESET}" >&2
      exit 1
    fi
  fi

  # Fetch fresh admin.conf directly from the running VM
  rm -f "${staged_local_conf}"
  "${BASE_DIR}/scripts/shell.sh" --run \
    "vagrant ssh kube-control-plane -c 'sudo cat /etc/kubernetes/admin.conf'" > "${staged_local_conf}" 2>/dev/null || true
  chmod 0600 "${staged_local_conf}"
else
  # In production: admin.conf must be fetched via Ansible playbook or staged locally
  if [[ ! -f "${staged_local_conf}" || ! -s "${staged_local_conf}" ]] || ! grep -q "apiVersion:" "${staged_local_conf}"; then
    if [[ "${BEST_EFFORT}" == "true" ]]; then
      echo "${CYAN}[sync-kubeconfig]${RESET} admin.conf not found. Skipping production credentials sync."
      exit 0
    else
      echo "${RED}Error:${RESET} admin.conf not found at ${staged_local_conf}." >&2
      echo "       For production, run: ${BOLD}./scripts/run-playbook.sh -e prod -p site.yml${RESET}" >&2
      echo "       or stage the cluster admin.conf to ${staged_local_conf} manually." >&2
      exit 1
    fi
  fi
fi

echo "${BOLD}${CYAN}[sync-kubeconfig]${RESET} Processing '${ENV}' Kubernetes admin credentials..."

# ------------------------------------------------------------------------------
# 3. Sanitize and Extract YAML (strip any non-YAML header lines)
# ------------------------------------------------------------------------------
RAW_ADMIN="${TMP_DIR}/sanitized-admin.conf"
sed -n '/^apiVersion:/,$p' "${staged_local_conf}" > "${RAW_ADMIN}"
if [[ ! -s "${RAW_ADMIN}" ]]; then
  sed -n '/^kind:/,$p' "${staged_local_conf}" > "${RAW_ADMIN}"
fi

kubectl --kubeconfig="${RAW_ADMIN}" config view --raw -o json > "${TMP_DIR}/admin.json"

# ------------------------------------------------------------------------------
# 4. Dynamic API Server URL Resolution (Preserve TLS certificate SAN validity)
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
  EFFECTIVE_API_SERVER="${DETECTED_SERVER}"
else
  EFFECTIVE_API_SERVER="https://192.168.56.10:6443"
fi

# ------------------------------------------------------------------------------
# 5. Transform config: namespace cluster, user, and context
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
# 6. Generate standalone kubeconfig (mode 0600)
# ------------------------------------------------------------------------------
kubectl --kubeconfig="${TMP_DIR}/admin.json" config view --raw > "${STANDALONE_KUBECONFIG}"
chmod 0600 "${STANDALONE_KUBECONFIG}"
echo "${GREEN}✔${RESET} Standalone kubeconfig written to: ${STANDALONE_KUBECONFIG}"

# ------------------------------------------------------------------------------
# 7. Non-disruptive merge into local client kubeconfig
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

  # Remove existing entries for this specific cluster/user/context to ensure updated credentials take precedence
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
# 8. Verification Probe: Test Host Connectivity to Cluster
# ------------------------------------------------------------------------------
echo ""
echo "Testing host connectivity to cluster endpoint (${EFFECTIVE_API_SERVER})..."
if kubectl --context="${CONTEXT_NAME}" get nodes -o wide --request-timeout=5s; then
  echo ""
  echo "${BOLD}${GREEN}✔ Kubernetes credentials (${ENV}) synchronized and verified successfully!${RESET}"
else
  echo ""
  echo "${YELLOW}Warning: Credentials synchronized, but cluster endpoint did not respond within 5s.${RESET}"
  echo "         Please ensure kube-apiserver is running on the control plane node."
fi

echo ""
echo "Summary:"
echo "  - Environment: ${CYAN}${ENV}${RESET}"
echo "  - Cluster:     ${CYAN}${CLUSTER_NAME}${RESET}"
echo "  - Context:     ${CYAN}${CONTEXT_NAME}${RESET}"
echo "  - User:        ${CYAN}${USER_NAME}${RESET}"
echo "  - Server:      ${CYAN}${EFFECTIVE_API_SERVER}${RESET}"
echo ""
echo "Usage options:"
echo "  1. Direct context execution:"
echo "     ${GREEN}kubectl --context=${CONTEXT_NAME} get nodes${RESET}"
echo "  2. Switch active context:"
echo "     ${GREEN}kubectl config use-context ${CONTEXT_NAME}${RESET}"
echo "  3. Use standalone config:"
echo "     ${GREEN}export KUBECONFIG=${STANDALONE_KUBECONFIG}${RESET}"

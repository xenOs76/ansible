#!/usr/bin/env bash
# ==============================================================================
# Script: check-ceph-status.sh
# Purpose: Comprehensive diagnostic and status inspection tool for Rook-Ceph.
#          Gracefully handles failing/crashed operators, displays detailed pod
#          events, inspects CephCluster CR health, and runs native 'ceph status'
#          via Ceph daemons or the Rook toolbox.
#
# Usage:
#   ./scripts/check-ceph-status.sh [OPTIONS]
#
# Options:
#   -n, --namespace <name>   Rook-Ceph namespace (default: rook-ceph)
#   -c, --cluster <name>     CephCluster name (default: rook-ceph)
#   -t, --toolbox            Ensure rook-ceph-tools deployment is running & query it
#   -v, --verbose            Include full recent events and extended logs
#   -h, --help               Display this help text
# ==============================================================================
set -euo pipefail

# ANSI color escapes
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

NAMESPACE="rook-ceph"
CLUSTER_NAME="rook-ceph"
ENSURE_TOOLBOX=false
VERBOSE=false

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Comprehensive diagnostic and status inspection tool for Rook-Ceph storage.

Options:
  -n, --namespace <name>   Rook-Ceph namespace (default: rook-ceph)
  -c, --cluster <name>     CephCluster custom resource name (default: rook-ceph)
  -t, --toolbox            Deploy or verify rook-ceph-tools pod for native ceph CLI
  -v, --verbose            Show verbose logs and full namespace events
  -h, --help               Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -c|--cluster)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    -t|--toolbox)
      ENSURE_TOOLBOX=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${RESET}" >&2
      show_help
      exit 1
      ;;
  esac
done

# Prerequisite checks
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${RED}Error: 'kubectl' command not found in PATH.${RESET}" >&2
  exit 1
fi

# Detect KUBECONFIG if running on control plane node
if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/kubernetes/admin.conf ] && [ ! -f "${HOME}/.kube/config" ]; then
  export KUBECONFIG=/etc/kubernetes/admin.conf
fi

echo -e "${BOLD}${BLUE}====================================================================${RESET}"
echo -e "${BOLD}${BLUE}               Rook-Ceph Cluster Diagnostics & Status                ${RESET}"
echo -e "${BOLD}${BLUE}====================================================================${RESET}"
echo -e "Namespace:   ${BOLD}${NAMESPACE}${RESET}"
echo -e "CephCluster: ${BOLD}${CLUSTER_NAME}${RESET}"
echo ""

# ------------------------------------------------------------------------------
# 1. Namespace & Helm Release State
# ------------------------------------------------------------------------------
echo -e "${BOLD}[1/5] Checking Rook-Ceph Namespace & Helm Release...${RESET}"
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo -e "${RED}✖ Error: Namespace '${NAMESPACE}' does not exist.${RESET}"
  echo "Hint: The Rook-Ceph operator has not been deployed yet. Run: make preprod-ceph"
  exit 1
fi
echo -e "  ${GREEN}✔ Namespace '${NAMESPACE}' exists.${RESET}"

if command -v helm >/dev/null 2>&1; then
  HELM_STATUS="$(helm status "${CLUSTER_NAME}-operator" -n "${NAMESPACE}" 2>/dev/null || true)"
  if [ -n "${HELM_STATUS}" ]; then
    HELM_PHASE="$(echo "${HELM_STATUS}" | awk '/STATUS:/ {print $2}' || true)"
    if [ "${HELM_PHASE}" = "deployed" ]; then
      echo -e "  ${GREEN}✔ Helm Release '${CLUSTER_NAME}-operator': deployed${RESET}"
    else
      echo -e "  ${YELLOW}⚠ Helm Release '${CLUSTER_NAME}-operator': ${HELM_PHASE}${RESET}"
    fi
  else
    echo -e "  ${YELLOW}ℹ Helm Release '${CLUSTER_NAME}-operator' not found via helm.${RESET}"
  fi
fi
echo ""

# ------------------------------------------------------------------------------
# 2. Operator Deployment & Pod Diagnostics
# ------------------------------------------------------------------------------
echo -e "${BOLD}[2/5] Inspecting Rook-Ceph Operator Pod Status...${RESET}"
OPERATOR_DEPLOY="$(kubectl get deployment rook-ceph-operator -n "${NAMESPACE}" -o jsonpath='{.metadata.name}' 2>/dev/null || true)"

if [ -z "${OPERATOR_DEPLOY}" ]; then
  echo -e "  ${RED}✖ Deployment 'rook-ceph-operator' not found in namespace '${NAMESPACE}'.${RESET}"
else
  # Retrieve operator pods
  OPERATOR_PODS="$(kubectl get pods -n "${NAMESPACE}" -l app=rook-ceph-operator --no-headers 2>/dev/null || true)"
  if [ -z "${OPERATOR_PODS}" ]; then
    echo -e "  ${RED}✖ No pods found for deployment 'rook-ceph-operator'.${RESET}"
  else
    echo "${OPERATOR_PODS}" | while read -r pod_name pod_ready pod_status pod_restarts pod_age; do
      if [ "${pod_status}" = "Running" ] && [[ "${pod_ready}" == *"1/1"* ]]; then
        echo -e "  ${GREEN}✔ Pod ${pod_name}: ${pod_status} (${pod_ready}, restarts: ${pod_restarts}, age: ${pod_age})${RESET}"
      else
        echo -e "  ${RED}✖ Pod ${pod_name}: ${pod_status} (${pod_ready}, restarts: ${pod_restarts}, age: ${pod_age})${RESET}"
        
        # Extract termination reason if crashed
        TERM_REASON="$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)"
        TERM_EXIT="$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}' 2>/dev/null || true)"
        if [ -n "${TERM_REASON}" ]; then
          echo -e "    ${YELLOW}Last Termination: ${TERM_REASON} (exit code: ${TERM_EXIT})${RESET}"
        fi

        # Extract waiting reason (e.g. CrashLoopBackOff, ImagePullBackOff, ErrImagePull)
        WAIT_REASON="$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
        WAIT_MSG="$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.containerStatuses[0].state.waiting.message}' 2>/dev/null || true)"
        if [ -n "${WAIT_REASON}" ]; then
          echo -e "    ${RED}Waiting State: ${WAIT_REASON} - ${WAIT_MSG}${RESET}"
        fi

        # Print recent pod events
        echo -e "    ${BOLD}Recent Pod Events:${RESET}"
        kubectl get events -n "${NAMESPACE}" --field-selector "involvedObject.name=${pod_name}" --sort-by='.lastTimestamp' \
          -o custom-columns="TYPE:.type,REASON:.reason,MESSAGE:.message" | tail -n 5 | sed 's/^/      /' || true

        # Print last logs from current or previous crash
        echo -e "    ${BOLD}Operator Crash/Error Logs (tail 20):${RESET}"
        kubectl logs "${pod_name}" -n "${NAMESPACE}" --tail=20 2>/dev/null | sed 's/^/      /' || \
          kubectl logs "${pod_name}" -n "${NAMESPACE}" --previous --tail=20 2>/dev/null | sed 's/^/      /' || true

        echo ""
        echo -e "    ${YELLOW}Troubleshooting Suggestions:${RESET}"
        if [[ "${WAIT_REASON}" == *"ImagePull"* ]]; then
          echo "    - Check network/DNS and registry reachability for rook/ceph image."
        elif [[ "${pod_status}" == *"Pending"* ]]; then
          echo "    - Check node taints or insufficient resources: kubectl describe nodes"
        else
          echo "    - Check if kernel module 'rbd' is loaded on nodes: lsmod | grep rbd"
          echo "    - Restart operator: kubectl rollout restart deployment/rook-ceph-operator -n ${NAMESPACE}"
        fi
      fi
    done
  fi
fi
echo ""

# ------------------------------------------------------------------------------
# 3. CephCluster Custom Resource Health
# ------------------------------------------------------------------------------
echo -e "${BOLD}[3/5] Inspecting CephCluster Resource '${CLUSTER_NAME}'...${RESET}"
if ! kubectl get crd cephclusters.ceph.rook.io >/dev/null 2>&1; then
  echo -e "  ${YELLOW}⚠ CephCluster CRD (cephclusters.ceph.rook.io) is not registered yet.${RESET}"
else
  CLUSTER_PHASE="$(kubectl get cephcluster "${CLUSTER_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [ -z "${CLUSTER_PHASE}" ]; then
    echo -e "  ${YELLOW}ℹ CephCluster resource '${CLUSTER_NAME}' has not been applied yet.${RESET}"
    echo "  (Rook operator may still be initializing or raw storage devices are unconfigured)."
  else
    CLUSTER_MSG="$(kubectl get cephcluster "${CLUSTER_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.message}' 2>/dev/null || true)"
    CLUSTER_HEALTH="$(kubectl get cephcluster "${CLUSTER_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.ceph.health}' 2>/dev/null || true)"
    
    if [ "${CLUSTER_PHASE}" = "Ready" ]; then
      echo -e "  ${GREEN}✔ Phase:  ${CLUSTER_PHASE}${RESET}"
    elif [ "${CLUSTER_PHASE}" = "Progressing" ]; then
      echo -e "  ${YELLOW}⏳ Phase:  ${CLUSTER_PHASE}${RESET}"
    else
      echo -e "  ${RED}✖ Phase:  ${CLUSTER_PHASE}${RESET}"
    fi

    [ -n "${CLUSTER_HEALTH}" ] && echo -e "  Health: ${BOLD}${CLUSTER_HEALTH}${RESET}"
    [ -n "${CLUSTER_MSG}" ] && echo -e "  Status: ${CLUSTER_MSG}"

    if [ "${VERBOSE}" = "true" ]; then
      echo -e "  Conditions:"
      kubectl get cephcluster "${CLUSTER_NAME}" -n "${NAMESPACE}" -o jsonpath='{range .status.conditions[*]}{"  - "}{.type}{": "}{.status}{" ("}{.message}{")\n"}{end}' 2>/dev/null || true
    fi
  fi
fi
echo ""

# ------------------------------------------------------------------------------
# 4. Ceph Daemon Pods Breakdown
# ------------------------------------------------------------------------------
echo -e "${BOLD}[4/5] Ceph Daemon Pods Overview...${RESET}"
ALL_CEPH_PODS="$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null || true)"

if [ -z "${ALL_CEPH_PODS}" ]; then
  echo "  No pods currently running in namespace '${NAMESPACE}'."
else
  printf "  %-35s %-10s %-12s %-10s %s\n" "POD" "READY" "STATUS" "RESTARTS" "NODE"
  echo "  --------------------------------------------------------------------------------"
  kubectl get pods -n "${NAMESPACE}" -o custom-columns="NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,NODE:.spec.nodeName" --no-headers | while read -r line; do
    echo "  ${line}"
  done
fi
echo ""

# ------------------------------------------------------------------------------
# 5. Native Ceph Status (via Toolbox or Running Daemons)
# ------------------------------------------------------------------------------
echo -e "${BOLD}[5/5] Native 'ceph status' Execution...${RESET}"

# Check if rook-ceph-tools deployment is requested or already running
TOOLBOX_RUNNING=false
if kubectl get deployment rook-ceph-tools -n "${NAMESPACE}" >/dev/null 2>&1; then
  TOOLBOX_POD="$(kubectl get pods -n "${NAMESPACE}" -l app=rook-ceph-tools -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -n "${TOOLBOX_POD}" ]; then
    TOOLBOX_STATUS="$(kubectl get pod "${TOOLBOX_POD}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [ "${TOOLBOX_STATUS}" = "Ready" ] || [ "${TOOLBOX_STATUS}" = "Running" ]; then
      TOOLBOX_RUNNING=true
    fi
  fi
fi

# Deploy toolbox if explicitly requested and not yet present
if [ "${ENSURE_TOOLBOX}" = "true" ] && [ "${TOOLBOX_RUNNING}" = "false" ]; then
  echo "  Deploying Rook-Ceph toolbox deployment..."
  kubectl apply -f https://raw.githubusercontent.com/rook/rook/v1.15.5/deploy/examples/toolbox.yaml -n "${NAMESPACE}"
  echo "  Waiting up to 60s for toolbox pod to become ready..."
  if kubectl wait --for=condition=Ready pod -l app=rook-ceph-tools -n "${NAMESPACE}" --timeout=60s >/dev/null 2>&1; then
    TOOLBOX_RUNNING=true
  fi
fi

# Attempt native command execution
if [ "${TOOLBOX_RUNNING}" = "true" ]; then
  echo -e "  ${GREEN}✔ Executing 'ceph status' via rook-ceph-tools:${RESET}"
  echo "--------------------------------------------------------------------------------"
  kubectl exec -n "${NAMESPACE}" deploy/rook-ceph-tools -- ceph status || true
  echo "--------------------------------------------------------------------------------"
  echo -e "  ${GREEN}✔ Executing 'ceph osd status':${RESET}"
  kubectl exec -n "${NAMESPACE}" deploy/rook-ceph-tools -- ceph osd status || true
else
  # Try querying via Mon/Mgr pod if toolbox isn't present
  MON_POD="$(kubectl get pods -n "${NAMESPACE}" -l app=rook-ceph-mon -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -n "${MON_POD}" ]; then
    echo -e "  ${GREEN}✔ Executing 'ceph status' via Mon pod '${MON_POD}':${RESET}"
    echo "--------------------------------------------------------------------------------"
    kubectl exec -n "${NAMESPACE}" "${MON_POD}" -- ceph status || true
    echo "--------------------------------------------------------------------------------"
  else
    echo -e "  ${YELLOW}ℹ Native 'ceph status' unavailable: No Mon daemons or Toolbox pod running.${RESET}"
    echo "    Tip: To deploy the interactive Ceph toolbox once Mons are running, invoke:"
    echo "         $(basename "$0") --toolbox"
  fi
fi

# ------------------------------------------------------------------------------
# StorageClass Status
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}StorageClass Status:${RESET}"
if kubectl get storageclass rook-ceph-block >/dev/null 2>&1; then
  echo -e "  ${GREEN}✔ StorageClass 'rook-ceph-block' is present:${RESET}"
  kubectl get storageclass rook-ceph-block -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode,ALLOW_EXPANSION:.allowVolumeExpansion" | sed 's/^/    /'
else
  echo -e "  ${YELLOW}⚠ StorageClass 'rook-ceph-block' is not yet created.${RESET}"
fi

echo -e "\n${BOLD}${BLUE}====================================================================${RESET}"

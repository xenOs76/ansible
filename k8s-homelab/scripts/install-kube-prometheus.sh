#!/usr/bin/env bash
# ==============================================================================
# Script: install-kube-prometheus.sh
# Purpose: Deploy or upgrade a lightweight, minimal Prometheus Operator setup
#          via Helm using the official kube-prometheus-stack chart.
#          Installs Prometheus ONLY (no Grafana, no Alertmanager, no exporters).
#
# Context:
#   Can be executed directly on the control plane node or from the host machine
#   when pointing to a valid kubeconfig. Requires 'helm' and 'kubectl'.
#
# Usage:
#   ./install-kube-prometheus.sh [CHART_VERSION]
#
# Arguments:
#   $1 - CHART_VERSION  (Optional) Pinned Helm chart version to install.
#                       Default: Latest available from prometheus-community repo.
#
# Environment Variables:
#   KUBECONFIG          - Path to kubeconfig. Automatically defaults to
#                         /etc/kubernetes/admin.conf if run inside control plane.
#   NAMESPACE           - Target namespace for Prometheus (Default: monitoring).
#   PROMETHEUS_REPLICAS - Replicas for Prometheus server (Default: 1).
#   RETENTION           - Metric retention period (Default: 12h).
#
# Minimal Footprint Configuration:
#   - alertmanager.enabled=false   : Alertmanager disabled
#   - grafana.enabled=false        : Grafana dashboard UI disabled
#   - nodeExporter.enabled=false   : Node Exporter daemonset disabled
#   - kubeStateMetrics.enabled=false : Kube State Metrics deployment disabled
#   - prometheus.prometheusSpec.replicas=1 : Single replica for lab sizing
#
# Manual Verification:
#   kubectl get pods -n monitoring
#   kubectl get prometheus -n monitoring
#   kubectl get servicemonitors -A
#   kubectl port-forward -n monitoring svc/kube-prometheus-kube-prome-prometheus 9090:9090
#   curl -s http://localhost:9090/-/ready
# ==============================================================================
set -euo pipefail

echo "=== Installing Minimal Prometheus Operator via Helm ==="

# Validate prerequisite CLI tools
if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is not installed or not in PATH." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed or not in PATH." >&2
  exit 1
fi

# Detect KUBECONFIG if running as non-root without ~/.kube/config
if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/kubernetes/admin.conf ] && [ ! -f "${HOME}/.kube/config" ]; then
  export KUBECONFIG=/etc/kubernetes/admin.conf
fi

CHART_VERSION="${1:-}"
TARGET_NAMESPACE="${NAMESPACE:-monitoring}"
REPLICAS="${PROMETHEUS_REPLICAS:-1}"
RETENTION_PERIOD="${RETENTION:-12h}"

EXTRA_ARGS=()
if [ -n "${CHART_VERSION}" ]; then
  EXTRA_ARGS+=(--version "${CHART_VERSION}")
fi

echo "Adding and updating prometheus-community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community

echo "Installing/upgrading kube-prometheus release in namespace '${TARGET_NAMESPACE}'..."
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${TARGET_NAMESPACE}" \
  --create-namespace \
  --set alertmanager.enabled=false \
  --set grafana.enabled=false \
  --set nodeExporter.enabled=false \
  --set kubeStateMetrics.enabled=false \
  --set prometheus.prometheusSpec.replicas="${REPLICAS}" \
  --set prometheus.prometheusSpec.retention="${RETENTION_PERIOD}" \
  --set prometheus.prometheusSpec.resources.requests.cpu="100m" \
  --set prometheus.prometheusSpec.resources.requests.memory="256Mi" \
  --set prometheus.prometheusSpec.resources.limits.cpu="500m" \
  --set prometheus.prometheusSpec.resources.limits.memory="512Mi" \
  "${EXTRA_ARGS[@]}"

echo "Waiting for Prometheus Operator deployment rollout..."
kubectl rollout status deployment kube-prometheus-kube-prome-operator \
  -n "${TARGET_NAMESPACE}" \
  --timeout=180s

echo "Waiting for Prometheus StatefulSet rollout..."
kubectl rollout status statefulset prometheus-kube-prometheus-kube-prome-prometheus \
  -n "${TARGET_NAMESPACE}" \
  --timeout=180s || true

echo "=== Prometheus Operator installed successfully ==="
echo ""
echo "Active workloads in namespace '${TARGET_NAMESPACE}':"
kubectl get pods,svc -n "${TARGET_NAMESPACE}"
echo ""
echo "To access Prometheus Web UI locally:"
echo "  kubectl port-forward -n ${TARGET_NAMESPACE} svc/kube-prometheus-kube-prome-prometheus 9090:9090"
echo "  Then visit: http://localhost:9090"

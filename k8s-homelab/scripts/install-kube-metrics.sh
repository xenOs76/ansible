#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Kubernetes Metrics Server via Helm ==="

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

METRICS_SERVER_VERSION="${1:-}"
EXTRA_ARGS=()
if [ -n "${METRICS_SERVER_VERSION}" ]; then
  EXTRA_ARGS+=(--version "${METRICS_SERVER_VERSION}")
fi

echo "Adding and updating metrics-server Helm repository..."
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
helm repo update metrics-server

echo "Installing/upgrading metrics-server chart..."
# Note: --kubelet-insecure-tls is required in kubeadm homelabs due to self-signed kubelet certs
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args="{--kubelet-insecure-tls}" \
  "${EXTRA_ARGS[@]}"

echo "Waiting for metrics-server deployment rollout..."
kubectl rollout status deployment metrics-server -n kube-system --timeout=120s || true

echo "=== Metrics server installed successfully ==="

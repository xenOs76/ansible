#!/usr/bin/env bash
# ==============================================================================
# Script: cni-enable-ingress-gateway.sh
# Purpose: Enable or upgrade Cilium's native Ingress Controller and Gateway API
#          controller in-place on an already-running Kubernetes cluster.
#
# Context:
#   Can be executed on 'kube-control-plane' or from any workstation with
#   valid KUBECONFIG, 'cilium', and 'kubectl' installed.
#   Does not reset the cluster, drain nodes, or drop pod-to-pod networking.
#
# Usage:
#   /home/vagrant/cni-enable-ingress-gateway.sh
#   # Or directly from the repo:
#   ./scripts/cni-enable-ingress-gateway.sh
#
# Ports Configured:
#   - Ingress: NodePort 31080 (HTTP) & 31443 (HTTPS)
#   - Gateway API: NodePort 30080 (HTTP) & 30443 (HTTPS)
# ==============================================================================
set -euo pipefail

echo "=== [cni-enable-ingress-gateway.sh] In-Place Cilium Ingress & Gateway API Enablement ==="

# Validate prerequisites
if ! command -v cilium >/dev/null 2>&1; then
  echo "Error: cilium CLI is not installed or not in PATH." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl CLI is not installed or not in PATH." >&2
  exit 1
fi

if [ -z "${KUBECONFIG:-}" ] && [ -f /etc/kubernetes/admin.conf ] && [ ! -f "${HOME}/.kube/config" ]; then
  export KUBECONFIG=/etc/kubernetes/admin.conf
fi

GATEWAY_API_CRD_VERSION="${GATEWAY_API_CRD_VERSION:-v1.2.1}"
INGRESS_HTTP_PORT="${INGRESS_HTTP_PORT:-31080}"
INGRESS_HTTPS_PORT="${INGRESS_HTTPS_PORT:-31443}"

# 1. Apply Gateway API standard and experimental CRDs
echo "==> [1/4] Ensuring Gateway API CRDs (${GATEWAY_API_CRD_VERSION}) are applied..."
kubectl apply --server-side --force-conflicts -f \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_CRD_VERSION}/experimental-install.yaml"

# 2. Upgrade Cilium deployment in-place
echo "==> [2/4] Detecting Kubernetes API server endpoint for kubeProxyReplacement..."
API_SERVER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)
API_SERVER_IP=$(echo "${API_SERVER_URL}" | sed -E -n 's|https?://([^:/]+).*|\1|p')
API_SERVER_PORT=$(echo "${API_SERVER_URL}" | sed -E -n 's|https?://[^:]+:([0-9]+).*|\1|p')
API_SERVER_PORT="${API_SERVER_PORT:-6443}"

if [ -z "${API_SERVER_IP}" ] || [ "${API_SERVER_IP}" = "127.0.0.1" ] || [ "${API_SERVER_IP}" = "localhost" ]; then
  API_SERVER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
fi
if [ -z "${API_SERVER_IP}" ]; then
  API_SERVER_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
fi
echo "    API Server: https://${API_SERVER_IP}:${API_SERVER_PORT}"

echo "    Upgrading Cilium with Ingress and Gateway API enabled..."
cilium upgrade --reuse-values \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${API_SERVER_IP}" \
  --set k8sServicePort="${API_SERVER_PORT}" \
  --set ingressController.enabled=true \
  --set ingressController.default=true \
  --set ingressController.loadbalancerMode=shared \
  --set ingressController.service.type=NodePort \
  --set ingressController.service.insecureNodePort="${INGRESS_HTTP_PORT}" \
  --set ingressController.service.secureNodePort="${INGRESS_HTTPS_PORT}" \
  --set gatewayAPI.enabled=true

# 3. Wait for Cilium deployment rollout
echo "==> [3/4] Waiting for Cilium deployment and operator to stabilize..."
cilium status --wait

# 4. Deploy Cilium NodePort GatewayClass and GatewayClassConfig
echo "==> [4/4] Configuring Cilium NodePort GatewayClass (cilium-nodeport)..."
cat << 'EOF' | kubectl apply -f -
---
apiVersion: cilium.io/v2alpha1
kind: CiliumGatewayClassConfig
metadata:
  name: cilium-nodeport
  namespace: kube-system
  labels:
    app.kubernetes.io/part-of: cilium
spec:
  service:
    type: NodePort
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: cilium-nodeport
  labels:
    app.kubernetes.io/part-of: cilium
spec:
  controllerName: io.cilium/gateway-controller
  description: "Cilium GatewayClass configured for NodePort service exposure"
  parametersRef:
    group: cilium.io
    kind: CiliumGatewayClassConfig
    name: cilium-nodeport
    namespace: kube-system
EOF

echo "=== [cni-enable-ingress-gateway.sh] Cilium dual controller configuration active ==="
echo "Active IngressClasses:"
kubectl get ingressclasses
echo "Active GatewayClasses:"
kubectl get gatewayclasses

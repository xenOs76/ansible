#!/usr/bin/env bash
# ==============================================================================
# Script: cni-install-cilium.sh
# Purpose: Download, verify, and install the Cilium CLI, then deploy the
#          Cilium eBPF-based Container Network Interface (CNI) to the cluster
#          with native dual Ingress (NodePort 31080/31443) and Gateway API
#          support.
#
# Context:
#   Executed on the 'kube-control-plane' node after 'control-plane.sh' (kubeadm init)
#   has completed. Typically run as 'vagrant' user with sudo permissions.
#
# Usage:
#   /home/vagrant/cni-install-cilium.sh
#   # Or directly from the shared mount:
#   /vagrant/scripts/cni-install-cilium.sh
#
# Key Operations:
#   1. Queries upstream GitHub for latest stable Cilium CLI version tag.
#   2. Detects architecture (amd64 / arm64).
#   3. Downloads CLI archive alongside official sha256sum and verifies integrity.
#   4. Installs 'cilium' binary into /usr/local/bin.
#   5. Applies Gateway API experimental CRDs (v1.2.1) including TLSRoute.
#   6. Runs 'cilium install' with Ingress (31080/31443) and Gateway API enabled
#      (standard kube-proxy service routing).
#   7. Configures 'cilium-nodeport' GatewayClass and CiliumGatewayClassConfig.
#
# Manual Verification:
#   cilium status --wait
#   kubectl get ingressclasses
#   kubectl get gatewayclasses
#   kubectl get nodes -o wide   # (Nodes will transition from NotReady to Ready)
# ==============================================================================
set -euo pipefail

echo "=== [cni-install-cilium.sh] Installing Cilium CNI (Dual Ingress & Gateway API) ==="

GATEWAY_API_CRD_VERSION="${GATEWAY_API_CRD_VERSION:-v1.2.1}"
INGRESS_HTTP_PORT="${INGRESS_HTTP_PORT:-31080}"
INGRESS_HTTPS_PORT="${INGRESS_HTTPS_PORT:-31443}"

# 1. Determine latest stable CLI version and system architecture
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH="amd64"
if [ "$(uname -m)" = "aarch64" ]; then
  CLI_ARCH="arm64"
fi

echo "    Cilium CLI Version: ${CILIUM_CLI_VERSION} (${CLI_ARCH})"

# 2. Download and verify Cilium CLI binary
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

cd "${TMP_DIR}"
echo "    Downloading Cilium CLI and verifying SHA256 checksum..."
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"

echo "    Installing cilium binary to /usr/local/bin..."
sudo tar -C /usr/local/bin -xzvf "cilium-linux-${CLI_ARCH}.tar.gz"

# 3. Ensure Gateway API standard and experimental CRDs are present
echo "    Applying Gateway API CRDs (${GATEWAY_API_CRD_VERSION})..."
if command -v kubectl >/dev/null 2>&1; then
  kubectl apply --server-side --force-conflicts -f \
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_CRD_VERSION}/experimental-install.yaml" || true
fi

# 4. Deploy Cilium into the Kubernetes cluster
echo "    Deploying Cilium CNI into cluster with Ingress & Gateway API..."
cilium install \
  --set ingressController.enabled=true \
  --set ingressController.default=true \
  --set ingressController.loadbalancerMode=shared \
  --set ingressController.service.type=NodePort \
  --set ingressController.service.insecureNodePort="${INGRESS_HTTP_PORT}" \
  --set ingressController.service.secureNodePort="${INGRESS_HTTPS_PORT}" \
  --set gatewayAPI.enabled=true

echo "    Waiting for Cilium to become ready..."
cilium status --wait

# 5. Configure Cilium NodePort GatewayClass
echo "    Configuring Cilium NodePort GatewayClass..."
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

echo "=== [cni-install-cilium.sh] Cilium installation complete ==="
echo "    IngressClass:  $(kubectl get ingressclasses -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo 'none')"
echo "    GatewayClass:  $(kubectl get gatewayclasses -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo 'none')"

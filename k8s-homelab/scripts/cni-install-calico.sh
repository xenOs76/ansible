#!/usr/bin/env bash
# ==============================================================================
# Script: cni-install-calico.sh
# Purpose: Deploy Project Calico CNI via the Tigera Operator with a customizable
#          Pod network CIDR block.
#
# Context:
#   Executed on the 'kube-control-plane' node after 'control-plane.sh' has completed.
#   Used as an alternative CNI option to Cilium for CKA training drills.
#
# Usage:
#   /home/vagrant/cni-install-calico.sh [POD_CIDR]
#   # Or directly from the shared mount:
#   /vagrant/scripts/cni-install-calico.sh [POD_CIDR]
#
# Arguments:
#   $1 - POD_CIDR  (Optional) Pod network CIDR block. Must match the
#                  --pod-network-cidr passed to 'kubeadm init'.
#                  Default: 10.2.0.0/16
#
# Key Operations:
#   1. Applies Tigera Operator custom resource definitions and controllers.
#   2. Fetches Calico Installation custom resource manifest.
#   3. Rewrites the default IP pool CIDR to match POD_CIDR.
#   4. Applies custom resources to trigger Calico node daemonset rollout.
#
# Manual Verification:
#   kubectl get pods -n tigera-operator
#   kubectl get pods -n calico-system -w
#   kubectl get nodes -o wide   # (Nodes will transition to Ready)
#
# Troubleshooting:
#   - Check operator logs:
#       kubectl logs -n tigera-operator deployment/tigera-operator
#   - Check Calico node daemonset:
#       kubectl describe daemonset calico-node -n calico-system
# ==============================================================================
set -euo pipefail

POD_CIDR="${1:-10.2.0.0/16}"
CALICO_VERSION="v3.29.1"

echo "=== [cni-install-calico.sh] Installing Calico CNI (${CALICO_VERSION}) ==="
echo "    Configured Pod CIDR: ${POD_CIDR}"

# 1. Install Tigera Operator
echo "    Applying Tigera Operator manifests..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

# 2. Download, configure, and apply Calico custom resources
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CUSTOM_RES="${TMP_DIR}/calico-custom-resources.yaml"
echo "    Configuring Calico custom resources with CIDR: ${POD_CIDR}..."
wget -q "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml" -O "${CUSTOM_RES}"
sed -i "s~cidr: 192\.168\.0\.0/16~cidr: ${POD_CIDR}~g" "${CUSTOM_RES}"

echo "    Applying custom resources to start Calico..."
kubectl create -f "${CUSTOM_RES}"

echo "=== [cni-install-calico.sh] Calico CNI deployed successfully ==="
echo "    Monitor rollout via: kubectl get pods -n calico-system -w"

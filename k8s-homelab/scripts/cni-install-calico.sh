#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Calico CNI ==="

POD_CIDR="${1:-10.2.0.0/16}"

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
wget -q https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml -O calico-custom-resources.yaml
sed -i "s~cidr: 192\.168\.0\.0/16~cidr: ${POD_CIDR}~g" calico-custom-resources.yaml
kubectl create -f calico-custom-resources.yaml
# rm -f calico-custom-resources.yaml

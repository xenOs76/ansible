#!/usr/bin/env bash
# ==============================================================================
# Script: install-rook-ceph.sh
# Purpose: Deploy or upgrade the Rook-Ceph operator and configure dynamic block
#          storage (RBD) backed by the control-plane storage volume.
#
# Context:
#   Can be executed directly on the control plane node or from the host machine
#   when pointing to a valid kubeconfig. Requires 'helm' and 'kubectl'.
#
# Usage:
#   ./install-rook-ceph.sh [ROOK_VERSION] [STORAGE_DEVICE] [STORAGE_NODE]
#
# Arguments:
#   $1 - ROOK_VERSION     (Optional) Helm chart version. Default: v1.15.5
#   $2 - STORAGE_DEVICE   (Optional) Target block device name. Default: vdb
#   $3 - STORAGE_NODE     (Optional) Node name holding the disk. Default: kube-control-plane
#
# Environment Variables:
#   KUBECONFIG - Path to kubeconfig. Defaults to /etc/kubernetes/admin.conf
#                if running inside the control plane VM.
#
# Manual Verification:
#   kubectl get pods -n rook-ceph
#   kubectl get cephcluster -n rook-ceph
#   kubectl get storageclass rook-ceph-block
# ==============================================================================
set -euo pipefail

echo "=== Installing Rook-Ceph Block Storage Operator ==="

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

ROOK_VERSION="${1:-v1.15.5}"
STORAGE_DEVICE="${2:-vdb}"
STORAGE_NODE="${3:-kube-control-plane}"
NAMESPACE="rook-ceph"
CLUSTER_NAME="rook-ceph"
STORAGE_CLASS="rook-ceph-block"

echo "Adding and updating Rook Helm repository..."
helm repo add rook-release https://charts.rook.io/release >/dev/null 2>&1 || true
helm repo update rook-release

echo "Installing/upgrading Rook-Ceph operator (version: ${ROOK_VERSION})..."
helm upgrade --install "${CLUSTER_NAME}-operator" rook-release/rook-ceph \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --version "${ROOK_VERSION}" \
  --set csi.enableRbdDriver=true \
  --set csi.enableCephfsDriver=false

echo "Waiting for Rook-Ceph operator deployment rollout..."
kubectl rollout status deployment/rook-ceph-operator -n "${NAMESPACE}" --timeout=180s

echo "Applying CephCluster resource for storage node '${STORAGE_NODE}' (device: ${STORAGE_DEVICE})..."
cat <<EOF | kubectl apply -f -
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${NAMESPACE}
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v19.2.1
    allowUnsupported: false
  dataDirHostPath: /var/lib/rook
  skipUpgradeChecks: false
  continueUpgradeAfterChecksEvenIfNotHealthy: false
  waitTimeoutForHealthyOSDInMinutes: 10
  mon:
    count: 1
    allowMultiplePerNode: false
  mgr:
    count: 1
    allowMultiplePerNode: false
    modules:
      - name: pg_autoscaler
        enabled: true
  dashboard:
    enabled: true
    ssl: false
  crashCollector:
    disable: false
  cleanupPolicy:
    wipeStorage: false
  placement:
    all:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: kubernetes.io/hostname
                  operator: In
                  values:
                    - "${STORAGE_NODE}"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "${STORAGE_NODE}"
        devices:
          - name: "${STORAGE_DEVICE}"
EOF

echo "Applying CephBlockPool and StorageClass '${STORAGE_CLASS}'..."
cat <<EOF | kubectl apply -f -
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: ${NAMESPACE}
spec:
  failureDomain: osd
  replicated:
    size: 1
    requireSafeReplicaSize: false
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS}
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ${NAMESPACE}.rbd.csi.ceph.io
parameters:
  clusterID: ${NAMESPACE}
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: ${NAMESPACE}
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: ${NAMESPACE}
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: ${NAMESPACE}
  csi.storage.k8s.io/fstype: ext4
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

echo "=== Rook-Ceph operator and storage class configuration completed ==="
echo "Verify cluster status with: kubectl get cephcluster -n ${NAMESPACE}"
echo "Verify storage class with:  kubectl get storageclass ${STORAGE_CLASS}"

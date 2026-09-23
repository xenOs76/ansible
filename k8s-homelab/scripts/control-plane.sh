#!/usr/bin/env bash

POD_CIDR=$1
API_ADV_ADDRESS=$2

kubeadm init --pod-network-cidr "$POD_CIDR" --apiserver-advertise-address "$API_ADV_ADDRESS" | tee /vagrant/kubeadm-init.out

systemctl daemon-reload
echo "KUBELET_EXTRA_ARGS=--node-ip=$API_ADV_ADDRESS --cgroup-driver=systemd" > /etc/default/kubelet
systemctl restart kubelet

mkdir -p /home/vagrant/.kube
cp -f /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config

# Note: CNI plugin can now be chosen and installed via:
#   /home/vagrant/cni-install-cilium.sh
# or
#   /home/vagrant/cni-install-calico.sh

cp -f /etc/kubernetes/admin.conf /vagrant/admin.conf

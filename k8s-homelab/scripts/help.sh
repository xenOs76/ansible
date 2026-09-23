#!/usr/bin/env bash
# Quick reference for managing the CKA training Vagrant Libvirt cluster
set -euo pipefail

# ANSI color codes
BOLD=$(printf '\033[1m')
CYAN=$(printf '\033[0;36m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m')
RESET=$(printf '\033[0m')

cat <<EOF
${BOLD}========================================================================${RESET}
${BOLD}${CYAN}   CKA Training Lab - Cluster Operations & Vagrant Cheatsheet           ${RESET}
${BOLD}========================================================================${RESET}

${BOLD}${YELLOW}[1] Environment & Shell${RESET}
  Enter nix-shell environment:
    ${GREEN}./scripts/shell.sh${RESET}
    ${GREEN}nix-shell${RESET}

${BOLD}${YELLOW}[2] Cluster Lifecycle${RESET}
  Start all VMs:
    ${GREEN}make preprod-up${RESET}  or  ${GREEN}./scripts/shell.sh --run "vagrant up"${RESET}
  Check VM status:
    ${GREEN}make preprod-status${RESET}  or  ${GREEN}./scripts/shell.sh --run "vagrant status"${RESET}
  Stop all VMs (graceful halt):
    ${GREEN}./scripts/shell.sh --run "vagrant halt"${RESET}
  Destroy and clean up all VMs:
    ${GREEN}make preprod-destroy${RESET}  or  ${GREEN}./scripts/shell.sh --run "vagrant destroy -f"${RESET}

${BOLD}${YELLOW}[3] Provisioning Existing VMs (No Re-creation)${RESET}
  Re-run provisioners on all running VMs:
    ${GREEN}./scripts/shell.sh --run "vagrant provision"${RESET}
  Re-run provisioners on a specific VM:
    ${GREEN}./scripts/shell.sh --run "vagrant provision kube-control-plane"${RESET}
    ${GREEN}./scripts/shell.sh --run "vagrant provision kube-worker-1"${RESET}
  Start stopped VMs AND execute provisioners:
    ${GREEN}./scripts/shell.sh --run "vagrant up --provision"${RESET}

${BOLD}${YELLOW}[4] SSH Access${RESET}
  Connect to control plane:
    ${GREEN}./scripts/shell.sh --run "vagrant ssh kube-control-plane"${RESET}
  Connect to worker node:
    ${GREEN}./scripts/shell.sh --run "vagrant ssh kube-worker-1"${RESET}

${BOLD}${YELLOW}[5] Kubernetes Setup Steps (Inside VMs)${RESET}
  1. On ${BOLD}kube-control-plane${RESET}:
     Initialize control plane:
       ${GREEN}sudo /vagrant/scripts/control-plane.sh 172.18.0.0/16 192.168.56.10${RESET}
     Install Cilium CNI (Option A):
       ${GREEN}./cni-install-cilium.sh${RESET}
     Install Calico CNI (Option B):
       ${GREEN}./cni-install-calico.sh${RESET}

  2. On ${BOLD}kube-worker-1${RESET}:
     Join cluster:
       ${GREEN}sudo /vagrant/scripts/worker.sh 1${RESET}

${BOLD}========================================================================${RESET}
EOF

.PHONY: all lint syntax inventory deps check-deps preprod-up preprod-destroy preprod-recreate preprod-status preprod-provision preprod-sync-kubeconfig prod-sync-kubeconfig preprod-deploy preprod-caddy preprod-cni preprod-ceph prod-ceph preprod-ceph-status preprod-iscsi preprod-fc preprod-fc-status preprod-nfs prod-nfs preprod-ha-nfs preprod-nfs-csi prod-nfs-csi preprod-upgrade preprod-reset cka-generate preprod-cka preprod-cka-lab preprod-cka-chaos preprod-cks-lab preprod-ha-up preprod-ha-destroy preprod-ha-recreate preprod-ha-deploy preprod-ha-sync-kubeconfig preprod-ha-cka preprod-ha-cka-lab preprod-switch-ha preprod-switch-standard preprod-stage-bare preprod-stage-prebootstrap preprod-stage-cp-only preprod-stage-ready cka-snapshot-save cka-snapshot-restore cka-lab-clone help

all: help

help:
	@echo "k8s-homelab Makefile"
	@echo "--------------------"
	@echo "make deps              - Install Ansible collection dependencies from requirements.yml"
	@echo "make check-deps        - Verify installed Ansible collection dependencies"
	@echo "make lint              - Run yamllint, syntax check, inventory parse, and ansible-lint"
	@echo "make syntax            - Run ansible-playbook --syntax-check on all playbooks"
	@echo "make inventory         - Show inventory host graph"
	@echo "make cka-generate      - Generate CKA lab docs and manifests locally in repo (offline)"
	@echo "make preprod-up        - Boot up Vagrant libvirt preprod VMs and provision NFS server"
	@echo "make preprod-destroy   - Destroy Vagrant libvirt preprod VMs"
	@echo "make preprod-recreate  - Clean rebuild: destroy and boot fresh Vagrant VMs"
	@echo "make preprod-status    - Check status of Vagrant VMs"
	@echo "make preprod-provision - Run Vagrant provisioners on running preprod VMs"
	@echo "make preprod-sync-kubeconfig - Sync preprod credentials (context: k8s-homelab-preprod)"
	@echo "make prod-sync-kubeconfig    - Sync prod credentials (context: k8s-homelab)"
	@echo "make preprod-deploy    - Run full Ansible playbook deployment on preprod"
	@echo "make preprod-caddy     - Deploy/configure Caddy ingress reverse proxy on preprod"
	@echo "make preprod-cni       - Install/verify Cilium CNI on preprod"
	@echo "make preprod-ceph      - Deploy/configure Rook-Ceph block storage on preprod"
	@echo "make prod-ceph         - Deploy/configure Rook-Ceph block storage on prod"
	@echo "make preprod-ceph-status - Inspect Rook-Ceph operator, cluster, and Ceph status"
	@echo "make preprod-iscsi     - Deploy/configure standalone iSCSI storage target on preprod"
	@echo "make preprod-fc        - Deploy/configure Fibre Channel SAN storage emulator on preprod"
	@echo "make preprod-fc-status - Inspect Fibre Channel SAN status, WWPNs, and LUN mappings"
	@echo "make preprod-nfs       - Deploy/configure NFS storage server on preprod"
	@echo "make prod-nfs          - Deploy/configure NFS storage server on prod"
	@echo "make preprod-ha-nfs    - Deploy/configure NFS storage server on preprod HA"
	@echo "make preprod-nfs-csi   - Deploy/configure NFS CSI dynamic storage driver on preprod"
	@echo "make prod-nfs-csi      - Deploy/configure NFS CSI dynamic storage driver on prod"
	@echo "make preprod-upgrade   - Run rolling upgrade on preprod"
	@echo "make preprod-reset     - Teardown/reset cluster on preprod"
	@echo "make preprod-cka-lab   - Deploy CKA training lab scenarios on preprod"
	@echo "make preprod-cka-chaos - Deploy CKA lab including Litmus dynamic chaos drills"
	@echo "make preprod-cks-lab   - Deploy CKS training lab scenarios on preprod"
	@echo "make preprod-stage-bare - Provision Stage 0: OS tuning & prerequisites only (bare nodes)"
	@echo "make preprod-stage-prebootstrap - Provision Stage 1: containerd & k8s packages (uninitialized)"
	@echo "make preprod-stage-cp-only - Provision Stage 2: Control plane initialized, workers unjoined"
	@echo "make preprod-stage-ready - Provision Stage 3: Full multi-node cluster ready"
	@echo "make cka-snapshot-save - Save snapshot of current VM state (name: cka-baseline)"
	@echo "make cka-snapshot-restore - Restore VMs from snapshot (name: cka-baseline)"
	@echo "make cka-lab-clone     - Sync standalone os76-cka-lab into control plane ~/cka"
	@echo "make preprod-ha-up     - Boot up Vagrant libvirt preprod HA VMs (3 CPs + 1 Worker)"
	@echo "make preprod-ha-deploy - Run full Ansible playbook deployment on HA preprod"
	@echo "make preprod-ha-destroy - Destroy Vagrant libvirt preprod HA VMs"
	@echo "make preprod-ha-sync-kubeconfig - Sync HA preprod credentials (VIP: 192.168.56.9:8443)"
	@echo "make preprod-ha-cka-lab - Deploy CKA lab scenarios on HA preprod (alias: preprod-ha-cka)"
	@echo "make preprod-switch-ha - Switch active topology to HA profile cleanly"
	@echo "make preprod-switch-standard - Switch active topology to Standard profile cleanly"

deps:
	ansible-galaxy collection install -r requirements.yml

check-deps:
	@echo "Checking required collections from requirements.yml..."
	@awk '/name:/ {print $$3}' requirements.yml | while read -r col; do \
		ansible-galaxy collection list "$$col" >/dev/null 2>&1 || { echo "❌ Missing collection: $$col. Run 'make deps' to install."; exit 1; }; \
		echo "✔ $$col is installed."; \
	done
	@echo "All required dependencies are satisfied."

lint:
	./scripts/lint.sh

syntax:
	@for pb in playbooks/*.yml; do \
		echo "Checking $$pb"; \
		ansible-playbook -i inventory/preprod/hosts.ini $$pb --syntax-check; \
	done

inventory:
	ansible-inventory -i inventory/preprod/hosts.ini --graph

preprod-up:
	@echo "standard" > .topology
	./scripts/shell.sh --run "vagrant up"
	./scripts/run-playbook.sh -e preprod -p nfs.yml
	@./scripts/sync-kubeconfig.sh --best-effort || true

preprod-destroy:
	./scripts/shell.sh --run "vagrant destroy -f"
	@virsh -c qemu:///system vol-delete --pool default k8s-homelab_kube-control-plane-vdb.qcow2 2>/dev/null || true
	@rm -f admin.conf kubeconfig.preprod .topology

preprod-status:
	./scripts/shell.sh --run "vagrant status"

preprod-recreate: preprod-destroy preprod-up

preprod-provision:
	./scripts/shell.sh --run "vagrant provision"

preprod-sync-kubeconfig:
	@./scripts/sync-kubeconfig.sh -e preprod

prod-sync-kubeconfig:
	@./scripts/sync-kubeconfig.sh -e prod

preprod-deploy:
	./scripts/run-playbook.sh -e preprod -p site.yml

preprod-caddy:
	./scripts/run-playbook.sh -e preprod -p caddy.yml

preprod-cni:
	./scripts/run-playbook.sh -e preprod -p cni.yml

preprod-ceph:
	./scripts/run-playbook.sh -e preprod -p ceph.yml

prod-ceph:
	./scripts/run-playbook.sh -e prod -p ceph.yml

preprod-ceph-status:
	@./scripts/check-ceph-status.sh

preprod-iscsi:
	./scripts/run-playbook.sh -e preprod -p iscsi.yml

preprod-fc:
	./scripts/run-playbook.sh -e preprod -p fc.yml

preprod-fc-status:
	@echo "Checking Fibre Channel SAN status on preprod nodes..."
	./scripts/run-playbook.sh -e preprod -p fc.yml

preprod-nfs:
	./scripts/run-playbook.sh -e preprod -p nfs.yml

prod-nfs:
	./scripts/run-playbook.sh -e prod -p nfs.yml

preprod-ha-nfs:
	./scripts/run-playbook.sh -e preprod-ha -p nfs.yml

preprod-nfs-csi:
	./scripts/run-playbook.sh -e preprod -p nfs_csi.yml

prod-nfs-csi:
	./scripts/run-playbook.sh -e prod -p nfs_csi.yml

preprod-upgrade:
	./scripts/run-playbook.sh -e preprod -p upgrade.yml

preprod-reset:
	./scripts/run-playbook.sh -e preprod -p reset.yml

cka-generate:
	ansible-playbook -i "localhost," -c local playbooks/cka_lab_generate.yml

preprod-cka: preprod-cka-lab
preprod-cka-lab:
	./scripts/run-playbook.sh -e preprod -p cka_lab.yml

preprod-cka-chaos:
	./scripts/run-playbook.sh -e preprod -p cka_lab.yml --extra-vars "cka_lab_scenario_chaos_troubleshooting_enabled=true"

preprod-stage-bare:
	./scripts/run-playbook.sh -e preprod -p cka_stage_bare.yml

preprod-stage-prebootstrap:
	./scripts/run-playbook.sh -e preprod -p cka_stage_prebootstrap.yml

preprod-stage-cp-only:
	./scripts/run-playbook.sh -e preprod -p cka_stage_cp_only.yml

preprod-stage-ready:
	./scripts/run-playbook.sh -e preprod -p cka_stage_ready.yml

cka-snapshot-save:
	@echo "Saving libvirt VM snapshot 'cka-baseline' across all preprod VMs..."
	@for dom in k8s-homelab_kube-control-plane k8s-homelab_kube-worker-1 k8s-homelab_kube-worker-2; do \
		echo "  -> Snapshotting $$dom..."; \
		virsh -c qemu:///system snapshot-create-as --domain "$$dom" --name cka-baseline --disk-only --atomic 2>/dev/null || true; \
	done
	@echo "✔ Snapshot 'cka-baseline' saved successfully."

cka-snapshot-restore:
	@echo "Restoring preprod VMs from snapshot 'cka-baseline'..."
	@for dom in k8s-homelab_kube-control-plane k8s-homelab_kube-worker-1 k8s-homelab_kube-worker-2; do \
		echo "  -> Reverting $$dom..."; \
		virsh -c qemu:///system snapshot-revert --domain "$$dom" --snapshotname cka-baseline 2>/dev/null || true; \
	done
	@./scripts/sync-kubeconfig.sh --best-effort || true
	@echo "✔ Restored to snapshot 'cka-baseline'."

cka-lab-clone:
	@echo "Synchronizing standalone os76-cka-lab repository to control plane ~/cka..."
	@CP_IP=$$(awk '/\[control_plane\]/{getline; print $$2}' inventory/preprod/hosts.ini 2>/dev/null | cut -d= -f2); \
	CP_IP=$${CP_IP:-192.168.56.10}; \
	CP_KEY=".vagrant/machines/kube-control-plane/libvirt/private_key"; \
	SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"; \
	if [ -f "$$CP_KEY" ]; then SSH_CMD="$$SSH_CMD -i $$CP_KEY"; fi; \
	rsync -avz --delete \
		-e "$$SSH_CMD" \
		--exclude '.git' \
		--exclude 'ckalab.env' \
		/home/xeno/git/gitea/os76-cka-lab/ \
		vagrant@$$CP_IP:/home/vagrant/cka/ && \
	$$SSH_CMD vagrant@$$CP_IP \
		"chmod +x /home/vagrant/cka/ckalab /home/vagrant/cka/scripts/*.sh 2>/dev/null || true"
	@echo "✔ Standalone CKA lab synced to kube-control-plane:~/cka"

preprod-cks-lab:
	./scripts/run-playbook.sh -e preprod -p cks_lab.yml

preprod-ha-up:
	@echo "ha" > .topology
	TOPOLOGY=ha ./scripts/shell.sh --run "vagrant up"
	./scripts/run-playbook.sh -e preprod-ha -p ha_control_plane.yml
	@./scripts/sync-kubeconfig.sh -e preprod-ha --best-effort || true

preprod-ha-destroy:
	TOPOLOGY=ha ./scripts/shell.sh --run "vagrant destroy -f"
	@virsh -c qemu:///system vol-delete --pool default k8s-homelab_kube-cp-1-vdb.qcow2 2>/dev/null || true
	@rm -f admin.conf kubeconfig.preprod-ha .topology

preprod-ha-recreate: preprod-ha-destroy preprod-ha-up

preprod-ha-deploy:
	./scripts/run-playbook.sh -e preprod-ha -p site.yml

preprod-ha-sync-kubeconfig:
	@./scripts/sync-kubeconfig.sh -e preprod-ha

preprod-ha-cka: preprod-ha-cka-lab
preprod-ha-cka-lab:
	./scripts/run-playbook.sh -e preprod-ha -p cka_lab.yml

preprod-switch-ha: preprod-destroy preprod-ha-up

preprod-switch-standard: preprod-ha-destroy preprod-up

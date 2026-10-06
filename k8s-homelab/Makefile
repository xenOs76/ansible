.PHONY: all lint syntax inventory deps check-deps preprod-up preprod-destroy preprod-recreate preprod-status preprod-provision preprod-sync-kubeconfig prod-sync-kubeconfig preprod-deploy preprod-caddy preprod-cni preprod-ceph prod-ceph preprod-ceph-status preprod-iscsi preprod-nfs prod-nfs preprod-upgrade preprod-reset preprod-cka-lab help

all: help

help:
	@echo "k8s-homelab Makefile"
	@echo "--------------------"
	@echo "make deps              - Install Ansible collection dependencies from requirements.yml"
	@echo "make check-deps        - Verify installed Ansible collection dependencies"
	@echo "make lint              - Run yamllint, syntax check, inventory parse, and ansible-lint"
	@echo "make syntax            - Run ansible-playbook --syntax-check on all playbooks"
	@echo "make inventory         - Show inventory host graph"
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
	@echo "make preprod-nfs       - Deploy/configure NFS storage server on preprod"
	@echo "make prod-nfs          - Deploy/configure NFS storage server on prod"
	@echo "make preprod-upgrade   - Run rolling upgrade on preprod"
	@echo "make preprod-reset     - Teardown/reset cluster on preprod"
	@echo "make preprod-cka-lab   - Deploy CKA training lab scenarios on preprod"
	@echo "make preprod-cka-chaos - Deploy CKA lab including Litmus dynamic chaos drills"

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
	./scripts/shell.sh --run "vagrant up"
	./scripts/run-playbook.sh -e preprod -p nfs.yml
	@./scripts/sync-kubeconfig.sh --best-effort || true

preprod-destroy:
	./scripts/shell.sh --run "vagrant destroy -f"
	@virsh vol-delete --pool default k8s-homelab_kube-control-plane-vdb.qcow2 2>/dev/null || true
	@rm -f admin.conf kubeconfig.preprod

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

preprod-nfs:
	./scripts/run-playbook.sh -e preprod -p nfs.yml

prod-nfs:
	./scripts/run-playbook.sh -e prod -p nfs.yml

preprod-upgrade:
	./scripts/run-playbook.sh -e preprod -p upgrade.yml

preprod-reset:
	./scripts/run-playbook.sh -e preprod -p reset.yml

preprod-cka-lab:
	./scripts/run-playbook.sh -e preprod -p cka_lab.yml

preprod-cka-chaos:
	./scripts/run-playbook.sh -e preprod -p cka_lab.yml --extra-vars "cka_lab_scenario_chaos_troubleshooting_enabled=true"

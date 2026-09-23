.PHONY: all lint syntax inventory deps check-deps preprod-up preprod-destroy preprod-recreate preprod-status preprod-provision preprod-deploy preprod-cni preprod-upgrade preprod-reset help

all: help

help:
	@echo "k8s-homelab Makefile"
	@echo "--------------------"
	@echo "make deps              - Install Ansible collection dependencies from requirements.yml"
	@echo "make check-deps        - Verify installed Ansible collection dependencies"
	@echo "make lint              - Run yamllint, syntax check, inventory parse, and ansible-lint"
	@echo "make syntax            - Run ansible-playbook --syntax-check on all playbooks"
	@echo "make inventory         - Show inventory host graph"
	@echo "make preprod-up        - Boot up Vagrant libvirt preprod VMs"
	@echo "make preprod-destroy   - Destroy Vagrant libvirt preprod VMs"
	@echo "make preprod-recreate  - Clean rebuild: destroy and boot fresh Vagrant VMs"
	@echo "make preprod-status    - Check status of Vagrant VMs"
	@echo "make preprod-provision - Run Vagrant provisioners on running preprod VMs"
	@echo "make preprod-deploy    - Run full site.yml deployment on preprod"
	@echo "make preprod-cni       - Install/verify Cilium CNI on preprod"
	@echo "make preprod-upgrade   - Run rolling upgrade on preprod"
	@echo "make preprod-reset     - Teardown/reset cluster on preprod"

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

preprod-destroy:
	./scripts/shell.sh --run "vagrant destroy -f"

preprod-status:
	./scripts/shell.sh --run "vagrant status"

preprod-recreate: preprod-destroy preprod-up

preprod-provision:
	./scripts/shell.sh --run "vagrant provision"

preprod-deploy:
	./scripts/run-playbook.sh -e preprod -p site.yml

preprod-cni:
	./scripts/run-playbook.sh -e preprod -p cni.yml

preprod-upgrade:
	./scripts/run-playbook.sh -e preprod -p upgrade.yml

preprod-reset:
	./scripts/run-playbook.sh -e preprod -p reset.yml

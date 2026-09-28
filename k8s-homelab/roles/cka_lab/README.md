# Ansible Role: `cka_lab`

Dedicated Ansible role for provisioning isolated hands-on Certified Kubernetes Administrator (CKA) exam training scenarios on the `k8s-homelab` preprod cluster.

## Design & Isolation

- **Targeted Execution**: Invoked exclusively by `make preprod-cka-lab` via `playbooks/cka_lab.yml`.
- **Environment Isolation**: Strictly excluded from standard deployment pipelines (`make preprod-deploy`, `playbooks/site.yml`) and never run against production environments.
- **Modular Scenarios**: Scenarios map directly to CKA curriculum domains (Security, Troubleshooting, Maintenance, Networking) and are managed in modular task files under `tasks/`.

## Scenarios

### Scenario 1: User Authentication & RBAC (`user_rbac`)

- **Domain**: Security & RBAC.
- **Objective**: Create a dedicated Linux and Kubernetes user (`anna`) for RBAC authorization drills.
- **Actions**:
  1. Creates Linux user `anna` on `kube-control-plane` with membership in the `sudo` group and passwordless sudo privileges.
  2. Creates visible certificate directory `/home/anna/certs` (`0755`).
  3. Generates 2048-bit RSA private key (`anna.key`) and CSR (`anna.csr`) with Subject `/CN=anna/O=developers`.
  4. Signs certificate (`anna.crt`) with the cluster's local Kubernetes CA (`/etc/kubernetes/pki/ca.crt`).
  5. Assembles `/home/anna/.kube/config` with embedded client certificates and sets active context to `anna@kubernetes`.

## Verification inside Control Plane

```bash
# SSH into control plane VM
./scripts/shell.sh --run "vagrant ssh kube-control-plane"

# Switch to trainee user
sudo su - anna

# Inspect credentials and context
kubectl config get-contexts
kubectl config current-context

# Test authorization (expected: forbidden until trainee binds roles)
kubectl auth can-i create pods
kubectl get pods
```

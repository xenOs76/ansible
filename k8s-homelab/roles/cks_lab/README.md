# Ansible Role: `cks_lab`

Dedicated Ansible role for provisioning isolated hands-on **Certified Kubernetes Security Specialist (CKS)** exam training scenarios on the `k8s-homelab` preprod cluster, derived from Benjamin Muschko's *Certified Kubernetes Security Specialist (CKS) Study Guide* and the Linux Foundation / CNCF CKS Curriculum.

---

## 1. Design & Isolation

- **Targeted Execution**: Invoked exclusively by `make preprod-cks-lab` via `playbooks/cks_lab.yml`.
- **Environment Isolation**: Strictly isolated from production environments (`prod`) and standard cluster builds (`make preprod-deploy`). All intrusive security tests (simulated attacks, static pod modifications, and policy blocks) run inside ephemeral Libvirt/KVM virtual machines.
- **Homelab Production Roadmap**: Strategic production considerations, hardware sizing for 3x Raspberry Pi 5 (8 GB RAM) nodes, and Istio/Cilium coexistence are maintained in [`docs/HOMELAB_SECURITY_ROADMAP.md`](file:///home/xeno/git/gitea/os76-ansible/k8s-homelab/roles/cks_lab/docs/HOMELAB_SECURITY_ROADMAP.md) for synchronization with `os76-homelab-reliability`.
- **Modular Scenarios**: Each scenario is individually toggleable via feature flags in `defaults/main.yml` and tagged for granular execution.

---

## 2. Scenario Catalog

### Scenario 0: CKS Initial Steps & Cheat Sheet MOTD (`motd`)

- **Domain**: Exam Orientation & Quick Reference.
- **Objective**: Display CKS-specific reminders, critical file paths, and syntax helpers upon SSH login:
  - Static pod manifests: `/etc/kubernetes/manifests/`
  - Kubelet configuration: `/var/lib/kubelet/config.yaml`
  - Seccomp directory: `/var/lib/kubelet/seccomp/`
  - AppArmor profiles: `/etc/apparmor.d/`
  - Audit policy & etcd encryption manifests.

### Scenario 1: Security Tooling Provisioning (`tools`)

- **Domain**: Exam Utilities & Prerequisites.
- **Objective**: Install pinned security binaries on `kube-control-plane`:
  - `kube-bench` (`v0.16.0`): CIS Kubernetes benchmark runner.
  - `trivy` (`v0.75.0`): Vulnerability and misconfiguration scanner.
  - `hadolint` (`v2.12.0`): Dockerfile static linter.
  - `kubesec` (`v2.14.2`): Kubernetes manifest security analyzer.
  - `cosign` (`v2.4.3`): Sigstore container image signing and verification CLI.

### Scenario 2: CIS Benchmark Scanning & Remediation (`cis_bench`)

- **Domain**: Cluster Setup (10%).
- **Objective**: Execute `kube-bench` against master and node components. Provide practice scripts to remediate common failed CIS checks (permissions on `/etc/kubernetes`, certs, and kubelet arguments).

### Scenario 3: Kubernetes API Server Audit Logging (`audit_logs`)

- **Domain**: Monitoring, Logging & Runtime Security (20%).
- **Objective**: Configure API server audit policy with RequestResponse, Metadata, and None stage rules. Mount audit policies into `kube-apiserver.yaml` and configure log rotation. Practice inspecting logs with `jq`.

### Scenario 4: etcd Secrets Encryption at Rest (`etcd_enc`)

- **Domain**: Minimize Microservice Vulnerabilities (20%).
- **Objective**: Generate a 32-byte AES key, configure `EncryptionConfiguration`, update API Server `--encryption-provider-config`, and verify encrypted ciphertext via `etcdctl get`.

### Scenario 5: Host & Kernel Hardening - AppArmor (`apparmor`)

- **Domain**: System Hardening (15%).
- **Objective**: Deploy and parse custom AppArmor profiles on worker nodes (`aa-status`, `aa-enforce`, `apparmor_parser`). Run test pods verifying confinement.

### Scenario 6: System Call Filtering - Seccomp (`seccomp`)

- **Domain**: System Hardening (15%).
- **Objective**: Install custom Seccomp JSON profiles into `/var/lib/kubelet/seccomp/profiles/`. Deploy workloads referencing `Localhost` seccomp profiles.

### Scenario 7: Container Sandboxing with gVisor (`gvisor`)

- **Domain**: Minimize Microservice Vulnerabilities (20%).
- **Objective**: Install `runsc` on worker nodes, register containerd runtime handler, create `RuntimeClass` resource `gvisor`, and deploy sandboxed pods.

### Scenario 8: Pod Security Admission & Webhook Admission (`admission`)

- **Domain**: Minimize Microservice Vulnerabilities & Supply Chain (20%).
- **Objective**: Configure namespace-level Pod Security Admission (PSA) labels (`enforce=restricted`). Set up ImagePolicyWebhook mock service and admission configuration.

### Scenario 9: Supply Chain & Static Analysis Drills (`supply_chain`)

- **Domain**: Supply Chain Security (20%).
- **Objective**: Automated drill scripts for Dockerfile linting (`hadolint`), manifest risk scoring (`kubesec`), and CVE scanning of images (`trivy`).

### Scenario 10: Behavioral Analytics & Runtime Intrusion - Falco (`falco`)

- **Domain**: Monitoring, Logging & Runtime Security (20%).
- **Objective**: Install Falco with local rule overrides (`/etc/falco/falco_rules.local.yaml`). Execute attack simulation script to trigger and verify alerts.

---

## 3. Quick Reference & Commands

```bash
cd k8s-homelab

# Run full CKS training suite against preprod
make preprod-cks-lab

# Run only specific scenario via tags
./scripts/run-playbook.sh playbooks/cks_lab.yml -t tools
./scripts/run-playbook.sh playbooks/cks_lab.yml -t audit_logs
./scripts/run-playbook.sh playbooks/cks_lab.yml -t etcd_enc
```

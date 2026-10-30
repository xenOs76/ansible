# Architecture & Implementation Plan: Move NetworkPolicies from CKA to CKS Lab

## 1. Executive Summary & Rationale

This document defines the comprehensive migration plan to move all Kubernetes NetworkPolicy training drills,
manifests, tests, and documentation from the CKA lab (`roles/cka_lab`) to the dedicated CKS lab (`roles/cks_lab`).

### Curriculum & Pedagogical Justification

1. **Alignment with CNCF Certification Curricula**:
   - In the CNCF / Linux Foundation **CKS (Certified Kubernetes Security Specialist)** curriculum, network security is a
     foundational pillar across two major domains:
     - **Minimize Microservice Vulnerabilities (20%)**: *Implement Pod-to-Pod security using Network Policies*.
     - **Cluster Setup (10%)**: *Use NetworkSecurityPolicies to restrict cluster-level access*.
   - In the **CKA (Certified Kubernetes Administrator)** curriculum, the *Services & Networking* domain (20%) centers on
     traffic management and routing abstractions: ClusterIP, NodePort, LoadBalancer, Headless Services, CoreDNS
     resolution, Ingress controllers, and Gateway API (`HTTPRoute`).
2. **Pedagogical Cohesion**:
   - Pod-to-pod microsegmentation, zero-trust default-deny architectures, multi-tenant isolation, packet drop forensics
     with Cilium Hubble eBPF, and static policy auditing with `kubectl-cyclonus` represent advanced defensive security
     disciplines that naturally belong in the CKS training environment alongside AppArmor, Seccomp, and API audit logs.
3. **Decoupled Lab Execution**:
   - The CKA networking suite (`~/cka/11-networking/`) becomes lean, fast, and focused purely on core routing
     primitives.
   - The CKS lab suite (`~/cks/network-policies/`) gains a dedicated, self-contained multi-tier security practice lab
     that can run independently without depending on extraneous CKA ingress controllers.

---

## 2. Inventory of Current NetworkPolicy Artifacts in `roles/cka_lab`

Currently, NetworkPolicy exercises in `roles/cka_lab` are organized as Modules 4 and 5 inside `11-networking`:

| Component / Subdirectory | Files Involved | Current Purpose | Destination in CKS |
| :--- | :--- | :--- | :--- |
| **Basic Network Policies** (`04-network-policies/`) | 7 templates: namespaces, backend, client, default-deny, allow-client, egress-dns, test runner | Two-namespace client/backend model testing default-deny, ingress label selection, and CoreDNS port 53 egress. | `~/cks/network-policies/01-basic-isolation/` |
| **Progressive NetPol & Hubble** (`05-advanced-network-policies/`) | 8 templates: guide, Hubble guide, workloads, default-deny, allow-kube-dns, allow-external-dns, allow-gateway, test runner | Staged progressive lockdown in `default`: default-deny-all, in-cluster CoreDNS, external DNS via `ipBlock`, and Gateway API traffic whitelisting. Hubble CLI drop tracing. | `~/cks/network-policies/02-progressive-microsegmentation/` |
| **Multi-Tenant Pod Isolation** (`05-advanced-network-policies/`) | 3 templates: cross-tenant workloads, allow-cross-tenant, test runner | Cross-namespace multi-tenant security exercising logical AND (`namespaceSelector` + `podSelector`) between `tenant-a` and `tenant-b`. | `~/cks/network-policies/03-multi-tenant-isolation/` |
| **Policy Analysis Tooling** (`05-advanced-network-policies/`) | Mentioned in guide; tool installed by `roles/control_plane_tools` | Linting and reachability matrix visualization via `kubectl-cyclonus`. | `~/cks/network-policies/04-policy-analysis-cyclonus/` |

---

## 3. Target Architecture in `roles/cks_lab`

### 3.1 Workspace Layout on `kube-control-plane`

The dedicated CKS NetworkPolicy scenario will reside under `/home/vagrant/cks/network-policies/`:

```text
/home/vagrant/cks/network-policies/
├── README.md                                  # Comprehensive CKS NetworkPolicy guide & exam reference
├── test-network-policies.sh                  # Non-interactive master test runner (drills 1 through 3)
├── 01-basic-isolation/                        # Drill 1: Foundational Pod Microsegmentation
│   ├── 01-namespaces-workloads.yaml           # Isolated client & backend namespaces and probe pods
│   ├── 02-default-deny-ingress.yaml           # Ingress default-deny policy
│   ├── 03-allow-client-to-backend.yaml        # Whitelisted ingress via podSelector & namespaceSelector
│   ├── 04-allow-coredns-egress.yaml           # Whitelisted egress to CoreDNS UDP/TCP 53
│   └── test-basic-isolation.sh                # Non-interactive verification script for Drill 1
├── 02-progressive-microsegmentation/          # Drill 2: Progressive Zero-Trust Lockdown & Hubble
│   ├── 01-workloads.yaml                      # Multi-tier microservice test client & internal API
│   ├── 02-default-deny-all.yaml               # Strict ingress + egress namespace lockdown
│   ├── 03-allow-kube-dns.yaml                 # CoreDNS in-cluster egress rule
│   ├── 04-allow-external-dns.yaml             # External DNS egress rule via ipBlock (1.1.1.1, 8.8.8.8)
│   ├── 05-allow-internal-api.yaml             # Egress to internal backend tier on port 8080
│   ├── hubble-troubleshooting.md              # Live Hubble eBPF drop tracing & flow debugging guide
│   └── test-progressive-netpol.sh             # Progressive validation runner for Drill 2
├── 03-multi-tenant-isolation/                 # Drill 3: Cross-Tenant Logical AND Boundaries
│   ├── 01-cross-tenant-workloads.yaml         # Tenant A (frontend/analytics) & Tenant B (secure-db)
│   ├── 02-allow-cross-tenant.yaml             # Logical AND policy (namespaceSelector + podSelector)
│   └── test-multi-tenant.sh                   # Non-interactive verification runner for Drill 3
└── 04-policy-analysis-cyclonus/               # Drill 4: Static Policy Auditing & Matrix Analysis
    ├── README.md                              # Cyclonus explain, lint, and probe usage guide
    └── run-cyclonus-analysis.sh               # Non-interactive cyclonus lint & matrix check
```

### 3.2 Design Decisions for CKS Decoupling

1. **Decouple from Gateway API & Ingress**:
   - In CKA, `05-allow-gateway-httpbin.yaml` used the `nginx-gateway` controller and `httpbingo` service deployed in
     Drill 3.
   - In CKS, Drill 2 (`02-progressive-microsegmentation`) will feature self-contained microservice tiers (e.g.,
     `netpol-client` and `internal-api`) deployed directly inside the scenario namespaces. This ensures `make
     preprod-cks-lab` operates with 100% autonomy without requiring NGINX Gateway Fabric or Ingress-NGINX.
2. **CKS Exam-Specific References**:
   - Update master `README.md` to map directly to Benjamin Muschko's *CKS Study Guide* (Chapter 11: Network Policies)
     and CNCF CKS Exam Domain *Minimize Microservice Vulnerabilities*.
   - Include CKS terminal fast lookups (`kubectl explain networkpolicy.spec.ingress`, `kubectl explain
     networkpolicy.spec.egress`, `ipBlock.except`).
3. **Cilium Hubble Integration**:
   - Retain and elevate the `hubble-troubleshooting.md` guide and scripts into the CKS workspace, as eBPF-level runtime
     packet inspection directly matches the CKS *Monitoring, Logging and Runtime Security* domain.
4. **Namespace Isolation**:
   - Use dedicated CKS namespaces (`cks-net-client`, `cks-net-backend`, `cks-tenant-a`, `cks-tenant-b`) to eliminate
     any possible collision with CKA test namespaces.

---

## 4. Step-by-Step Implementation Plan

### Phase 1: Implement NetworkPolicy Scenario in `roles/cks_lab`

1. **Variables & Defaults (`roles/cks_lab/defaults/main.yml`)**:
   - Add scenario toggle: `cks_lab_scenario_netpol_enabled: true`.
   - Add workspace path: `cks_lab_netpol_workspace: "{{ cks_lab_workspace_dir }}/network-policies"`.
   - Add namespace configurations:

     ```yaml
     cks_lab_netpol_client_namespace: "cks-net-client"
     cks_lab_netpol_backend_namespace: "cks-net-backend"
     cks_lab_netpol_tenant_a: "cks-tenant-a"
     cks_lab_netpol_tenant_b: "cks-tenant-b"
     cks_lab_netpol_namespace: "default"
     ```

2. **Task Definition (`roles/cks_lab/tasks/scenario_network_policy.yml`)**:
   - Create directories:
     - `{{ cks_lab_netpol_workspace }}`
     - `{{ cks_lab_netpol_workspace }}/01-basic-isolation`
     - `{{ cks_lab_netpol_workspace }}/02-progressive-microsegmentation`
     - `{{ cks_lab_netpol_workspace }}/03-multi-tenant-isolation`
     - `{{ cks_lab_netpol_workspace }}/04-policy-analysis-cyclonus`
   - Render Jinja2 templates into destination paths with appropriate file modes (`0755` for scripts, `0644` for
     manifests and markdown).
3. **Task Registration (`roles/cks_lab/tasks/main.yml`)**:
   - Include `scenario_network_policy.yml` when `cks_lab_scenario_netpol_enabled | bool`.
   - Assign tags: `cks_lab`, `netpol`, `network_policy`, `microservices`.
4. **Jinja2 Templates Creation in `roles/cks_lab/templates/`**:
   - `netpol_readme.md.j2` (Master guide covering CKS domains, rules, Cilium eBPF enforcement, and quick lookups).
   - `netpol_test_drills.sh.j2` (Master test suite running all sub-drills non-interactively with non-zero exit codes).
   - `netpol_01_*` templates (Basic client/backend isolation, default-deny, allow rules, test script).
   - `netpol_02_*` templates (Progressive lockdown in `default`, DNS egress, internal API egress, Hubble guide, test
     script).
   - `netpol_03_*` templates (Cross-tenant multi-namespace workloads, logical AND allow rules, test script).
   - `netpol_04_*` templates (`kubectl-cyclonus` explanation, linting, and automated audit script).

### Phase 2: Refactor & Clean Up `roles/cka_lab`

1. **Update `roles/cka_lab/tasks/scenario_networking.yml`**:
   - Remove directory definitions:
     - `{{ cka_lab_networking_dir }}/04-network-policies`
     - `{{ cka_lab_networking_dir }}/05-advanced-network-policies`
   - Remove template loop items for:
     - `networking_04_*`
     - `networking_05_*`
   - Remove tag `networkpolicy` from task blocks in `scenario_networking.yml`.
2. **Delete Obsolete CKA Templates**:
   - Remove `networking_04_*.j2` (7 template files).
   - Remove `networking_05_*.j2` (11 template files).
3. **Refactor Master CKA Networking Guide (`roles/cka_lab/templates/networking_readme.md.j2`)**:
   - Update Directory Structure to include only:
     - `01-services/`
     - `02-ingresses/`
     - `03-gateway-api/`
   - Remove Drill 4 (*Network Policies with httpbin-go*) and Drill 5 (*Progressive Microsegmentation & Hubble*).
   - Add a prominent CKS pointer note:
     > [!NOTE]
     > **Kubernetes Network Policies & Pod Microsegmentation**:
     > Network security policies, multi-tenant isolation, Hubble eBPF flow inspection, and `kubectl-cyclonus` policy
     > auditing are maintained in the dedicated CKS training environment at `/home/vagrant/cks/network-policies/`.
4. **Refactor Master CKA Networking Test Runner (`roles/cka_lab/templates/networking_test_drills.sh.j2`)**:
   - Reduce active test sequence from 7 drills to 4 drills:
     - `[1/4] Testing Services & CoreDNS`
     - `[2/4] Testing Headless Service & SRV/A-Record DNS`
     - `[3/4] Testing Ingress Path Routing`
     - `[4/4] Testing Gateway API & HTTPRoute`
   - Remove NetworkPolicy cleanup logic (`kubectl delete netpol --all`) and tenant namespace deletions from `cleanup()`
     trap.
5. **Clean Up `roles/cka_lab/defaults/main.yml`**:
   - Remove unused NetworkPolicy variables:
     - `cka_lab_networking_client_namespace`
     - `cka_lab_networking_backend_namespace`
     - `cka_lab_networking_tenant_a`
     - `cka_lab_networking_tenant_b`
6. **Update `roles/cka_lab/tasks/main.yml`**:
   - Remove `networkpolicy` tag from the `networking` task block.
   - Update task name to: `Execute CKA Lab Scenario - Services, Ingress & Gateway API (networking)`.
7. **Update `roles/cka_lab/README.md`**:
   - Update Section 2 table for item **11 (`11-networking/`)**: change description to *Services (ClusterIP, NodePort),
     Headless, Ingress, and Gateway API*.
   - Update Scenario 8 walkthrough description and remove Drill 4 and Drill 5 references.

### Phase 3: Update CKS Role Documentation & MOTD

1. **Update `roles/cks_lab/README.md`**:
   - Add Scenario Catalog entry: **Scenario 11: Pod-to-Pod Security & Network Policies (`netpol`)**.
   - Detail objectives: default-deny microsegmentation, cross-tenant isolation, CoreDNS/external egress control, Hubble
     drop analysis, and Cyclonus linting.
   - Add execution commands:

     ```bash
     ./scripts/run-playbook.sh playbooks/cks_lab.yml -t netpol
     ```

2. **Update CKS MOTD / Cheat Sheet (`roles/cks_lab/defaults/main.yml` or future MOTD template)**:
   - Add quick helper reminder for NetworkPolicy:

     ```text
     Network Policies: ~/cks/network-policies/ (kubectl explain networkpolicy.spec.ingress)
     ```

### Phase 4: Project-Wide Documentation & Git Standards

1. **Update `k8s-homelab/CHANGELOG.md`**:
   - Under `## [Unreleased]`, add concise entries:
     - **CKS Training Lab Suite (`roles/cks_lab`, `~/cks/network-policies/`)**: Migrated and enhanced comprehensive
       NetworkPolicy training drills covering basic isolation, progressive zero-trust microsegmentation, multi-tenant
       cross-namespace rules, Hubble eBPF drop tracing, and `kubectl-cyclonus` policy analysis.
     - **CKA Training Lab Streamlining (`roles/cka_lab`, `~/cka/11-networking/`)**: Refactored networking scenario to
       focus strictly on core traffic routing (Services, Headless, Ingress, Gateway API), transferring security and
       policy drills to `roles/cks_lab`.
2. **Update `k8s-homelab/README.md` & `AGENTS.md`**:
   - Update summary tables and descriptions to reflect NetworkPolicies residing in `cks_lab`.
3. **Archive / Update Previous Plan**:
   - Update `docs/plan_advanced_network_policies_drill.md` with a deprecation/superseded notice pointing to this
     document.

---

## 5. Verification & Quality Gates

Before completing the implementation, the following quality gates must pass:

1. **YAML Syntax & Schema Validation**:

   ```bash
   yamllint -c .yamllint k8s-homelab/roles/cka_lab/ k8s-homelab/roles/cks_lab/
   ```

2. **Shell Script Validation**:

   ```bash
   shellcheck -s bash k8s-homelab/roles/cks_lab/templates/*.sh.j2 k8s-homelab/roles/cka_lab/templates/*.sh.j2
   ```

3. **Ansible Lint Validation**:

   ```bash
   nix shell nixpkgs#ansible-lint --command bash -c \
     "ANSIBLE_ROLES_PATH=k8s-homelab/roles ansible-lint -c k8s-homelab/.ansible-lint k8s-homelab/playbooks/site.yml k8s-homelab/playbooks/cka_lab.yml k8s-homelab/playbooks/cks_lab.yml"
   ```

4. **Markdown Standards & 120-Character Line Length**:

   ```bash
   python3 scripts/check-readme-line-length.py \
     k8s-homelab/roles/cks_lab/README.md \
     k8s-homelab/roles/cka_lab/README.md \
     k8s-homelab/docs/plan_move_network_policies_to_cks_lab.md
   ```

   ```bash
   nix shell nixpkgs#markdownlint-cli2 --command markdownlint-cli2 \
     k8s-homelab/roles/cks_lab/README.md \
     k8s-homelab/roles/cka_lab/README.md \
     k8s-homelab/docs/plan_move_network_policies_to_cks_lab.md
   ```

5. **Dry-Run / Syntax Check of Ansible Playbooks**:

   ```bash
   ansible-playbook -i k8s-homelab/inventory/preprod/hosts.ini k8s-homelab/playbooks/cks_lab.yml --syntax-check
   ansible-playbook -i k8s-homelab/inventory/preprod/hosts.ini k8s-homelab/playbooks/cka_lab.yml --syntax-check
   ```

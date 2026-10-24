# Architecture & Implementation Plan: Advanced NetworkPolicies & Hubble Troubleshooting Drill

## 1. Overview & Pedagogical Objectives

This plan details the modernization of Module 5 (`11-networking/05-advanced-network-policies/`) in the CKA lab suite.
The revised scenario shifts from an isolated two-namespace mock DB to an exam-relevant progressive hardening drill in
the `default` namespace, combined with Cilium Hubble eBPF observability for network policy debugging.

Trainees will practice:

1. **Total Namespace Isolation**: Enforcing strict `default-deny` for Ingress and Egress on the `default` namespace.
2. **Phase 1 — In-Cluster CoreDNS**: Whitelisting egress to CoreDNS pods in `kube-system` on port 53 (UDP/TCP).
3. **Phase 2 — External DNS**: Whitelisting egress via `ipBlock` to external DNS resolvers (`1.1.1.1`, `8.8.8.8`).
4. **Phase 3 — Gateway API & httpbingo**: Permitting L7 HTTP communication from the internal client to the NGINX
   Gateway Fabric controller (`nginx-gateway` namespace) and backend `httpbingo` service.
5. **Phase 4 — External Ingress Validation**: Validating external host traffic routed through NodePort `30080` to the
   NGINX Gateway, observing how `default-deny` blocks external traffic and how the ingress policy restores it.
6. **Hubble Observability**: Using the `hubble` CLI to dump live flows, isolate `DROPPED` verdicts, verify policy
   enforcement, and trace DNS and HTTP requests.

---

## 2. Workload & Network Topology

```text
+---------------------------------------------------------------------------------------------------+
| External Host / VM Shell (outside cluster)                                                        |
|   curl http://httpbin.example.local:30080/headers --resolve httpbin.example.local:30080:<NODE_IP> |
+---------------------------------------------------------------------------------------------------+
                               |
                               | (NodePort 30080)
                               v
+---------------------------------------------------------------------------------------------------+
| Kubernetes Cluster (Cilium eBPF Datapath)                                                         |
|                                                                                                   |
|  [Namespace: default]                                                                             |
|    +-----------------------+                    [Namespace: nginx-gateway]                        |
|    | netpol-client         |                      +-----------------------------+                 |
|    | (curl / test client)  | ---- (HTTP 80) ----> | ngf-nginx-gateway-fabric    |                 |
|    +-----------------------+                      +-----------------------------+                 |
|               |                                                  |                                |
|        (CoreDNS Port 53)                                  (Forward to Backend)                    |
|               v                                                  v                                |
|  [Namespace: kube-system]                       [Namespace: default]                              |
|    +-----------------------+                      +-----------------------------+                 |
|    | coredns (kube-dns:53) |                      | httpbingo (target backend)  |                 |
|    +-----------------------+                      +-----------------------------+                 |
|               |                                                                                   |
|        (External Port 53)                                                                         |
|               v                                                                                   |
|       (Public Internet: 1.1.1.1 / 8.8.8.8 via ipBlock)                                            |
+---------------------------------------------------------------------------------------------------+
```

### Components Deployed

1. **Test Client Pod (`netpol-test-client`)**: A lightweight `curlimages/curl` pod deployed in `default` with label
   `app=netpol-client` for in-cluster probing.
2. **Backend Target (`httpbingo`)**: Lightweight HTTP echo service in `default` with label
   `app.kubernetes.io/name: httpbingo` (deployed via `helm/install-httpbin-go.sh`).
3. **NGINX Gateway Fabric**: Gateway controller and Gateway resource deployed in `nginx-gateway` (listens on port 80
   internally and binds NodePort `30080` externally).
4. **CoreDNS**: Upstream cluster DNS running in `kube-system` labeled `k8s-app=kube-dns`.
5. **External Host Client Probe**: Shell commands executed directly from the VM host (`kube-control-plane`) simulating
   external traffic hitting the cluster edge via `--resolve httpbin.example.local:30080:<NODE_IP>`, exactly matching
   the `cka-lab-gateway` listener (port 80 / NodePort 30080) and `cka-lab-httproute` hostname `httpbin.example.local`.

---

## 3. Step-by-Step Progressive Policy Sequence

The scenario directory (`05-advanced-network-policies/`) will contain staged declarative manifests:

### Stage 0: Workloads Setup (`01-workloads.yaml`)

- Deploys `netpol-test-client` in `default`.
- Ensures target service `httpbingo` exists in `default` (from `11-networking/03-gateway-api/` prerequisites).
- Verifies initial open connectivity from both internal client and external host:
  - Internal: `kubectl exec netpol-test-client -- curl -s http://httpbingo/get` (200 OK).
  - External: `curl -s http://httpbin.example.local:30080/headers --resolve httpbin.example.local:30080:<NODE_IP>`
    (200 OK, matching Gateway listener port 80 / NodePort 30080 and HTTPRoute host `httpbin.example.local`).

### Stage 1: Strict Default-Deny (`02-default-deny-all.yaml`)

- Applies a namespace-wide default-deny NetworkPolicy in `default`:

  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: default-deny-all
    namespace: default
  spec:
    podSelector: {}
    policyTypes:
      - Ingress
      - Egress
  ```

- **Observed Internal Behavior**: Client egress is blocked; all outbound connections (DNS, HTTP) time out.
- **Observed External Behavior**: External curl to NodePort `30080` fails with 504 Gateway Timeout or connection drop
  because NGINX Gateway Fabric cannot forward requests to `httpbingo` in `default`:

  ```bash
  curl -m 5 -s http://httpbin.example.local:30080/headers --resolve httpbin.example.local:30080:${NODE_IP}
  # Fails / times out due to default-deny Ingress on httpbingo
  ```

- **Hubble Inspection**: `hubble observe --namespace default --verdict DROPPED -f` captures `BPF DROP (Policy denied)`
  for both outbound client queries and incoming proxied requests from `nginx-gateway`.

### Stage 2: Whitelist In-Cluster CoreDNS (`03-allow-kube-dns.yaml`)

- Whitelists egress to `kube-system` namespace on UDP and TCP port 53:

  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-kube-dns-egress
    namespace: default
  spec:
    podSelector:
      matchLabels:
        app: netpol-client
    policyTypes:
      - Egress
    egress:
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
            podSelector:
              matchLabels:
                k8s-app: kube-dns
        ports:
          - protocol: UDP
            port: 53
          - protocol: TCP
            port: 53
  ```

- **Observed Behavior**: `nslookup kubernetes.default.svc.cluster.local` succeeds. External domain lookups and HTTP
  traffic remain blocked.
- **Hubble Inspection**: `hubble observe --namespace default --protocol dns` displays allowed CoreDNS port 53 flows.

### Stage 3: Whitelist External DNS (`04-allow-external-dns.yaml`)

- Whitelists egress to external DNS servers using `ipBlock`:

  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-external-dns-egress
    namespace: default
  spec:
    podSelector:
      matchLabels:
        app: netpol-client
    policyTypes:
      - Egress
    egress:
      - to:
          - ipBlock:
              cidr: 1.1.1.1/32
          - ipBlock:
              cidr: 8.8.8.8/32
        ports:
          - protocol: UDP
            port: 53
          - protocol: TCP
            port: 53
  ```

- **Observed Behavior**: `nslookup google.com 1.1.1.1` and `nslookup cloudflare.com 8.8.8.8` succeed. General external
  HTTP traffic to other IPs or non-DNS ports remains blocked.

### Stage 4: Allow Gateway API & httpbingo Ingress/Egress (`05-allow-gateway-httpbin.yaml`)

Following Gateway API best practices, the `Gateway` infrastructure resource is deployed in the dedicated
infrastructure namespace `nginx-gateway` with cross-namespace routing allowed (`allowedRoutes.namespaces.from: All`).
Because NGINX Gateway Fabric deploys its data-plane proxy pod inside the Gateway's namespace (`nginx-gateway`), the
proxy runs completely outside tenant `default` lockdown. This isolates controller traffic (`:8443`) within
`nginx-gateway` and eliminates the need for proxy-specific egress policies in tenant namespaces.

Tenant namespace `default` defines two minimal, declarative cross-namespace NetworkPolicies:

  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-gateway-to-httpbingo
    namespace: default
  spec:
    podSelector:
      matchLabels:
        app.kubernetes.io/name: httpbingo
    policyTypes:
      - Ingress
    ingress:
      - from:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: nginx-gateway
        ports:
          - protocol: TCP
            port: 8080
  ---
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: allow-client-to-gateway
    namespace: default
  spec:
    podSelector:
      matchLabels:
        app: netpol-client
    policyTypes:
      - Egress
    egress:
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: nginx-gateway
        ports:
          - protocol: TCP
            port: 80
  ```

- **Observed Internal Behavior**:
  - Direct client-to-backend access (`curl -s http://httpbingo/get`) times out / drops
    (`policy-verdict:none EGRESS DENIED`), strictly enforcing microsegmentation.
  - Client access routed through the Gateway proxy
    (`curl -H "Host: httpbin.example.local" http://cka-lab-gateway-nginx.nginx-gateway/get`) succeeds with HTTP 200.
- **Observed External Host Behavior**: The external curl from the host through NodePort `30080` succeeds:

  ```bash
  curl -s http://httpbin.example.local:30080/headers \
    --resolve httpbin.example.local:30080:${NODE_IP}
  ```

  Alternatively, testing through the `/httpbin` path rewrite rule:

  ```bash
  curl -s http://httpbin.example.local:30080/httpbin/headers \
    --resolve httpbin.example.local:30080:${NODE_IP}
  ```

  Expected response (matching HTTPRoute hostname `httpbin.example.local` and root/rewrite rules):

  ```json
  {
    "headers": {
      "Accept": ["*/*"],
      "Host": ["httpbin.example.local:30080"],
      "User-Agent": ["curl/8.18.0"],
      "X-Forwarded-For": ["192.168.121.62"],
      "X-Forwarded-Host": ["httpbin.example.local"],
      "X-Forwarded-Port": ["80"],
      "X-Forwarded-Proto": ["http"],
      "X-Real-Ip": ["192.168.121.62"]
    }
  }
  ```

---

## 4. Hubble Observability & Troubleshooting Guide

A dedicated markdown reference (`hubble-troubleshooting.md`) will guide trainees through real-time traffic analysis:

### 1. Enabling Port-Forwarding

```bash
cilium hubble port-forward &
hubble status
```

### 2. Tracing Policy Drops in Real-Time

```bash
# Watch dropped packets live in default namespace
hubble observe --namespace default --verdict DROPPED -f

# Filter for specific client pod drops
hubble observe --pod default/netpol-test-client --verdict DROPPED

# Filter for drops on the httpbingo backend
hubble observe --pod default/httpbingo --verdict DROPPED
```

### 3. Monitoring DNS Queries and Resolutions

```bash
# Observe DNS resolution flows
hubble observe --namespace default --protocol dns -f
```

### 4. Inspecting L7 HTTP & Gateway Traffic

```bash
# Trace HTTP requests and response codes across namespaces
hubble observe --namespace default --protocol http -f

# Trace incoming proxied flows from nginx-gateway
hubble observe --from-namespace nginx-gateway --to-namespace default -f

# Compact one-line flow format
hubble observe --namespace default -o compact
```

---

## 5. Automated Validation Test Suite (`test-advanced-netpol.sh`)

A defensive Bash verification script executing sequential validation phases:

1. **Phase 1 (Baseline)**: Verify open connectivity before policies are applied (internal curl + external NodePort).
2. **Phase 2 (Default Deny)**: Apply `02-default-deny-all.yaml`, assert that internal calls and external NodePort
   curls fail/drop.
3. **Phase 3 (CoreDNS)**: Apply `03-allow-kube-dns.yaml`, assert cluster DNS resolves, assert HTTP and external DNS
   remain blocked.
4. **Phase 4 (External DNS)**: Apply `04-allow-external-dns.yaml`, assert lookups against public DNS resolvers succeed.
5. **Phase 5 (Gateway & httpbingo)**: Apply `05-allow-gateway-httpbin.yaml`, assert internal GET via Gateway succeeds,
   and assert external host curl via NodePort `30080` succeeds and returns expected HTTP headers.
6. **Phase 6 (Hubble Diagnostics)**: Query `hubble observe` to assert that drops were recorded during Phase 2.

---

## 6. Proposed Files & Templates to Add/Modify

| Path in Repository | Purpose | Action |
| --- | --- | --- |
| `k8s-homelab/roles/cka_lab/templates/networking_05_guide.md.j2` | Scenario documentation & exam quick lookups | Rewrite with progressive drill details |
| `k8s-homelab/roles/cka_lab/templates/networking_05_workloads.yaml.j2` | Client and target workloads in `default` | Update with client and httpbingo definitions |
| `k8s-homelab/roles/cka_lab/templates/networking_05_02_default_deny.yaml.j2` | Strict namespace isolation policy | New template |
| `k8s-homelab/roles/cka_lab/templates/networking_05_03_allow_coredns.yaml.j2` | CoreDNS in-cluster whitelisting | New template |
| `k8s-homelab/roles/cka_lab/templates/networking_05_04_allow_external_dns.yaml.j2` | External DNS `ipBlock` whitelisting | New template |
| `k8s-homelab/roles/cka_lab/templates/networking_05_05_allow_gateway_httpbin.yaml.j2` | Gateway and backend HTTP routing policies | New template |
| `k8s-homelab/roles/cka_lab/templates/networking_05_hubble_troubleshooting.md.j2` | Hubble CLI troubleshooting guide | New template |
| `k8s-homelab/roles/cka_lab/templates/networking_05_test_advanced_netpol.sh.j2` | Matrix automated validation test runner (internal + external) | Updated test suite |
| `k8s-homelab/roles/cka_lab/tasks/scenario_networking.yml` | Ansible task deploying files to `~/cka/11-networking/05-...` | Add new templates to copy loop |
| `k8s-homelab/roles/cka_lab/templates/networking_readme.md.j2` | Master networking guide (Module 5 overview) | Update scenario description & instructions |

---

## 7. Quality Gates & Acceptance Criteria

1. **YAML Validation**: All manifest templates must pass `yamllint -c .yamllint`.
2. **Bash Standards**: `test-advanced-netpol.sh` must adhere to `set -euo pipefail` and pass `shellcheck -s bash`.
3. **Markdown Standards**: All markdown templates and guides must pass `check-readme-line-length.py` (<= 120 chars)
   and `markdownlint-cli2`.
4. **Ansible Lint**: Zero failures and zero warnings under `ansible-lint` production profile.

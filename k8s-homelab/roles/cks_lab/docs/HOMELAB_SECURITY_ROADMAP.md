# OS76 Homelab Security & Mesh Architecture Roadmap

This document captures the strategic security and service mesh architecture for the OS76 physical homelab cluster (`prod`) and its relationship to the CKS training environment (`preprod`). It is authored for direct synchronization and reference in [`os76-homelab-reliability`](file:///home/xeno/git/gitea/os76-homelab-reliability).

---

## 1. Physical Cluster Hardware Baseline & Resource Sizing

### 1.1 Physical Inventory (`flux`, `rpi501`, `rpi502`)

The production Kubernetes cluster consists of 3 bare-metal nodes:

- **`flux`** (Control Plane, `192.168.1.114`): Raspberry Pi 5 (4-core ARM Cortex-A76 @ 2.4 GHz, 8 GB LPDDR4X RAM).
- **`rpi501`** (Worker 1, `192.168.1.151`): Raspberry Pi 5 (4-core ARM Cortex-A76 @ 2.4 GHz, 8 GB LPDDR4X RAM).
- **`rpi502`** (Worker 2, `192.168.1.152`): Raspberry Pi 5 (4-core ARM Cortex-A76 @ 2.4 GHz, 8 GB LPDDR4X RAM).
- **Total Cluster Hardware Capacity**: 12 CPU cores, **24 GB total RAM**, Gigabit Ethernet, Broadcom BCM2712 SoC with **ARMv8 Cryptography Extensions (hardware AES)**.

### 1.2 Measured Live Resource Consumption (`kubectl top`)

Measured from live cluster workloads (`monitoring`, `default`, `keycloak`, `gitea`, `flux-system`):

- **`flux`**: CPU 279m (6%), RAM 4,802 MiB (59% of 8 GB). Hosts k3s control plane, Keycloak (~474M), Alloy (~149M), metrics-server, flux-system controllers, Istio Ingress Gateway (~74M).
- **`rpi501`**: CPU 159m (3%), RAM 2,512 MiB (31% of 8 GB). Hosts Prometheus stack (~1,148M), Gitea runner (~377M), apps.
- **`rpi502`**: CPU 112m (2%), RAM 1,385 MiB (17% of 8 GB). Hosts Gitea runner (~295M), Velero (~127M), Istiod (~101M), apps.
- **Cluster Total**: ~550m CPU (4.5% load), **~8.7 GB RAM utilized (36% of 24 GB)**.
- **Available Cluster Headroom**: **~15.3 GB RAM free**.

### 1.3 Projected Resource Demand: `kubeadm` + Cilium CNI

- **Discrete Control Plane (`kube-apiserver` + `etcd` + `controller-manager` + `scheduler`)**: ~1.2 – 1.8 GB RAM on `flux`. (Comparable footprint to the bundled `k3s` server).
- **Cilium eBPF CNI on ARM64**: ~250–350 MiB RAM per node for `cilium-agent`, ~100 MiB for `cilium-operator`. Runs in kernel eBPF memory.
- **Istio Mesh (`istiod` + sidecars)**: ~100 MiB for `istiod`, ~75 MiB for `istio-gateway-ingress`, ~40–60 MiB per injected pod.
- **Conclusion**: Ample headroom exists. The cluster will operate comfortably at ~40–45% aggregate RAM utilization.

---

## 2. Production Security Controls: Prioritization & Exclusion Matrix

When translating CKS certification practices to physical Raspberry Pi 5 bare metal, controls are partitioned into prioritized defaults vs excluded lab mechanisms:

| Security Domain | Physical Cluster Recommendation | Resource Impact | Rationale / Hardware Considerations |
| :--- | :---: | :---: | :--- |
| **CIS Hardening (`kube-bench`)** | 🟢 **Prioritize** | **0 MB** | File permission hardening (`chmod 600` on certs/etcd, `644` on configs). Zero runtime memory cost. |
| **etcd Secret Encryption at Rest** | 🟢 **Prioritize** | **< 5 MB** | In-memory AES-GCM. Cortex-A76 cores feature **ARMv8 Cryptography Extensions (hardware AES)**. Hardware acceleration prevents CPU overhead and protects secrets stored on physical flash media. |
| **API Server Audit Logging** | 🟢 **Prioritize** | **< 10 MB** (Disk I/O) | Critical for activity tracking and forensics. Keep policy at `Metadata` with `--audit-log-maxsize 50` and `--audit-log-maxbackup 3` to limit flash storage write cycles. |
| **Pod Security Standards (PSA)** | 🟢 **Prioritize** | **0 MB** | Built-in Kubernetes admission controller. Enforce `baseline` or `restricted` at zero RAM cost. |
| **Cilium NetworkPolicies** | 🟢 **Prioritize** | **0 MB** | Enforced inside Linux kernel eBPF map tables without userspace proxy overhead. |
| **AppArmor & Seccomp** | 🟢 **Prioritize** | **0 MB** | Native Linux kernel LSM and BPF syscall filters; zero memory overhead. |
| **Vulnerability & Manifest Scans** | 🟢 **Prioritize in CI/CD** | Offloaded | Run `trivy`, `hadolint`, `kubesec` in Gitea Actions runners or workstation pre-commit, not as daemon in-cluster. |
| **Falco Runtime Monitoring** | 🟡 **Prioritize with Tuning** | ~180–250 MiB / node | Supported on ARM64 via modern eBPF driver. Must deploy tuned homelab rule filters to prevent false alert floods. |
| **gVisor (`runsc`) Sandboxing** | 🔴 **Exclude on RPi** | High CPU overhead | Userspace kernel emulation (ptrace) incurs severe performance penalties on ARM64. Retained in x86_64 `preprod` KVM lab only. |
| **Rook-Ceph (Storage)** | 🔴 **Exclude on RPi** | 2–3 GB RAM / node | Demands fast enterprise NVMe and GBs of RAM. Homelab uses Linux kernel **NFS** (`roles/nfs_server`) and `local-path-provisioner`. |
| **ImagePolicyWebhook** | 🔴 **Exclude on RPi** | Availability risk | Single point of failure: if webhook pod is delayed during node reboot, all pod creation blocks. |

---

## 3. Service Mesh Architecture: Cilium CNI & Istio Coexistence

The live homelab currently runs **Istio 1.29.2** (defined in [`os76-tf/k3s`](file:///home/xeno/git/gitea/os76-tf/k3s)):

- `istiod` (with OpenTelemetry trace propagation and custom Envoy access log formatting).
- `istio-gateway-ingress` (NodePort `30080` HTTP, `30443` HTTPS).
- Automatic sidecar injection (`istio-injection: enabled`) on `default` and `monitoring`.
- External traffic ingress via Caddy (`caddy_upstream_port: 30443`) reverse-proxying into Istio Ingress Gateway.

### 3.1 Coexistence Mechanics (Cilium L3/L4 + Istio L7)

- **Layer 3/4**: Cilium handles eBPF packet routing, Pod IPAM, NodePort forwarding, and kernel-level NetworkPolicies.
- **Layer 7**: Istio handles mutual TLS (mTLS), fine-grained HTTP routing, and distributed tracing.

### 3.2 Key Configuration Requirement: `socketLB`

- **Issue**: Cilium's default kube-proxy replacement uses eBPF socket load balancing (`bpf.lbSocket: true`). It intercepts `connect()` syscalls inside the pod namespace, which can bypass Envoy sidecar `iptables` redirection rules (`PREROUTING`/`OUTPUT`).
- **Solution**: Configure Cilium with:

```yaml
socketLB:
  hostNamespaceOnly: true
```

This restricts socket load balancing to the host namespace, ensuring pod-level traffic is cleanly redirected through Envoy sidecars.

### 3.3 Evaluation of Istio Ambient Mode

- **Mechanism**: Replaces per-pod Envoy sidecars with **ztunnel** (Zero-Trust Tunnel, a shared Rust daemon per node for L4 mTLS) and optional **Waypoint proxies** (Envoy instances deployed only for namespaces needing L7 routing).
- **Resource Impact**:
  - Eliminates 40–60 MiB per injected pod, reclaiming **~1.0 to 1.5 GB RAM** across the cluster.
  - Rust ztunnel consumes only **~30–50 MiB RAM per node**.
  - Zero pod restarts during data plane upgrades.

### 3.4 Long-Term Convergence: Replacing Istio with Native Cilium Service Mesh

In the long run, Cilium can completely replace Istio with **zero security loss**:

1. **Mutual TLS**: Cilium Mutual Authentication (SPIFFE) + kernel WireGuard transparent encryption replaces Envoy Citadel mTLS.
2. **L7 Policies**: `CiliumNetworkPolicy` HTTP rules replace Istio `AuthorizationPolicy`.
3. **Ingress Gateway**: Cilium Ingress / Gateway API (`Gateway`, `HTTPRoute`) replaces `istio-gateway-ingress`.
4. **Telemetry**: Hubble eBPF L7 observability + OpenTelemetry integration replaces Envoy access logs.
5. **Resource Win**: Reclaims **~1.5 to 2.0 GB RAM** across the cluster and eliminates sidecar overhead entirely.

---

## 4. Operational Transition Strategy

1. **Milestone 1 (Immediate)**: Complete CKS certification exercises in `preprod` (pure Kubernetes security on Vagrant).
2. **Milestone 2 (Preprod Verification)**: Deploy `os76-tf/k3s` Istio charts on top of preprod Cilium with `socketLB.hostNamespaceOnly: true` to validate sidecar behavior.
3. **Milestone 3 (Prod Migration)**: Migrate live workloads to the hardened `prod` cluster maintaining Istio compatibility.
4. **Milestone 4 (Convergence)**: Transition to Istio Ambient Mode or native Cilium Gateway API, permanently retiring Istio sidecars.

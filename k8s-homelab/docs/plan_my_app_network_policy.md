# Implementation Plan: CKA NetworkPolicy Drill (`my-app-network-policy`)

## 1. Scenario Objective & Requirements

Create an end-to-end hands-on CKA exam practice drill based on a classic exam pattern:

- **Workloads**:
  - `my-app-deployment`: Frontend/application workload exposed via ClusterIP service `my-app-service`.
  - `cache-deployment`: Backend cache workload (e.g., Redis or lightweight cache simulator).
  - `trusted-client`: Test pod labeled with `app=trusted`.
  - `untrusted-client`: Test pod labeled with `app=untrusted`.
- **Policy Requirements (`my-app-network-policy`)**:
  - **Target**: Protects `my-app-deployment` pods.
  - **Ingress**:
    - Allow incoming traffic only from pods.
    - Specifically allow incoming traffic from a pod labeled `app=trusted`.
    - Deny all other incoming traffic (from untrusted pods, other namespaces, or external sources).
  - **Egress**:
    - Allow outgoing traffic to pods (specifically `cache-deployment` pods or cluster pods).
    - Allow DNS resolution (port 53 UDP/TCP to CoreDNS) so `my-app` can resolve service hostnames.
    - Deny all other outgoing traffic (external networks, unauthorized cluster services, or metadata endpoints).
  - **Policy Types**: Explicitly sets `policyTypes: ["Ingress", "Egress"]` to enforce default-deny for non-whitelisted
    flows.

```mermaid
flowchart TD
    subgraph Clients ["Client Pods"]
        TrustedPod["trusted-client\n(app=trusted)"]
        UntrustedPod["untrusted-client\n(app=untrusted)"]
    end

    subgraph TargetApp ["my-app Target Domain"]
        MyAppSvc["my-app-service:80"]
        MyAppPod["my-app-deployment\n(app=my-app)"]
    end

    subgraph Backend ["Backend Dependencies"]
        CacheSvc["cache-service:6379"]
        CachePod["cache-deployment\n(app=cache)"]
        CoreDNS["CoreDNS\n(port 53 UDP/TCP)"]
        External["External / Internet / Other"]
    end

    TrustedPod -- "ALLOW (Ingress)" --> MyAppSvc --> MyAppPod
    UntrustedPod -- "DENY / Drop" -.-x MyAppSvc

    MyAppPod -- "ALLOW (Egress)" --> CacheSvc --> CachePod
    MyAppPod -- "ALLOW (Egress DNS)" --> CoreDNS
    MyAppPod -- "DENY / Drop" -.-x External
```

---

## 2. Manifest Specifications

### A. Target Workloads (`my-app-workload.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-deployment
  namespace: default
  labels:
    app: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: registry.k8s.io/e2e-test-images/agnhost:2.45
          args: ["netexec", "--http-port=8080"]
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
---
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  namespace: default
  labels:
    app: my-app
spec:
  type: ClusterIP
  selector:
    app: my-app
  ports:
    - name: http
      port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-deployment
  namespace: default
  labels:
    app: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
        - name: cache
          image: registry.k8s.io/e2e-test-images/agnhost:2.45
          args: ["netexec", "--http-port=6379"]
          ports:
            - containerPort: 6379
              name: redis
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
---
apiVersion: v1
kind: Service
metadata:
  name: cache-service
  namespace: default
  labels:
    app: cache
spec:
  type: ClusterIP
  selector:
    app: cache
  ports:
    - name: redis
      port: 6379
      targetPort: 6379
```

### B. Verification Clients (`my-app-clients.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: trusted-client
  namespace: default
  labels:
    app: trusted
spec:
  containers:
    - name: client
      image: registry.k8s.io/e2e-test-images/agnhost:2.45
      command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: untrusted-client
  namespace: default
  labels:
    app: untrusted
spec:
  containers:
    - name: client
      image: registry.k8s.io/e2e-test-images/agnhost:2.45
      command: ["sleep", "3600"]
```

### C. The NetworkPolicy (`my-app-network-policy.yaml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-app-network-policy
  namespace: default
spec:
  # 1. Target my-app-deployment pods
  podSelector:
    matchLabels:
      app: my-app
  # 2. Enforce both Ingress and Egress isolation
  policyTypes:
    - Ingress
    - Egress
  # 3. Ingress: Allow only from pods with label app=trusted
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: trusted
      ports:
        - protocol: TCP
          port: 8080
  # 4. Egress: Allow traffic to backend cache pods and CoreDNS
  egress:
    # 4a. Allow egress to cache pods
    - to:
        - podSelector:
            matchLabels:
              app: cache
      ports:
        - protocol: TCP
          port: 6379
    # 4b. Allow DNS resolution to kube-system CoreDNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

---

## 3. Key Design Decisions & Variations for Trainees

### Variation 1: Scope of "Allow Outgoing Traffic to Pods"

In exam prompts, "Allow outgoing traffic to pods" can be interpreted in two ways:

1. **Specific Backend Pods (`app=cache`)**: Matches strict microsegmentation where only designated dependencies
   are accessible.
1. **Any Pod in Same Namespace (`podSelector: {}`)**:

   ```yaml
   egress:
     - to:
         - podSelector: {}
   ```

   Allows outgoing traffic to all pods in the current namespace (including cache pods) while still denying external/IP
   traffic.

*Decision*: The lab drill will explain both variations, with the default solution enforcing strict cache targeting
while teaching the `podSelector: {}` shortcut.

### Variation 2: DNS Egress Requirement

If `my-app` accesses `cache-service` via hostname (`cache-service.default.svc.cluster.local:6379`), DNS resolution on
port 53 is mandatory. If DNS egress is not whitelisted, name resolution fails even if traffic to the cache pod IP is
allowed. The exercise will highlight this common exam pitfall.

---

## 4. Automated Verification Test Suite (`test-my-app-netpol.sh`)

A fully automated, non-interactive script that validates:

1. **Baseline reachability** before policy application (trusted, untrusted, and cache all reachable).
1. **Policy enforcement**:
   - `trusted-client` -> `my-app-service:80`: **SUCCESS** (HTTP 200).
   - `untrusted-client` -> `my-app-service:80`: **BLOCKED** (Timeout within 2s).
   - `my-app` -> `cache-service:6379`: **SUCCESS** (TCP connect).
   - `my-app` -> `http://1.1.1.1` (external): **BLOCKED** (Timeout within 2s).
   - `my-app` -> internal non-cache services: **BLOCKED**.
1. **Clean teardown** upon script completion.

---

## 5. Repository Layout & Integration

We will place this exercise in a dedicated subfolder under `04-network-policies/`:

```text
k8s-homelab/roles/cka_lab/templates/
├── networking_04_my_app_workload.yaml.j2     # my-app, cache, and services
├── networking_04_my_app_clients.yaml.j2      # trusted and untrusted test clients
├── networking_04_my_app_netpol.yaml.j2       # my-app-network-policy manifest
├── networking_04_my_app_test.sh.j2           # Non-interactive automated test script
└── networking_04_my_app_exercise.md.j2       # Step-by-step walkthrough & exam tips
```

And update:

- `roles/cka_lab/tasks/scenario_networking.yml` to template and deploy the new drill.
- `roles/cka_lab/templates/networking_readme.md.j2` with a dedicated walkthrough section.
- `roles/cka_lab/templates/networking_test_drills.sh.j2` to include the test in the master suite.

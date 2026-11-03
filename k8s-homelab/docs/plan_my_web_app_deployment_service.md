# Implementation Plan: `my-web-app-deployment` & `my-web-app-service` NodePort Drill

This plan outlines the architecture, manifest definitions, imperative shortcuts, automated verification suite,
and integration steps for the classic CKA exam practice scenario: deploying a 2-replica WordPress deployment
and exposing it across all cluster nodes via a NodePort service on dedicated port `30770`.

---

## 1. Problem Statement & Exam Objectives

### Task Specification

1. Create a Kubernetes Deployment named **`my-web-app-deployment`**:
   - Container image: `wordpress`
   - Replicas: `2`
   - Standard container port: `80` (HTTP)
2. Expose **`my-web-app-deployment`** as a Kubernetes Service named **`my-web-app-service`**:
   - Service Type: `NodePort`
   - Service Port: `80`
   - Target Port: `80` (defaults to service port if omitted)
   - NodePort: **`30770`** (must be explicitly bound to port `30770` within range 30000–32767)
3. Ensure accessibility:
   - Accessible via `http://<Node-IP>:30770` on any cluster node
     (`kube-control-plane`, `kube-worker-1`, `kube-worker-2`).
   - Accessible internally via ClusterIP and CoreDNS (`my-web-app-service.default.svc.cluster.local:80`).

---

## 2. Fast CKA Exam Workflow (Imperative vs Declarative)

During the CKA exam, speed is vital. Candidates should not write YAML from scratch. The recommended workflow is:

### Step 1: Imperative Deployment Creation

```bash
kubectl create deployment my-web-app-deployment \
  --image=wordpress \
  --replicas=2
```

### Step 2: Imperative Service Scaffolding with NodePort Patch

`kubectl expose` does not support a `--node-port` flag directly. Candidates can scaffold the YAML with
`--dry-run=client -o yaml`, add `nodePort: 30770`, and apply:

```bash
kubectl expose deployment my-web-app-deployment \
  --name=my-web-app-service \
  --type=NodePort \
  --port=80 \
  --dry-run=client -o yaml > svc.yaml
```

Then add `nodePort: 30770` to `spec.ports[0]` in `svc.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-web-app-service
spec:
  type: NodePort
  selector:
    app: my-web-app-deployment
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30770
      protocol: TCP
```

Apply the service:

```bash
kubectl apply -f svc.yaml
```

### Alternative: Single-Line Imperative Expose + Patch

```bash
kubectl expose deployment my-web-app-deployment \
  --name=my-web-app-service \
  --type=NodePort \
  --port=80

kubectl patch svc my-web-app-service --type='json' -p='[
  {"op": "add", "path": "/spec/ports/0/nodePort", "value": 30770}
]'
```

---

## 3. Declarative Manifests

### 3.1 Deployment Manifest (`cka-lab-my-web-app-deployment.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-web-app-deployment
  namespace: {{ cka_lab_networking_namespace | default('default') }}
  labels:
    app: my-web-app-deployment
    app.kubernetes.io/name: my-web-app
    app.kubernetes.io/part-of: cka-lab
    cka.practice/scenario: networking
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-web-app-deployment
  template:
    metadata:
      labels:
        app: my-web-app-deployment
        app.kubernetes.io/name: my-web-app
    spec:
      containers:
        - name: wordpress
          image: wordpress:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
              name: http
          env:
            - name: WORDPRESS_DB_HOST
              value: "localhost:3306"
            - name: WORDPRESS_DB_USER
              value: "root"
            - name: WORDPRESS_DB_PASSWORD
              value: "placeholder"
```

> [!NOTE]
> WordPress without a MySQL database server still launches its Apache/PHP web server and returns an HTTP `200`
> or redirect `302` to `/wp-admin/install.php`, satisfying HTTP connectivity probes.

### 3.2 Service Manifest (`cka-lab-my-web-app-service.yaml`)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-web-app-service
  namespace: {{ cka_lab_networking_namespace | default('default') }}
  labels:
    app: my-web-app-service
    app.kubernetes.io/name: my-web-app
    app.kubernetes.io/part-of: cka-lab
    cka.practice/scenario: networking
spec:
  type: NodePort
  selector:
    app: my-web-app-deployment
  ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 30770
      protocol: TCP
```

---

## 4. Automated Verification Script (`test-my-web-app-service.sh`)

An automated Bash verification script to test:

1. **Deployment Rollout**: Asserts that `my-web-app-deployment` achieves `2/2` ready replicas within 120 seconds.
2. **EndpointSlice Verification**: Queries `kubectl get endpointslices -l kubernetes.io/service-name=my-web-app-service`
   to assert that 2 distinct Pod IP endpoints are registered and ready.
3. **NodePort Property Check**: Confirms `.spec.type == "NodePort"` and `.spec.ports[0].nodePort == 30770`.
4. **Internal ClusterIP & CoreDNS Test**: Launches an ephemeral `busybox` probe pod to query
   `http://my-web-app-service.${NAMESPACE}.svc.cluster.local:80`.
5. **Multi-Node NodePort Ingress**:
   - Queries `http://${NODE_IP}:30770` across cluster nodes (`kube-control-plane`, `kube-worker-1`, `kube-worker-2`).
   - Asserts HTTP response code is `200` or `302` (WordPress installer redirect).

---

## 5. File Layout & Integration Plan

### New Files to Create

| Source Template | Target Path in Lab (`~/cka/11-networking/`) | Purpose |
| --- | --- | --- |
| `networking_01_my_web_app_deployment.yaml.j2` | `01-services/cka-lab-my-web-app-deployment.yaml` | 2-replica WordPress deployment manifest |
| `networking_01_my_web_app_svc.yaml.j2` | `01-services/cka-lab-my-web-app-service.yaml` | NodePort service manifest with `nodePort: 30770` |
| `networking_01_my_web_app_test.sh.j2` | `01-services/test-my-web-app-service.sh` | Non-interactive automated test suite |
| `networking_01_my_web_app_exercise.md.j2` | `01-services/my-web-app-service-guide.md` | Student walkthrough guide & exam tips |

### Modifications to Existing Files

1. **`roles/cka_lab/tasks/scenario_networking.yml`**:
   Add template mappings for the 4 new files under `01-services/`.
2. **`roles/cka_lab/templates/networking_readme.md.j2`**:
   Add the new files to the directory tree and add a dedicated practice section for the NodePort WordPress drill.
3. **`roles/cka_lab/templates/networking_test_drills.sh.j2`**:
   Add cleanup entries for `my-web-app-deployment` and `my-web-app-service`, and execute `test-my-web-app-service.sh`
   as part of the master test suite.
4. **`k8s-homelab/CHANGELOG.md`**:
   Record the new scenario under `## [Unreleased]`.

---

## 6. Quality Gates & Validation Steps

1. `nix shell nixpkgs#markdownlint-cli2 --command markdownlint-cli2 <markdown_files>`
2. `python3 scripts/check-readme-line-length.py --all`
3. `shellcheck -s bash <scripts>`
4. `yamllint -c .yamllint <task_and_manifest_files>`
5. `make -C k8s-homelab cka-generate`
6. `nix shell nixpkgs#ansible-lint --command bash -c \`
   `"ANSIBLE_ROLES_PATH=k8s-homelab/roles ansible-lint -c k8s-homelab/.ansible-lint k8s-homelab/playbooks/site.yml"`

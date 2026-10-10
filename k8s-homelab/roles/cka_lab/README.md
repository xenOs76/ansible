# Ansible Role: `cka_lab`

Dedicated Ansible role for provisioning isolated hands-on Certified Kubernetes Administrator (CKA) exam training scenarios on the `k8s-homelab` preprod cluster.

## Design & Isolation

- **Targeted Execution**: Invoked exclusively by `make preprod-cka-lab` via `playbooks/cka_lab.yml`.
- **Environment Isolation**: Strictly excluded from standard deployment pipelines (`make preprod-deploy`, `playbooks/site.yml`) and never run against production environments.
- **Modular Scenarios**: Scenarios map directly to CKA curriculum domains (Security, Troubleshooting, Maintenance, Networking) and are managed in modular task files under `tasks/`.

## Scenarios

### Scenario 0: Initial Steps Reminder MOTD (`motd`)

- **Domain**: Exam Workflow & Orientation.
- **Objective**: Activate dynamic system MOTD reminder on `kube-control-plane` guiding trainees through manual preliminary setup steps:
  - Provisions `/home/vagrant/.motd` and registers system hook `/etc/update-motd.d/99-cka-training` (`0755`) for PAM SSH login display.
  - Reminds trainees to manually practice:
    1. Backup `~/.kube` directory.
    2. Check/configure autocompletion for `kubectl`.
    3. Check/configure bash alias `k`.
    4. Check/configure autocompletion for bash alias `k`.
    5. Check/configure safe deletion via `~/.kube/kuberc`.
  - Automatically deleted upon running full cluster deployment via `make preprod-deploy`.

### Scenario 1: User Authentication & RBAC (`user_rbac`)

- **Domain**: Security & RBAC.
- **Objective**: Create dedicated Kubernetes user authentication setups and minimal-permission contexts for RBAC authorization drills:
  1. **User `anna` Environment**:
     - Creates Linux user `anna` on `kube-control-plane` with membership in the `sudo` group and passwordless sudo privileges.
     - Creates visible certificate directory `/home/anna/certs` (`0755`).
     - Generates 2048-bit RSA private key (`anna.key`) and CSR (`anna.csr`) with Subject `/CN=anna/O=developers`.
     - Submits a Kubernetes `CertificateSigningRequest` (`certificates.k8s.io/v1`), approves it via `kubectl certificate approve`, and extracts the issued client certificate (`anna.crt`).
     - Assembles `/home/anna/.kube/config` with embedded client certificates and sets active context to `anna@kubernetes`.
  2. **Vagrant User Context Script (`create-user-context.sh`)**:
     - Based on the [bmuschko/cka-crash-course Exercise 04](https://github.com/bmuschko/cka-crash-course/blob/master/exercises/04-rbac/create-user-context.sh) pattern.
     - Provisions `/home/vagrant/cka/rbac/create-user-context.sh` (with convenience symlink at `/home/vagrant/cka/create-user-context.sh`).
     - Dynamically generates private key, submits and approves CSR, and registers credentials and context `vagrant` in the vagrant user's `~/.kube/config` with minimal permissions (zero initial RBAC roles bound).
     - Includes a step-by-step drill guide at `/home/vagrant/cka/rbac/README.md`.

### Scenario 2: Sample Secrets across Namespaces (`secrets`)

- **Domain**: Configuration & Security.

- **Reference**: [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- **Objective**: Ensure the `development` namespace exists and provision sample Secrets representing distinct built-in Kubernetes types across both `default` and `development` namespaces:
  - **`default` Namespace Secrets**:
    1. `sample-app-secret` (`type: Opaque`): Generic application credentials (`username`, `password`, `database-url`, `api-key`).
    2. `sample-basic-auth` (`type: kubernetes.io/basic-auth`): Basic HTTP authentication credentials (`username`, `password`).
    3. `sample-tls-secret` (`type: kubernetes.io/tls`): 2048-bit RSA TLS server certificate (`tls.crt`) and private key (`tls.key`).
    4. `sample-ssh-auth` (`type: kubernetes.io/ssh-auth`): Ed25519 SSH private key (`ssh-privatekey`) for remote authentication.
  - **`development` Namespace Secrets**:
    1. `dev-app-secret` (`type: Opaque`): Development credentials with additional JWT signing key (`username`, `password`, `database-url`, `api-key`, `jwt-secret`).
    2. `dev-basic-auth` (`type: kubernetes.io/basic-auth`): Development service basic authentication credentials.
    3. `dev-tls-secret` (`type: kubernetes.io/tls`): Dedicated development TLS certificate and private key (`tls.crt`, `tls.key`).
    4. `dev-ssh-auth` (`type: kubernetes.io/ssh-auth`): Dedicated development deployment SSH key (`ssh-privatekey`).
- **Artifacts**: Rendered YAML manifest is persisted at `/home/vagrant/cka/secrets/sample-secrets.yaml`.

### Scenario 3: Sample ConfigMaps & Kustomize Practice (`configmaps`)

- **Domain**: Configuration & Kustomize.
- **Reference**: [Kubernetes ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- **Objective**: Provision sample ConfigMaps dynamically generated via Jinja2 templates across both `default` and `development` namespaces, and set up a hands-on Kustomize customization lab:
  - **`default` Namespace ConfigMaps**:
    1. `sample-app-config`: Property-like key-value environment pairs (`APP_ENV`, `LOG_LEVEL`, `MAX_CONNECTIONS`, `FEATURE_FLAG_ANALYTICS`, `SERVER_PORT`).
    2. `sample-service-config`: File-like configuration data embedding complete configuration files (`application.properties` and `nginx.conf`).
    3. `sample-system-config`: An immutable ConfigMap (`immutable: true`) protecting baseline cluster settings from modification and reducing API server watch overhead.
  - **`development` Namespace ConfigMaps**:
    1. `dev-app-config`: Development environment configuration with debugging flags and local port settings.
    2. `dev-service-config`: Development configuration files embedding `application-dev.properties` and `nginx-dev.conf`.
    3. `dev-system-config`: Development immutable ConfigMap (`immutable: true`) defining sandbox baseline endpoints.
  - **Kustomize Practice Environment**:
    - `kustomize/base/`: Base deployment, service, and `webapp-config` ConfigMap.
    - `kustomize/overlays/development/`: ConfigMapGenerator with `behavior: merge`, file sources (`dev-settings.properties`), and resource patch.
    - `kustomize/overlays/production/`: ConfigMapGenerator with production literals and strategic merge patch for replicas.
- **Artifacts**:
  - Combined manifest: `/home/vagrant/cka/configmaps/sample-configmaps.yaml`
  - Individual ConfigMap files: `/home/vagrant/cka/configmaps/default/` and `/home/vagrant/cka/configmaps/development/`
  - Kustomize directory: `/home/vagrant/cka/kustomize/`

### Scenario 4: Helm Tools, Monitoring & Gateway API (`helm`)

- **Domain**: Cluster Architecture, Installation & Configuration.
- **Reference**: [Helm Documentation](https://helm.sh/docs/), [Prometheus Community Helm Charts](https://github.com/prometheus-community/helm-charts), [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) & [estahn/httpbingo Chart](https://github.com/estahn/charts/tree/main/charts/httpbingo)
- **Objective**: Provision standalone Helm deployment scripts for hands-on cluster addon management, monitoring, and Gateway API:
  1. `install-kube-metrics.sh`: Deploys Kubernetes Metrics Server with `--kubelet-insecure-tls` enabling `kubectl top nodes` and `kubectl top pods`.
  1. `install-kube-prometheus.sh`: Deploys the Prometheus Operator (`kube-prometheus-stack`) configured with Prometheus ONLY (Alertmanager, Grafana, node-exporter, and kube-state-metrics disabled) for minimal resource footprint on lab VMs.
  1. `install-nginx-gateway-fabric.sh`: Deploys NGINX Gateway Fabric via the official OCI Helm chart (`oci://ghcr.io/nginx/charts/nginx-gateway-fabric`) along with required Kubernetes Gateway API CRDs (`gatewayclasses`, `gateways`, `httproutes`).
  1. `install-httpbin-go.sh`: Deploys `go-httpbin` (`mccutchen/go-httpbin`) via `estahn/httpbingo` with minimal resource footprint (10m CPU / 16Mi RAM) as a lightweight HTTP echo target for Gateway API and Ingress routing drills.
- **Artifacts**:
  - Helm scripts and guide directory: `/home/vagrant/cka/helm/`
  - Installer scripts: `install-kube-metrics.sh`, `install-kube-prometheus.sh`, `install-nginx-gateway-fabric.sh`, and `install-httpbin-go.sh`
  - Practice guide: `/home/vagrant/cka/helm/README.md`

### Scenario 5: NFS Server & Storage Volumes Practice (`volumes`)

- **Domain**: Storage & Volume Management.
- **Objective**: Leverage the cluster NFS server (provisioned by `roles/nfs_server` during `make preprod-up`, exporting `/exports` with `nfs-server.local` mapped across nodes) to scaffold comprehensive CKA volume drills and sample dataset files under `/home/vagrant/cka/volumes/`:
  1. **NFS Shared Storage (`01-nfs/`)**:
     - Direct inline NFS Pod volume mount (`01-nfs-direct-pod.yaml`) referencing `server: nfs-server.local`.
     - Multi-replica Deployment demonstrating shared read/write (`ReadWriteMany`) across worker nodes (`02-nfs-deployment-shared.yaml`).
     - PersistentVolume (`03-nfs-pv.yaml`) and PersistentVolumeClaim (`04-nfs-pvc.yaml`) binding with consumer Pod (`05-nfs-pvc-pod.yaml`).
  2. **Ephemeral Volumes (`02-emptydir/`)**:
     - Multi-container sidecar data sharing via `emptyDir: {}` (`01-emptydir-sidecar-pod.yaml`).
     - In-memory tmpfs volume with `medium: Memory` and `sizeLimit: 64Mi` (`02-emptydir-memory-pod.yaml`).
  3. **Node Filesystem Volumes (`03-hostpath/`)**:
     - `hostPath` mount with `type: DirectoryOrCreate` (`01-hostpath-pod.yaml`).
     - Read-only inspection of node `/var/log` (`02-hostpath-log-viewer.yaml`).
  4. **ConfigMap & Secret Volumes (`04-configmap-secret/`)**:
     - ConfigMap mounted as volume files with specific items and `0644` permissions (`01-configmap-volume-pod.yaml`).
     - Secret mounted as files with restricted permissions (`defaultMode: 0400`) (`02-secret-volume-pod.yaml`).
  5. **PV/PVC Lifecycle & Expansion (`05-pv-pvc-lifecycle/`)**:
     - Local manual PV binding with `Retain` reclaim policy (`01-local-pv-pvc.yaml`).
     - PVC online volume expansion drill (`02-pvc-expansion.yaml`).
     - Reclaim policy step-by-step drill guide (`03-reclaim-policy-drill.md`).
  6. **Ceph RBD Block Storage (`06-rbd/`)**:
     - Dynamic Ceph RBD PVC and consumer Pod with ext4 filesystem (`01-rbd-dynamic-filesystem.yaml`).
     - Raw block volume with `volumeMode: Block` and `volumeDevices` (`02-rbd-raw-block.yaml`).
     - Static Ceph CSI PV, PVC, and consumer Pod binding (`03-rbd-static-pv-pvc-pod.yaml`).
     - Live online PVC volume expansion drill (`04-rbd-pvc-expansion.yaml`).
     - Dedicated test suite: `test-rbd-volumes.sh`.
  7. **iSCSI Block Storage (`07-iscsi/`)**:
     - Direct inline iSCSI Pod volume mount (`01-iscsi-direct-pod.yaml`).
     - Static PersistentVolume and PersistentVolumeClaim binding with consumer Pod (`02-iscsi-pv-pvc-pod.yaml`).
     - Raw block volume with `volumeMode: Block` and `volumeDevices` (`03-iscsi-raw-block.yaml`).
     - ReadWriteOnce multi-node single-writer conflict demonstration (`04-iscsi-two-nodes-rwo.yaml`).
     - Authenticated iSCSI with CHAP credentials Secret (`05-iscsi-chap-secret.yaml`).
     - Dedicated test suite: `test-iscsi-volumes.sh`.
- **Artifacts**:
  - Volume practice directory: `/home/vagrant/cka/volumes/`
  - Automated verification test scripts: `/home/vagrant/cka/volumes/test-nfs-mounts.sh`, `06-rbd/test-rbd-volumes.sh`, and `07-iscsi/test-iscsi-volumes.sh`
  - Practice guide: `/home/vagrant/cka/volumes/README.md`, `06-rbd/README.md`, and `07-iscsi/README.md`

### Scenario 6: Deployments, ReplicaSets & Rollouts Practice (`deployments`)

- **Domain**: Workloads & Scheduling.
- **Reference**: [Kubernetes Deployments Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- **Objective**: Practice declarative and imperative deployment lifecycle management, rolling updates, rollbacks, history tracking, label selector troubleshooting, and deployment strategies:
  1. **Deployment Basics (`01-basic-deployment/`)**:
     - `web-frontend-deployment.yaml`: Production reverse-proxy deployment with 3 replicas, resource requests, and environment variables.
     - `api-service-deployment.yaml`: Background microservice deployment with custom command loop.
  2. **Label Selector Troubleshooting (`02-troubleshooting-labels/`)**:
     - `broken-deployment.yaml`: Broken manifest with mismatched `spec.selector.matchLabels` (`env: staging`) vs `spec.template.metadata.labels` (`env: production`) for diagnostic practice.
     - `fixed-deployment.yaml`: Corrected matching manifest.
     - `README.md`: Error inspection, ReplicaSet selector mechanics, and immutability rules.
  3. **Rolling Updates & Rollbacks (`03-rolling-updates-rollbacks/`)**:
     - `01-catalog-v1.yaml` (`nginx:1.24-alpine`) & `02-catalog-v2.yaml` (`nginx:1.25-alpine`).
     - `rollout-drill.sh`: Interactive walkthrough demonstrating `rollout status`, revision history inspection, change-cause annotations, and rollbacks via `rollout undo --to-revision`.
  4. **Deployment Strategies (`04-strategies/`)**:
     - `rolling-update-custom.yaml`: Zero-downtime RollingUpdate with discrete integers (`maxSurge: 1`, `maxUnavailable: 0`).
     - `rolling-update-percent.yaml`: Percentage-based RollingUpdate (`maxSurge: 50%`, `maxUnavailable: 25%`).
     - `recreate-strategy.yaml`: Recreate strategy for singleton workers requiring complete container teardown prior to launch.
  5. **Pausing and Resuming Rollouts (`05-pause-resume/`)**:
     - `batch-change-deployment.yaml` & `pause-resume-drill.sh`: Demonstrating batch updates (image, environment variables, resource limits) while paused, followed by single-revision resume.
- **Artifacts**:
  - Deployments drill directory: `/home/vagrant/cka/deployments/`
  - Automated test suite: `/home/vagrant/cka/deployments/test-deployments-drills.sh`
  - Master practice guide: `/home/vagrant/cka/deployments/README.md`

### Scenario 7: Pods, Lifecycle & Namespaces Practice (`pods`)

- **Domain**: Workloads & Scheduling.
- **Reference**: [Kubernetes Pods Documentation](https://kubernetes.io/docs/concepts/workloads/pods/).
- **Objective**: Practice imperative and declarative Pod management, command and argument overrides, lifecycle phase and container state diagnostics, observability (logs and exec), ephemeral network probing, spec immutability workflows, and namespace context preferences:
  1. **Imperative & Declarative Pods (`01-imperative-declarative/`)**:
     - `run-imperative.sh`: Command reference for generating and executing Pods using `kubectl run` with flags (`--image`, `--port`, `--env`, `--labels`, `--restart`, `--dry-run=client -o yaml`).
     - `cka-lab-web-service-pod.yaml`: Declarative Nginx web server manifest with container ports and environment variables.
     - `cka-lab-batch-task-pod.yaml`: Declarative batch processing task overriding container `command` and `args`.
  2. **Lifecycle Phases & Restart Policies (`02-lifecycle-and-restarts/`)**:
     - `cka-lab-finite-worker-pod.yaml`: Finite task with `restartPolicy: Never` demonstrating successful transition to `Succeeded` (Completed).
     - `cka-lab-failing-worker-pod.yaml`: Non-zero exit task with `restartPolicy: OnFailure` demonstrating `CrashLoopBackOff`.
     - `README.md`: In-depth breakdown of Pod phases (`Pending`, `Running`, `Succeeded`, `Failed`) versus container states (`Waiting`, `Running`, `Terminated`).
  3. **Observability & Diagnostics (`03-observability-exec/`)**:
     - `cka-lab-telemetry-pod.yaml`: Structured log emitter utilizing downward API for node name injection.
     - `debug-drill.sh`: Interactive drill demonstrating log retrieval, log tailing, container environment inspection, and process table auditing via `kubectl exec`.
  4. **Ephemeral Networking Diagnostics (`04-ephemeral-networking/`)**:
     - `cka-lab-echo-server-pod.yaml`: Internal HTTP service target.
     - `test-connectivity.sh`: Launches temporary ephemeral Pod (`--rm -it --restart=Never`) to probe cluster IP reachability via `wget`.
  5. **Pod Spec Immutability (`05-spec-immutability/`)**:
     - `cka-lab-immutable-app-v1.yaml` & `cka-lab-immutable-app-v2.yaml`: Versioned manifests for demonstrating mutation restrictions.
     - `replace-drill.sh`: Walkthrough demonstrating admission rejection on live spec modifications and force replacement via `kubectl replace --force`.
  6. **Namespaces & Context Preferences (`06-namespaces-context/`)**:
     - `cka-lab-namespace.yaml`: Declarative staging namespace (`cka-lab-staging`).
     - `namespace-context-drill.sh`: Interactive drill for binding active kubeconfig context namespace preference and demonstrating cascading resource deletion.
- **Artifacts**:
  - Pods drill directory: `/home/vagrant/cka/pods/`
  - Automated test suite: `/home/vagrant/cka/pods/test-pods-drills.sh`
  - Master practice guide: `/home/vagrant/cka/pods/README.md`

### Scenario 8: Services, Ingress, Gateway API & Network Policies (`networking`)

- **Domain**: Services & Networking.
- **Reference**: [Kubernetes Services & Networking Documentation](https://kubernetes.io/docs/concepts/services-networking/).
- **Objective**: Comprehensive training across core Kubernetes networking abstractions, edge routing, and pod-to-pod microsegmentation:
  1. **Services & CoreDNS (`01-services/`)**:
     - `cka-lab-backend-app.yaml`: Multi-port microservice deployment exposing HTTP (port 80) and metrics (port 8080).
     - `cka-lab-clusterip-service.yaml`: ClusterIP service providing stable virtual IP and CoreDNS name discovery (`cka-lab-clusterip-svc.default.svc.cluster.local`).
     - `cka-lab-nodeport-service.yaml`: Multi-port NodePort service exposing port 80 on NodePort 31080 and port 8080 on NodePort 31090.
     - `test-services.sh`: Non-interactive script verifying endpoint registration, DNS resolution, and NodePort access.
  2. **Ingresses (`02-ingresses/`)**:
     - `cka-lab-ingress-backends.yaml`: Independent web and API backend deployments and ClusterIP services.
     - `cka-lab-ingress.yaml`: Ingress resource routing host `cka-lab.example.local` with path prefixes `/web` and `/api` using `ingressClassName: nginx`.
     - `test-ingress.sh`: Non-interactive curl verification script testing Host header path routing.
  3. **Gateway API & Caddy Integration (`03-gateway-api/`)**:
     - `cka-lab-gateway.yaml`: Gateway resource implementing Gateway API standard CRDs with listeners on port 80 and port 443.
     - `cka-lab-httproute.yaml`: HTTPRoute resource attaching to `cka-lab-gateway`, routing `/api` and `/httpbin` (with URLRewrite prefix stripping) to backend services.
     - `cka-lab-caddy-integration.md`: Architecture guide documenting edge TLS termination on Caddy (port 443) and upstream reverse proxying to NGINX Gateway Fabric NodePort 30443.
     - `test-gateway.sh`: Non-interactive script testing Gateway status and HTTPRoute path evaluation.
  4. **Network Policies (`04-network-policies/`)**:
     - `cka-lab-namespaces.yaml`: Isolated namespaces `cka-lab-net-client` and `cka-lab-net-backend`.
     - `cka-lab-backend-workload.yaml`: Target backend microservice (`httpbin-go`).
     - `cka-lab-client-workloads.yaml`: Authorized (`access: authorized`) and unauthorized (`access: unauthorized`) client pods.
     - `cka-lab-default-deny-ingress.yaml`: Default-deny ingress isolation policy.
     - `cka-lab-allow-client-to-backend.yaml`: Ingress policy permitting traffic only from authorized client pods.
     - `cka-lab-egress-dns-policy.yaml`: Egress policy allowing CoreDNS (UDP/TCP 53) and backend access.
     - `test-network-policies.sh`: Non-interactive script verifying permitted traffic vs connection timeouts when dropped.
- **Artifacts**:
  - Networking drill directory: `/home/vagrant/cka/networking/`
  - Automated test suite: `/home/vagrant/cka/networking/test-networking-drills.sh`
  - Master practice guide: `/home/vagrant/cka/networking/README.md`

### Scenario 9: Advanced Scheduling & Capacity Management (`scheduling`)

- **Domain**: Workloads & Scheduling.
- **Reference**: [Kubernetes Scheduling Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/).
- **Objective**: Master node scheduling constraints, pod spreading, autoscaling, and namespace capacity governance:
  1. **Taints & Tolerations (`01-taints-tolerations/`)**: Applying and removing `NoSchedule` taints to nodes and configuring matching pod tolerations.
  2. **Affinities & Anti-Affinities (`02-affinities/`)**: Hard and soft `nodeAffinity` placement rules, and multi-replica hostname spreading via `podAntiAffinity`.
  3. **Horizontal Pod Autoscaling (`03-hpa-autoscaling/`)**: Dynamic pod replica autoscaling using `autoscaling/v2` based on target CPU utilization.
  4. **Capacity Governance (`04-quotas-limits/`)**: Namespace boundary enforcement using `ResourceQuota` and default limit/request injection via `LimitRange`.
- **Artifacts**:
  - Scheduling drill directory: `/home/vagrant/cka/scheduling/`
  - Automated test suite: `/home/vagrant/cka/scheduling/test-scheduling-drills.sh`
  - Master practice guide: `/home/vagrant/cka/scheduling/README.md`

### Scenario 10: Specialized Workload Controllers & Multi-Container Pods (`workloads_advanced`)

- **Domain**: Workloads & Scheduling.
- **Reference**: [Kubernetes Workloads Documentation](https://kubernetes.io/docs/concepts/workloads/).
- **Objective**: Deploy and maintain background node daemons, batch workloads, and coordinated multi-container pods:
  1. **DaemonSets (`01-daemonsets/`)**: Deploying node agents across all cluster nodes with control plane tolerations and hostPath inspection.
  2. **Batch Jobs & CronJobs (`02-batch-jobs/`)**: Parallel batch jobs (`completions`, `parallelism`) and scheduled CronJobs (`concurrencyPolicy: Forbid`).
  3. **Multi-Container Pods (`03-multi-container/`)**: Gated sequential initialization via `initContainers`, and native persistent helper execution via Kubernetes 1.28+ native sidecar containers (`restartPolicy: Always`).
- **Artifacts**:
  - Workloads drill directory: `/home/vagrant/cka/workloads-advanced/`
  - Automated test suite: `/home/vagrant/cka/workloads-advanced/test-workloads-advanced-drills.sh`
  - Master practice guide: `/home/vagrant/cka/workloads-advanced/README.md`

### Scenario 11: Dynamic Provisioning & StorageClasses (`storage_classes`)

- **Domain**: Storage.
- **Reference**: [Kubernetes Storage Documentation](https://kubernetes.io/docs/concepts/storage/).
- **Objective**: Configure dynamic storage provisioners, customize StorageClass operational parameters, and manage dynamic volume lifecycles:
  1. **Dynamic Provisioners (`01-provisioners/`)**: Deploying Rancher's lightweight `local-path-provisioner`.
  2. **StorageClass Lifecycle (`02-storage-classes/`)**: Configuring `reclaimPolicy` (`Delete` vs `Retain`), delayed binding (`volumeBindingMode: WaitForFirstConsumer`), dynamic PVC binding upon first pod consumer, and PVC volume expansion.
- **Artifacts**:
  - StorageClasses drill directory: `/home/vagrant/cka/storage-classes/`
  - Automated test suite: `/home/vagrant/cka/storage-classes/test-storage-classes-drills.sh`
  - Master practice guide: `/home/vagrant/cka/storage-classes/README.md`

### Scenario 12: Cluster Maintenance & Node Troubleshooting (`cluster_troubleshooting`)

- **Domain**: Troubleshooting.
- **Reference**: [Kubernetes Troubleshooting Documentation](https://kubernetes.io/docs/tasks/debug/).
- **Objective**: Execute safe cluster node maintenance workflows, recover failing control plane static pods, and inspect resource telemetry:
  1. **Node Maintenance (`01-node-maintenance/`)**: Non-interactive node cordoning (`kubectl cordon`), workload eviction (`kubectl drain --ignore-daemonsets --delete-emptydir-data`), and return to service (`kubectl uncordon`).
  2. **Static Pod Break-Fix (`02-static-pod-recovery/`)**: Diagnosing and repairing corrupted control plane manifests in `/etc/kubernetes/manifests/` using `crictl` and system logs.
  3. **Kubelet Diagnostics (`03-kubelet-diagnostics/`)**: Troubleshooting worker node systemd `kubelet.service` failures and configuration syntax errors.
  4. **Resource Telemetry (`04-metrics-monitoring/`)**: Live node and pod CPU/memory consumption inspection using `kubectl top nodes` and `kubectl top pods`.
- **Artifacts**:
  - Troubleshooting drill directory: `/home/vagrant/cka/cluster-troubleshooting/`
  - Automated test suite: `/home/vagrant/cka/cluster-troubleshooting/test-cluster-troubleshooting.sh`
  - Master practice guide: `/home/vagrant/cka/cluster-troubleshooting/README.md`

### Scenario 13: Custom Resource Definitions & Operators (`crds`)

- **Domain**: Cluster Architecture, Installation & Configuration.
- **Reference**: [Kubernetes Extend API Documentation](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/).
- **Objective**: Define custom API schemas with OpenAPI v3 validation and manage custom resource lifecycles:
  1. **CRD Specification (`01-crd-schema/`)**: Declaring group, version, kind, shortNames, additional printer columns, and OpenAPI v3 structural validation rules.
  2. **Custom Resource Lifecycle**: Creating declarative instances and testing admission webhook rejection on malformed specifications.
- **Artifacts**:
  - CRD drill directory: `/home/vagrant/cka/crds-operators/`
  - Automated test suite: `/home/vagrant/cka/crds-operators/test-crds-drills.sh`
  - Master practice guide: `/home/vagrant/cka/crds-operators/README.md`

### Scenario 14: Chaos Engineering & Dynamic Troubleshooting (`chaos_troubleshooting`)

- **Domain**: Troubleshooting & Resilience.
- **Reference**: [LitmusChaos Documentation](https://litmuschaos.io/).
- **Objective**: On-demand runtime fault injection using Headless LitmusChaos to simulate live service failures:
  1. **Memory OOM Drill (`01-memory-oom`)**: Simulates container memory exhaustion (`pod-memory-hog`), inspecting `OOMKilled` (ExitCode 137), and adjusting resource limits.
  2. **Network Degradation Drill (`02-network-latency`)**: Injects 70% packet loss (`pod-network-loss`) to troubleshoot timeouts using ephemeral debug containers (`kubectl debug`).
  3. **CoreDNS Blackhole Drill (`03-dns-chaos`)**: Disrupts inter-service DNS lookups (`pod-dns-error`) to diagnose resolution paths.
  4. **Node MemoryPressure Drill (`04-node-pressure`)**: Induces node memory saturation (`node-memory-hog`) to examine node conditions and QoS pod eviction priorities.
- **Artifacts**:
  - Chaos drill directory: `/home/vagrant/cka/chaos-troubleshooting/`
  - Automated verification test suite: `/home/vagrant/cka/chaos-troubleshooting/test-chaos-drills.sh`
  - Master practice guide: `/home/vagrant/cka/chaos-troubleshooting/README.md`

## Verification inside Control Plane

### Verify RBAC Scenario

```bash
# SSH into control plane VM
./scripts/shell.sh --run "vagrant ssh kube-control-plane"

# Option A: Run Vagrant User Minimal Context Drill (Exercise 04)
cd ~/cka/rbac
./create-user-context.sh

# Switch to the new minimal-permission context
kubectl config use-context vagrant

# Verify forbidden permissions (expected: no)
kubectl get pods
kubectl auth can-i get pods

# Switch back to cluster administrator
kubectl config use-context kubernetes-admin@kubernetes

# Option B: Switch to trainee user 'anna'
sudo su - anna

# Inspect credentials and context
kubectl config get-contexts
kubectl config current-context

# Test authorization (expected: forbidden until trainee binds roles)
kubectl auth can-i create pods
kubectl get pods
```

### Verify Secrets Scenario

```bash

# List secrets in both namespaces
kubectl get secrets -n default
kubectl get secrets -n development

# Inspect details and keys of sample secrets in default namespace
kubectl describe secret sample-app-secret -n default
kubectl describe secret sample-basic-auth -n default
kubectl describe secret sample-tls-secret -n default
kubectl describe secret sample-ssh-auth -n default

# Inspect details and keys of sample secrets in development namespace
kubectl describe secret dev-app-secret -n development
kubectl describe secret dev-basic-auth -n development
kubectl describe secret dev-tls-secret -n development
kubectl describe secret dev-ssh-auth -n development

# Decode and compare secret values
kubectl get secret sample-app-secret -n default -o jsonpath='{.data.password}' | base64 -d
echo ""
kubectl get secret dev-app-secret -n development -o jsonpath='{.data.password}' | base64 -d
echo ""
```

### Verify ConfigMaps Scenario

```bash
# List configmaps in both namespaces
kubectl get configmap -n default
kubectl get configmap -n development

# Inspect individual YAML files copied to vagrant home
ls -la /home/vagrant/cka/configmaps/default/
ls -la /home/vagrant/cka/configmaps/development/

# Inspect key-value properties and embedded config files
kubectl describe configmap sample-app-config -n default
kubectl describe configmap sample-service-config -n default
kubectl describe configmap sample-system-config -n default

# Inspect development configmaps
kubectl describe configmap dev-app-config -n development
kubectl describe configmap dev-service-config -n development
kubectl describe configmap dev-system-config -n development
```

### Verify Kustomize Customizations

```bash
# Change to the Kustomize drill directory
cd /home/vagrant/cka/kustomize

# Preview the base resources
kubectl kustomize base

# Preview development overlay (observe: namespace=development, namePrefix=dev-, merged configmap)
kubectl kustomize overlays/development

# Preview production overlay (observe: 3 replicas, prod- prefix, production settings)
kubectl kustomize overlays/production

# Test applying development overlay
kubectl apply -k overlays/development
kubectl get all,configmap -n development -l environment=development

# Clean up overlay test
kubectl delete -k overlays/development
```

### Verify Helm Scenarios

```bash
# Change to the Helm drill directory
cd /home/vagrant/cka/helm

# Deploy Kubernetes Metrics Server
./install-kube-metrics.sh
kubectl top nodes

# Deploy Minimal Prometheus Operator (Prometheus only)
./install-kube-prometheus.sh
kubectl get pods,svc -n monitoring
kubectl get prometheus -n monitoring

# Deploy NGINX Gateway Fabric (Gateway API)
./install-nginx-gateway-fabric.sh
kubectl get pods,svc -n nginx-gateway
kubectl get gatewayclasses
curl -I http://192.168.56.20:30080/

# Deploy Lightweight httpbin-go (Target Backend)
./install-httpbin-go.sh
kubectl get pods,svc -l app.kubernetes.io/instance=httpbingo
kubectl run test-curl --rm -i --restart=Never --image=curlimages/curl:latest -- http://httpbingo.default.svc.cluster.local/get
```

### Verify Volumes Scenario

```bash
# Verify DNS / host mapping across cluster
ping -c 1 nfs-server.local

# Check NFS server status on control plane
sudo exportfs -v
showmount -e nfs-server.local

# Run automated validation script
cd /home/vagrant/cka/volumes
./test-nfs-mounts.sh

# Test inline NFS Pod
kubectl apply -f 01-nfs/01-nfs-direct-pod.yaml
kubectl get pod nfs-direct-pod
kubectl exec nfs-direct-pod -- cat /mnt/nfs/shared-data.txt

# Test static PV / PVC binding
kubectl apply -f 01-nfs/03-nfs-pv.yaml
kubectl apply -f 01-nfs/04-nfs-pvc.yaml
kubectl get pv nfs-storage-pv
kubectl get pvc nfs-storage-pvc

# Run automated Ceph RBD test suite
06-rbd/test-rbd-volumes.sh

# Run automated iSCSI test suite
07-iscsi/test-iscsi-volumes.sh
```

### Verify Deployments Scenario

```bash
# Change to the deployments drill directory
cd /home/vagrant/cka/deployments

# Run automated validation test suite
./test-deployments-drills.sh

# Run interactive rolling update drill
cd 03-rolling-updates-rollbacks
./rollout-drill.sh
```

### Verify Pods Scenario

```bash
# Change to the pods drill directory
cd /home/vagrant/cka/pods

# Run automated validation test suite
./test-pods-drills.sh

# Run individual drill scripts
cd 01-imperative-declarative && ./run-imperative.sh
cd ../03-observability-exec && ./debug-drill.sh
cd ../04-ephemeral-networking && ./test-connectivity.sh
cd ../05-spec-immutability && ./replace-drill.sh
cd ../06-namespaces-context && ./namespace-context-drill.sh
```

### Verify Networking Scenarios

```bash
# Change to the networking drill directory
cd /home/vagrant/cka/networking

# Run automated validation test suite
./test-networking-drills.sh

# Run individual drill tests
./01-services/test-services.sh
./02-ingresses/test-ingress.sh
./03-gateway-api/test-gateway.sh
./04-network-policies/test-network-policies.sh
```

### Verify Scheduling Scenario

```bash
cd /home/vagrant/cka/scheduling
./test-scheduling-drills.sh
```

### Verify Workloads Advanced Scenario

```bash
cd /home/vagrant/cka/workloads-advanced
./test-workloads-advanced-drills.sh
```

### Verify StorageClasses Scenario

```bash
cd /home/vagrant/cka/storage-classes
./test-storage-classes-drills.sh
```

### Verify Cluster Troubleshooting Scenario

```bash
cd /home/vagrant/cka/cluster-troubleshooting
./test-cluster-troubleshooting.sh
```

### Verify Custom Resource Definitions Scenario

```bash
cd /home/vagrant/cka/crds-operators
./test-crds-drills.sh
```

### Verify Chaos Troubleshooting Scenario

```bash
cd /home/vagrant/cka/chaos-troubleshooting
./test-chaos-drills.sh
```

# Ansible Role: `cka_lab`

Dedicated Ansible role for provisioning isolated hands-on Certified Kubernetes Administrator (CKA) exam training scenarios on the `k8s-homelab` preprod cluster.

## Design & Isolation

- **Targeted Execution**: Invoked exclusively by `make preprod-cka-lab` via `playbooks/cka_lab.yml`.
- **Environment Isolation**: Strictly excluded from standard deployment pipelines (`make preprod-deploy`, `playbooks/site.yml`) and never run against production environments.
- **Modular Scenarios**: Scenarios map directly to CKA curriculum domains (Security, Troubleshooting, Maintenance, Networking) and are managed in modular task files under `tasks/`.

## Official CKA Exam Allowed Resources & Navigation Guidelines

Under official Linux Foundation / CNCF candidate policies, candidates may access specific documentation resources within the exam environment browser:

1. **Permitted Web Resources**:
   - **Kubernetes Documentation**: [https://kubernetes.io/docs/](https://kubernetes.io/docs/) (official docs, cheatsheet, API reference, tutorials).
   - **Kubernetes Blog**: [https://kubernetes.io/blog/](https://kubernetes.io/blog/).
   - **Helm Documentation**: [https://helm.sh/docs/](https://helm.sh/docs/).
   - **Gateway API Documentation (CKA only)**: [https://gateway-api.sigs.k8s.io/](https://gateway-api.sigs.k8s.io/).
   - **Task-Specific Documentation**: Direct links provided inside the question's Quick Reference box.
2. **Search Policy**:
   - Built-in search on allowed websites is permitted.
   - External search engines (Google, Bing) and navigating away to unapproved third-party domains (e.g., StackOverflow, general GitHub issues) are **strictly prohibited** and trigger immediate exam invalidation.
3. **Terminal Fast Aids**:
   - `kubectl explain <resource>.<field>`: Fast offline schema discovery directly in your shell.
   - CLI help: `kubectl --help`, `kubeadm --help`, `crictl --help`, `etcdctl --help`.
   - Local documentation: `/usr/share/doc/` and system `man` pages.
4. **Homelab Auxiliary vs. Exam Primitives**:
   - The lab incorporates supplementary homelab tools (LitmusChaos, Caddy edge router, Ceph RBD, iSCSI). While valuable for practical learning, their documentation is **not** accessible during the actual exam. Scenarios note `[EXAM ALLOWED]` vs `[HOMELAB AUXILIARY]` so trainees cultivate exam-compliant reflexes.

## Scenarios

### Scenario 0: Initial Steps Reminder MOTD (`motd`)

- **Domain**: Exam Workflow & Orientation.
- **Exam References & Permitted Documentation**:
  - [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/) `[EXAM ALLOWED]`
  - [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"kubectl cheat sheet"`, `"bash autocomplete"`, `"kubeconfig"`
- **Fast Terminal Lookups**:

  ```bash
  source <(kubectl completion bash)
  complete -o default -F __start_kubectl k
  ```

- **Objective**: Activate dynamic system MOTD reminder on `kube-control-plane` guiding trainees through manual preliminary setup steps:
  - Provisions `/home/vagrant/.motd` and registers system hook `/etc/update-motd.d/99-cka-training` (`0755`) for PAM SSH login display.
  - Reminds trainees to manually practice:
    1. Backup `~/.kube` directory.
    1. Check/configure autocompletion for `kubectl`.
    1. Check/configure bash alias `k`.
    1. Check/configure autocompletion for bash alias `k`.
    1. Check/configure safe deletion via `~/.kube/kuberc`.
  - Automatically deleted upon running full cluster deployment via `make preprod-deploy`.

### Scenario 1: User Authentication & RBAC (`user_rbac`)

- **Domain**: Security & RBAC (25%).
- **Exam References & Permitted Documentation**:
  - [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) `[EXAM ALLOWED]`
  - [CertificateSigningRequests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/) `[EXAM ALLOWED]`
  - [Managing Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"using rbac authorization"`, `"certificate signing request"`, `"service account token"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl explain role.rules
  kubectl explain clusterrolebinding.subjects
  kubectl create role developer --verb=create,get,list --resource=pods --dry-run=client -o yaml
  kubectl create rolebinding dev-binding --role=developer --user=anna --dry-run=client -o yaml
  ```

- **Objective**: Create dedicated Kubernetes user authentication setups and minimal-permission contexts for RBAC authorization drills:
  1. **User `anna` Environment**:
     - Creates Linux user `anna` on `kube-control-plane` with membership in the `sudo` group and passwordless sudo privileges.
     - Creates visible certificate directory `/home/anna/certs` (`0755`).
     - Generates 2048-bit RSA private key (`anna.key`) and CSR (`anna.csr`) with Subject `/CN=anna/O=developers`.
     - Submits a Kubernetes `CertificateSigningRequest` (`certificates.k8s.io/v1`), approves it via `kubectl certificate approve`, and extracts the issued client certificate (`anna.crt`).
     - Assembles `/home/anna/.kube/config` with embedded client certificates and sets active context to `anna@kubernetes`.
  1. **Vagrant User Context Script (`create-user-context.sh`)**:
     - Based on the [bmuschko/cka-crash-course Exercise 04](https://github.com/bmuschko/cka-crash-course/blob/master/exercises/04-rbac/create-user-context.sh) pattern.
     - Provisions `/home/vagrant/cka/rbac/create-user-context.sh` (with convenience symlink at `/home/vagrant/cka/create-user-context.sh`).
     - Dynamically generates private key, submits and approves CSR, and registers credentials and context `vagrant` in the vagrant user's `~/.kube/config` with minimal permissions (zero initial RBAC roles bound).
     - Includes a step-by-step drill guide at `/home/vagrant/cka/rbac/README.md`.
  1. **Manual User Context Creation Drills (`manual-user/`)**:
     - Hands-on manual execution of all operations automated by `create-user-context.sh` for CKA exam preparedness.
     - Located at `/home/vagrant/cka/rbac/manual-user/` with master walkthrough `README.md` and reference manifest `csr-template.yaml`.
     - Covers manual OpenSSL 2048-bit RSA private key and CSR creation (`/CN=developer/O=developers`).
     - Covers manual single-line base64 encoding and submission of Kubernetes `CertificateSigningRequest` (`certificates.k8s.io/v1`).
     - Covers manual CSR inspection and approval (`kubectl certificate approve developer`).
     - Covers manual certificate extraction and base64 decoding via jsonpath (`kubectl get csr developer -o jsonpath='{.status.certificate}' | base64 -d`).
     - Covers manual credential embedding (`kubectl config set-credentials`) and context configuration (`kubectl config set-context`).
     - Covers authorization verification, Role and RoleBinding creation, and context switching.
     - Includes end-to-end automated test validation script (`verify-manual-user.sh`) and reset/teardown tooling (`cleanup-manual-user.sh`).
  1. **ServiceAccount Token & RBAC Scenarios**:
     - Dedicated ServiceAccount RBAC guide at `/home/vagrant/cka/rbac/serviceaccounts/README.md`.

### Scenario 2: Sample Secrets across Namespaces (`secrets`)

- **Domain**: Configuration & Security (25%).
- **Exam References & Permitted Documentation**:
  - [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) `[EXAM ALLOWED]`
  - [Distribute Credentials Securely Using Secrets](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/) `[EXAM ALLOWED]`
  - [Managing Secrets using kubectl](https://kubernetes.io/docs/tasks/configmaps-secrets/managing-secret-using-kubectl/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"secret"`, `"secret envfrom"`, `"secret volume"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl create secret generic sample-secret --from-literal=password=secret123 --dry-run=client -o yaml
  kubectl create secret tls sample-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml
  kubectl explain pod.spec.volumes.secret
  kubectl explain pod.spec.containers.envFrom.secretRef
  ```

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

- **Domain**: Configuration & Kustomize (15%).
- **Exam References & Permitted Documentation**:
  - [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/) `[EXAM ALLOWED]`
  - [Configure a Pod to Use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) `[EXAM ALLOWED]`
  - [Declarative Management Using Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"configmap"`, `"immutable configmap"`, `"kustomize"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl create configmap app-cfg --from-literal=APP_ENV=prod --dry-run=client -o yaml
  kubectl explain pod.spec.containers.envFrom.configMapRef
  kubectl explain configmap.immutable
  kubectl kustomize <directory>
  ```

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

- **Domain**: Cluster Architecture, Installation & Configuration (25%).
- **Exam References & Permitted Documentation**:
  - [Helm Documentation](https://helm.sh/docs/) `[EXAM ALLOWED]`
  - [Resource Metrics Pipeline](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/) `[EXAM ALLOWED]`
  - [Tools for Monitoring Resources](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-usage-monitoring/) `[EXAM ALLOWED]`
  - [Gateway API Official Documentation](https://gateway-api.sigs.k8s.io/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"helm install"`, `"metrics server"`, `"kubectl top"`, `"gateway api"`
- **Fast Terminal Lookups**:

  ```bash
  helm repo add <repo-name> <repo-url>
  helm search repo <keyword>
  helm install <release-name> <chart> --set key=value
  helm list -A
  kubectl top nodes
  kubectl top pods -A --sort-by=cpu
  ```

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

- **Domain**: Storage & Volume Management (10%).
- **Exam References & Permitted Documentation**:
  - [Volumes](https://kubernetes.io/docs/concepts/storage/volumes/) `[EXAM ALLOWED]`
  - [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) `[EXAM ALLOWED]`
  - [Configure a Pod to Use a PersistentVolume for Storage](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/) `[EXAM ALLOWED]`
  - [Change the Reclaim Policy of a PersistentVolume](https://kubernetes.io/docs/tasks/administer-cluster/change-pv-reclaim-policy/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"persistent volume"`, `"persistent volume claim"`, `"pv reclaim policy"`, `"emptydir volume"`, `"hostpath"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl explain pv.spec
  kubectl explain pvc.spec
  kubectl explain pod.spec.volumes.nfs
  kubectl explain pod.spec.volumes.emptyDir
  kubectl explain pod.spec.volumes.hostPath
  ```

- **Exam Context & Permissibility Notes**:
  - Ceph RBD and iSCSI targets represent homelab raw block volume configurations `[HOMELAB AUXILIARY]`. The exam tests standard Kubernetes PersistentVolumes (`accessModes`, `capacity`, `hostPath`, `nfs`, `persistentVolumeReclaimPolicy`) and volume mounts.
- **Objective**: Leverage cluster NFS server (exporting `/exports` with `nfs-server.local` mapped across nodes) to scaffold comprehensive CKA volume drills under `/home/vagrant/cka/volumes/`:
  1. **NFS Shared Storage (`01-nfs/`)**: Direct inline NFS Pod mount (`01-nfs-direct-pod.yaml`), multi-replica shared read/write (`ReadWriteMany`) Deployment (`02-nfs-deployment-shared.yaml`), and PersistentVolume/PersistentVolumeClaim binding (`03-nfs-pv.yaml`, `04-nfs-pvc.yaml`, `05-nfs-pvc-pod.yaml`).
  1. **Ephemeral Volumes (`02-emptydir/`)**: Multi-container sidecar data sharing (`01-emptydir-sidecar-pod.yaml`) and in-memory tmpfs volume (`02-emptydir-memory-pod.yaml`).
  1. **Node Filesystem Volumes (`03-hostpath/`)**: `hostPath` mount with `DirectoryOrCreate` (`01-hostpath-pod.yaml`) and read-only host `/var/log` inspection (`02-hostpath-log-viewer.yaml`).
  1. **ConfigMap & Secret Volumes (`04-configmap-secret/`)**: Mounted ConfigMap items with `0644` permissions (`01-configmap-volume-pod.yaml`) and Secret files with restricted permissions (`defaultMode: 0400`) (`02-secret-volume-pod.yaml`).
  1. **PV/PVC Lifecycle & Expansion (`05-pv-pvc-lifecycle/`)**: Local manual PV binding with `Retain` reclaim policy (`01-local-pv-pvc.yaml`), online PVC expansion drill (`02-pvc-expansion.yaml`), and reclaim policy step-by-step drill guide (`03-reclaim-policy-drill.md`).
  1. **Ceph RBD Block Storage (`06-rbd/`)**: Dynamic Ceph RBD PVC, raw block volumes (`volumeMode: Block`), and expansion.
  1. **iSCSI Block Storage (`07-iscsi/`)**: Direct inline iSCSI mount, static PV/PVC binding, raw block devices, and CHAP credentials.
- **Artifacts**:
  - Volume practice directory: `/home/vagrant/cka/volumes/`
  - Automated verification scripts: `test-nfs-mounts.sh`, `06-rbd/test-rbd-volumes.sh`, and `07-iscsi/test-iscsi-volumes.sh`
  - Practice guides: `README.md`, `06-rbd/README.md`, and `07-iscsi/README.md`

### Scenario 6: Deployments, ReplicaSets & Rollouts Practice (`deployments`)

- **Domain**: Workloads & Scheduling (15%).
- **Exam References & Permitted Documentation**:
  - [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) `[EXAM ALLOWED]`
  - [Performing a Rolling Update](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/) `[EXAM ALLOWED]`
  - [ReplicaSets](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"deployment"`, `"rolling update"`, `"rollout undo"`, `"maxsurge"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl create deployment web --image=nginx:1.25-alpine --replicas=3 --dry-run=client -o yaml
  kubectl rollout status deployment/web
  kubectl rollout history deployment/web
  kubectl rollout undo deployment/web --to-revision=1
  kubectl explain deployment.spec.strategy.rollingUpdate
  ```

- **Objective**: Practice declarative and imperative deployment lifecycle management, rolling updates, rollbacks, history tracking, label selector troubleshooting, and deployment strategies:
  1. **Deployment Basics (`01-basic-deployment/`)**: `web-frontend-deployment.yaml` (3 replicas, resources, env vars) and `api-service-deployment.yaml`.
  1. **Label Selector Troubleshooting (`02-troubleshooting-labels/`)**: `broken-deployment.yaml` (mismatched selector vs template labels) and `fixed-deployment.yaml`.
  1. **Rolling Updates & Rollbacks (`03-rolling-updates-rollbacks/`)**: Version updates (`nginx:1.24` to `1.25`) and `rollout-drill.sh` walkthrough.
  1. **Deployment Strategies (`04-strategies/`)**: Custom RollingUpdate (`maxSurge: 1`, `maxUnavailable: 0`), percent-based rolling update, and Recreate strategy.
  1. **Pausing and Resuming Rollouts (`05-pause-resume/`)**: Batch changes while paused and resuming single-revision deployment.
- **Artifacts**:
  - Deployments drill directory: `/home/vagrant/cka/deployments/`
  - Automated test suite: `test-deployments-drills.sh`
  - Master practice guide: `README.md`

### Scenario 7: Pods, Lifecycle & Namespaces Practice (`pods`)

- **Domain**: Workloads & Scheduling (15%).
- **Exam References & Permitted Documentation**:
  - [Pods](https://kubernetes.io/docs/concepts/workloads/pods/) `[EXAM ALLOWED]`
  - [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/) `[EXAM ALLOWED]`
  - [Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) `[EXAM ALLOWED]`
  - [Define a Command and Arguments for a Container](https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/) `[EXAM ALLOWED]`
  - [Debugging Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"pod lifecycle"`, `"container states"`, `"restartpolicy"`, `"command arguments pod"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl run web --image=nginx:alpine --port=80 --labels=app=web --dry-run=client -o yaml
  kubectl run test-pod --rm -it --restart=Never --image=busybox:1.36 -- sh
  kubectl replace --force -f pod.yaml
  kubectl explain pod.spec.containers.command
  kubectl explain pod.spec.restartPolicy
  ```

- **Objective**: Practice imperative and declarative Pod management, command and argument overrides, lifecycle phase and container state diagnostics, observability (logs and exec), ephemeral network probing, spec immutability workflows, and namespace context preferences:
  1. **Imperative & Declarative Pods (`01-imperative-declarative/`)**: `run-imperative.sh` reference and declarative manifests.
  1. **Lifecycle Phases & Restart Policies (`02-lifecycle-and-restarts/`)**: Finite task (`restartPolicy: Never`), failing task (`CrashLoopBackOff`), and phases vs container states.
  1. **Observability & Diagnostics (`03-observability-exec/`)**: Structured log emitter, Downward API, log tailing, previous container logs (`-p`), and interactive exec.
  1. **Ephemeral Networking Diagnostics (`04-ephemeral-networking/`)**: Testing cluster IP reachability using one-off pods (`--rm -it --restart=Never`).
  1. **Pod Spec Immutability (`05-spec-immutability/`)**: Handling admission mutation errors via `kubectl replace --force`.
  1. **Namespaces & Context Preferences (`06-namespaces-context/`)**: Namespace creation and `kubectl config set-context --current --namespace=...`.
  1. **Pod Quarantine & Autopsy (`07-quarantine-autopsy/`)**: Isolating unhealthy pods from Service endpoints via label manipulation for live debugging.
- **Artifacts**:
  - Pods drill directory: `/home/vagrant/cka/pods/`
  - Automated test suite: `test-pods-drills.sh`
  - Master practice guide: `README.md`

### Scenario 8: Services, Ingress, Gateway API & Network Policies (`networking`)

- **Domain**: Services & Networking (20%).
- **Exam References & Permitted Documentation**:
  - [Services](https://kubernetes.io/docs/concepts/services-networking/service/) `[EXAM ALLOWED]`
  - [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) `[EXAM ALLOWED]`
  - [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) `[EXAM ALLOWED]`
  - [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) `[EXAM ALLOWED]`
  - [Gateway API Official Documentation](https://gateway-api.sigs.k8s.io/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"service nodeport"`, `"ingress path"`, `"network policy default deny"`, `"httproute"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl expose deployment web --port=80 --target-port=8080 --type=NodePort --dry-run=client -o yaml
  kubectl explain service.spec.type
  kubectl explain ingress.spec.rules
  kubectl explain networkpolicy.spec.ingress
  kubectl explain networkpolicy.spec.egress
  ```

- **Exam Context & Permissibility Notes**:
  - Caddy acts as a homelab edge reverse proxy terminating external TLS `[HOMELAB AUXILIARY]`. CKA exam networking focuses on Kubernetes Ingress controllers, Ingress resources, and Gateway API CRDs (`Gateway`, `HTTPRoute`).
- **Objective**: Comprehensive training across core Kubernetes networking abstractions, edge routing, and pod-to-pod microsegmentation:
  1. **Services & CoreDNS (`01-services/`)**: ClusterIP, NodePort, and Headless services with CoreDNS resolution (`<service>.<namespace>.svc.cluster.local`).
  1. **Ingresses (`02-ingresses/`)**: Multi-host and path-based Ingress routing (`ingressClassName: nginx`).
  1. **Gateway API & Caddy Integration (`03-gateway-api/`)**: Standard Gateway and HTTPRoute resources with path prefix routing and URL rewrite rules.
  1. **Network Policies (`04-network-policies/`)**: Default-deny ingress, client-to-backend authorization via `podSelector`, and egress DNS policy.
  1. **Advanced Multi-Namespace NetworkPolicies (`05-advanced-netpol/`)**: Combined `namespaceSelector` and `podSelector` rules.
- **Artifacts**:
  - Networking drill directory: `/home/vagrant/cka/networking/`
  - Automated test suite: `test-networking-drills.sh`
  - Master practice guide: `README.md`

### Scenario 9: Advanced Scheduling & Capacity Management (`scheduling`)

- **Domain**: Workloads & Scheduling (15%).
- **Exam References & Permitted Documentation**:
  - [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) `[EXAM ALLOWED]`
  - [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) `[EXAM ALLOWED]`
  - [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) `[EXAM ALLOWED]`
  - [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) `[EXAM ALLOWED]`
  - [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/) `[EXAM ALLOWED]`
  - [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/) `[EXAM ALLOWED]`
  - [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"taints and tolerations"`, `"node affinity"`, `"pod anti affinity"`, `"horizontal pod autoscaler"`, `"resource quota"`, `"limit range"`, `"priority class"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl taint nodes kube-worker-1 key=value:NoSchedule
  kubectl taint nodes kube-worker-1 key=value:NoSchedule-
  kubectl explain pod.spec.tolerations
  kubectl explain pod.spec.affinity.nodeAffinity
  kubectl explain pod.spec.affinity.podAntiAffinity
  kubectl explain quota.spec.hard
  kubectl explain limitrange.spec.limits
  ```

- **Objective**: Master node scheduling constraints, pod spreading, autoscaling, and namespace capacity governance:
  1. **Taints & Tolerations (`01-taints-tolerations/`)**: Applying and removing `NoSchedule` taints to nodes and configuring matching pod tolerations.
  1. **Affinities & Anti-Affinities (`02-affinities/`)**: Hard (`requiredDuringSchedulingIgnoredDuringExecution`) and soft (`preferredDuringSchedulingIgnoredDuringExecution`) `nodeAffinity`, and multi-replica hostname spreading via `podAntiAffinity`.
  1. **Horizontal Pod Autoscaling (`03-hpa-autoscaling/`)**: Dynamic pod replica autoscaling using `autoscaling/v2` based on target CPU utilization.
  1. **Capacity Governance (`04-quotas-limits/`)**: Namespace boundary enforcement using `ResourceQuota` and default limit/request injection via `LimitRange`.
  1. **PriorityClasses & Preemption (`05-priority-preemption/`)**: Priority classes, `preemptionPolicy`, and scheduler eviction under resource exhaustion.
- **Artifacts**:
  - Scheduling drill directory: `/home/vagrant/cka/scheduling/`
  - Automated test suite: `test-scheduling-drills.sh`
  - Master practice guide: `README.md`

### Scenario 10: Specialized Workload Controllers & Multi-Container Pods (`workloads_advanced`)

- **Domain**: Workloads & Scheduling (15%).
- **Exam References & Permitted Documentation**:
  - [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/) `[EXAM ALLOWED]`
  - [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/) `[EXAM ALLOWED]`
  - [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) `[EXAM ALLOWED]`
  - [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) `[EXAM ALLOWED]`
  - [Native Sidecar Containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"daemonset"`, `"job completions"`, `"cronjob concurrency"`, `"init container"`, `"sidecar container"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl explain daemonset.spec
  kubectl explain job.spec.completions
  kubectl explain job.spec.parallelism
  kubectl create cronjob batch-job --schedule="0 * * * *" --image=busybox --dry-run=client -o yaml -- /bin/sh -c "echo running"
  kubectl explain pod.spec.initContainers
  ```

- **Objective**: Deploy and maintain background node daemons, batch workloads, and coordinated multi-container pods:
  1. **DaemonSets (`01-daemonsets/`)**: Deploying node agents across all cluster nodes with control plane tolerations and hostPath inspection.
  1. **Batch Jobs & CronJobs (`02-batch-jobs/`)**: Parallel batch jobs (`completions`, `parallelism`) and scheduled CronJobs (`concurrencyPolicy: Forbid`).
  1. **Multi-Container Pods (`03-multi-container/`)**: Gated sequential initialization via `initContainers`, and native persistent helper execution via Kubernetes 1.28+ native sidecar containers (`restartPolicy: Always`).
- **Artifacts**:
  - Workloads drill directory: `/home/vagrant/cka/workloads-advanced/`
  - Automated test suite: `test-workloads-advanced-drills.sh`
  - Master practice guide: `README.md`

### Scenario 11: Dynamic Provisioning & StorageClasses (`storage_classes`)

- **Domain**: Storage (10%).
- **Exam References & Permitted Documentation**:
  - [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/) `[EXAM ALLOWED]`
  - [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/) `[EXAM ALLOWED]`
  - [Expanding Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#expanding-persistent-volumes-claims) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"storage class"`, `"volume binding mode"`, `"allow volume expansion"`, `"reclaim policy delete"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl explain storageclass
  kubectl explain storageclass.volumeBindingMode
  kubectl explain storageclass.reclaimPolicy
  kubectl explain storageclass.allowVolumeExpansion
  ```

- **Objective**: Configure dynamic storage provisioners, customize StorageClass operational parameters, and manage dynamic volume lifecycles:
  1. **Dynamic Provisioners (`01-provisioners/`)**: Deploying Rancher's lightweight `local-path-provisioner`.
  1. **StorageClass Lifecycle (`02-storage-classes/`)**: Configuring `reclaimPolicy` (`Delete` vs `Retain`), delayed binding (`volumeBindingMode: WaitForFirstConsumer`), dynamic PVC binding upon first pod consumer, and PVC volume expansion.
  1. **Dynamic NFS CSI Provisioning (`04-nfs-csi/`)**: Dynamic NFS volume provisioning using the official Kubernetes SIG Storage NFS CSI Driver.
- **Artifacts**:
  - StorageClasses drill directory: `/home/vagrant/cka/storage-classes/`
  - Automated test suite: `test-storage-classes-drills.sh`
  - Master practice guide: `README.md`

### Scenario 12: Cluster Maintenance & Node Troubleshooting (`cluster_troubleshooting`)

- **Domain**: Troubleshooting (30%).
- **Exam References & Permitted Documentation**:
  - [Safely Drain a Node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/) `[EXAM ALLOWED]`
  - [Create Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/) `[EXAM ALLOWED]`
  - [Troubleshoot Clusters](https://kubernetes.io/docs/tasks/debug/debug-cluster/) `[EXAM ALLOWED]`
  - [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/) `[EXAM ALLOWED]`
  - [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"safely drain node"`, `"static pod"`, `"troubleshoot cluster"`, `"dns debugging"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl cordon <node>
  kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
  kubectl uncordon <node>
  sudo journalctl -u kubelet -e --no-pager
  crictl ps
  crictl logs <container-id>
  ```

- **Objective**: Execute safe cluster node maintenance workflows, recover failing control plane static pods, and inspect resource telemetry:
  1. **Node Maintenance (`01-node-maintenance/`)**: Non-interactive node cordoning (`kubectl cordon`), workload eviction (`kubectl drain --ignore-daemonsets --delete-emptydir-data`), and return to service (`kubectl uncordon`).
  1. **Static Pod Break-Fix (`02-static-pod-recovery/`)**: Diagnosing and repairing corrupted control plane manifests in `/etc/kubernetes/manifests/` using `crictl` and system logs.
  1. **Kubelet Diagnostics (`03-kubelet-diagnostics/`)**: Troubleshooting worker node systemd `kubelet.service` failures and configuration syntax errors (`/var/lib/kubelet/config.yaml`).
  1. **Resource Telemetry (`04-metrics-monitoring/`)**: Live node and pod CPU/memory consumption inspection using `kubectl top nodes` and `kubectl top pods`.
  1. **CoreDNS Recovery (`05-coredns-recovery/`)**: Diagnosing and repairing CoreDNS ConfigMap `Corefile` syntax errors and upstream forwarders.
  1. **Service & Endpoints Triage (`06-service-endpoints-recovery/`)**: Resolving mismatched label selectors and targetPort definitions causing unreachable services.
  1. **Worker Static Pods (`07-worker-static-pods/`)**: Configuring worker node kubelet `staticPodPath` and validating mirror pod creation on the API server.
  1. **Container Runtime Diagnostics (`08-containerd-diagnostics/`)**: Direct CRI triage using `crictl` and container logs.
- **Artifacts**:
  - Troubleshooting drill directory: `/home/vagrant/cka/cluster-troubleshooting/`
  - Automated test suite: `test-cluster-troubleshooting.sh`
  - Master practice guide: `README.md`

### Scenario 13: Custom Resource Definitions & Operators (`crds`)

- **Domain**: Cluster Architecture, Installation & Configuration (25%).
- **Exam References & Permitted Documentation**:
  - [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) `[EXAM ALLOWED]`
  - [Extend the Kubernetes API with CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"custom resource definitions"`, `"openapiv3schema"`, `"printer columns"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl explain crd.spec
  kubectl explain crd.spec.versions.schema.openAPIV3Schema
  kubectl explain crd.spec.names
  ```

- **Objective**: Define custom API schemas with OpenAPI v3 validation and manage custom resource lifecycles:
  1. **CRD Specification (`01-crd-schema/`)**: Declaring group, version, kind, shortNames, additional printer columns, and OpenAPI v3 structural validation rules.
  1. **Custom Resource Lifecycle**: Creating declarative instances and testing admission webhook rejection on malformed specifications.
- **Artifacts**:
  - CRD drill directory: `/home/vagrant/cka/crds-operators/`
  - Automated test suite: `test-crds-drills.sh`
  - Master practice guide: `README.md`

### Scenario 14: Chaos Engineering & Dynamic Troubleshooting (`chaos_troubleshooting`)

- **Domain**: Troubleshooting & Resilience (30%).
- **Exam References & Permitted Documentation**:
  - [Debugging Pods (OOM / CrashLoopBackOff)](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) `[EXAM ALLOWED]`
  - [Troubleshooting Cluster Networking](https://kubernetes.io/docs/tasks/debug/debug-cluster/debug-network/) `[EXAM ALLOWED]`
  - [Pod Quality of Service (QoS) Classes](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos-class/) `[EXAM ALLOWED]`
  - [Node-pressure Eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"debug pods"`, `"oomkilled"`, `"pod qos class"`, `"node pressure eviction"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl describe pod <pod-name> | grep -E "Exit Code|Reason|Last State"
  kubectl debug pod/<pod-name> -it --image=busybox --target=<container-name>
  kubectl describe node <node-name> | grep -A 5 Conditions
  ```

- **Exam Context & Permissibility Notes**:
  - Headless LitmusChaos is an automated homelab fault injection engine `[HOMELAB AUXILIARY]`. Candidates in the actual CKA exam will not see Litmus; they must diagnose injected system failures (OOM Exit Code 137, Network Drops, Node MemoryPressure) using standard `kubectl describe`, logs, and node conditions.
- **Objective**: On-demand runtime fault injection using Headless LitmusChaos to simulate live service failures:
  1. **Memory OOM Drill (`01-memory-oom`)**: Simulates container memory exhaustion (`pod-memory-hog`), inspecting `OOMKilled` (ExitCode 137), and adjusting resource limits.
  1. **Network Degradation Drill (`02-network-latency`)**: Injects 70% packet loss (`pod-network-loss`) to troubleshoot timeouts using ephemeral debug containers (`kubectl debug`).
  1. **CoreDNS Blackhole Drill (`03-dns-chaos`)**: Disrupts inter-service DNS lookups (`pod-dns-error`) to diagnose resolution paths.
  1. **Node MemoryPressure Drill (`04-node-pressure`)**: Induces node memory saturation (`node-memory-hog`) to examine node conditions and QoS pod eviction priorities.
- **Artifacts**:
  - Chaos drill directory: `/home/vagrant/cka/chaos-troubleshooting/`
  - Automated verification test suite: `test-chaos-drills.sh`
  - Master practice guide: `README.md`

### Scenario 15: etcd Snapshot Backup & Restore (`etcd`)

- **Domain**: Cluster Architecture, Installation & Configuration (25%).
- **Exam References & Permitted Documentation**:
  - [Operating etcd clusters for Kubernetes (Backup & Restore)](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"backup etcd"`, `"restore etcd"`, `"etcd snapshot"`
- **Fast Terminal Lookups**:

  ```bash
  ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save /tmp/etcd-snapshot.db

  ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-snapshot.db --write-out=table

  ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-snapshot.db \
    --data-dir=/var/lib/etcd-restored
  ```

- **Objective**: Discover TLS parameters directly from static pod manifest `/etc/kubernetes/manifests/etcd.yaml`, take verified snapshot, restore to new data-dir, update static pod hostPath, verify API server restoration, and manage automated daily backup systemd timers:
  1. `backup-etcd.sh`: Discovers TLS flags and saves snapshot to `/var/lib/etcd-backup/etcd-snapshot.db`.
  1. `restore-etcd.sh`: Restores snapshot into `/var/lib/etcd-restored`.
  1. `simulate-loss-drill.sh`: End-to-end drill testing canary namespace persistence across backup/loss/restore cycles.
  1. `backup-etcd-daily.sh`: Automated daily snapshot with health verification, `etcd-snapshot-` prefix and timestamp naming, and 7-day retention deletion.
  1. `etcd-backup.timer` & `etcd-backup.service`: Systemd daily timer automation (`OnCalendar=daily`, `Persistent=true`) and management tooling.
- **Artifacts**:
  - etcd drill directory: `/home/vagrant/cka/etcd/`
  - Automated daily backup directory: `/home/vagrant/cka/etcd/02-automated-backup/`
  - Automated test suite: `test-etcd-drills.sh`
  - Master practice guide: `README.md`

### Scenario 16: Manual Kubeadm Cluster Upgrade (`upgrade_drill`)

- **Domain**: Cluster Architecture, Installation & Configuration (25%).
- **Exam References & Permitted Documentation**:
  - [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"upgrading kubeadm clusters"`, `"kubeadm upgrade apply"`
- **Fast Terminal Lookups**:

  ```bash
  apt-mark unhold kubeadm kubelet kubectl
  apt-get update && apt-get install -y --allow-change-held-packages kubeadm=1.34.x-1.1
  kubeadm upgrade plan
  sudo kubeadm upgrade apply v1.34.x
  sudo kubeadm upgrade node
  apt-mark hold kubeadm kubelet kubectl
  ```

- **Objective**: Hands-on walkthrough of manual node draining, APT package unholding, `kubeadm upgrade apply/node`, `kubelet`/`kubectl` package upgrades, and uncordoning:
  1. `mock-control-plane-upgrade.sh`: Control plane upgrade commands and dry-run validation.
  1. `mock-worker-upgrade.sh`: Worker node upgrade sequence.
- **Artifacts**:
  - Upgrade drill directory: `/home/vagrant/cka/upgrade/`
  - Automated test suite: `test-upgrade-drills.sh`
  - Master practice guide: `README.md`

### Scenario 17: Speed JSONPath & Output Formatting (`jsonpath`)

- **Domain**: Troubleshooting (30%) & Workloads (15%).
- **Exam References & Permitted Documentation**:
  - [JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/) `[EXAM ALLOWED]`
  - [kubectl Cheat Sheet - Formatting Output](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#formatting-output) `[EXAM ALLOWED]`
- **In-Exam Search Keywords**: `"jsonpath support"`, `"custom columns"`
- **Fast Terminal Lookups**:

  ```bash
  kubectl get nodes -o jsonpath='{.items[*].metadata.name}'
  kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'
  kubectl get pods -A --sort-by=.metadata.creationTimestamp
  kubectl get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
  ```

- **Objective**: 10 rapid exam challenges practicing `-o jsonpath`, filter queries `[?(@...)]`, range loops, `--sort-by`, and custom columns.
- **Artifacts**:
  - JSONPath directory: `/home/vagrant/cka/jsonpath/`
  - Challenges and solutions: `challenges.md` and `solutions.md`
  - Automated evaluation harness: `/home/vagrant/cka/jsonpath/eval-jsonpath.sh`
  - Master practice guide: `/home/vagrant/cka/jsonpath/README.md`

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

### Verify etcd Backup & Restore Scenario

```bash
cd /home/vagrant/cka/etcd
./test-etcd-drills.sh
```

### Verify Manual Kubeadm Upgrade Drill

```bash
cd /home/vagrant/cka/upgrade
./test-upgrade-drills.sh
```

### Verify Speed JSONPath Scenario

```bash
cd /home/vagrant/cka/jsonpath
./eval-jsonpath.sh
```

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
  4. Submits a Kubernetes `CertificateSigningRequest` (`certificates.k8s.io/v1`), approves it via `kubectl certificate approve`, and extracts the issued client certificate (`anna.crt`).
  5. Assembles `/home/anna/.kube/config` with embedded client certificates and sets active context to `anna@kubernetes`.

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

### Scenario 4: Helm Tools & Monitoring (`helm`)

- **Domain**: Cluster Architecture, Installation & Configuration.
- **Reference**: [Helm Documentation](https://helm.sh/docs/) & [Prometheus Community Helm Charts](https://github.com/prometheus-community/helm-charts)
- **Objective**: Provision standalone Helm deployment scripts for hands-on cluster addon management and monitoring:
  1. `install-kube-metrics.sh`: Deploys Kubernetes Metrics Server with `--kubelet-insecure-tls` enabling `kubectl top nodes` and `kubectl top pods`.
  2. `install-kube-prometheus.sh`: Deploys the Prometheus Operator (`kube-prometheus-stack`) configured with Prometheus ONLY (Alertmanager, Grafana, node-exporter, and kube-state-metrics disabled) for minimal resource footprint on lab VMs.
- **Artifacts**:
  - Helm scripts and guide directory: `/home/vagrant/cka/helm/`
  - Installer scripts: `install-kube-metrics.sh` and `install-kube-prometheus.sh`
  - Practice guide: `/home/vagrant/cka/helm/README.md`

## Verification inside Control Plane

### Verify RBAC Scenario

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
```

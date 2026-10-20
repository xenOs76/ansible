# Implementation Plan: Kubernetes AWS OIDC IAM Workload Federation

**Target Scenarios:** `k8s-homelab/roles/control_plane`, `k8s-homelab/roles/cka_lab`  
**Target Reference Implementation:**  
[xenOs76 Gist 2123d6938441d5cb044dd5a64e3fee88](https://gist.github.com/xenOs76/2123d6938441d5cb044dd5a64e3fee88)  
**Static Discovery Export Target:** Local untracked staging directory (`.oidc-dist/`)  
**Documentation Domain:** Official Kubernetes TokenRequest / ServiceAccount Issuer & AWS STS AssumeRoleWithWebIdentity  

---

## 1. Objectives & Executive Summary

The objective is to enable workloads (Pods) in `k8s-homelab` and `cka-lab` to securely assume AWS IAM roles using
native OpenID Connect (OIDC) identity federation without static AWS credentials (`AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY`). This follows the AWS IAM Roles for Service Accounts (IRSA) architecture adapted for
self-hosted Kubernetes clusters.

### Core Architectural Components

1. **Persistent Service Account Signing Keys in SOPS**:
   - Generate and securely store RSA 2048-bit ServiceAccount signing keys (`sa.key`, `sa.pub`) in `secrets.sops.yaml`.
   - Pre-seeding `/etc/kubernetes/pki/sa.key` and `sa.pub` before `kubeadm init` guarantees key stability across cluster
     rebuilds (`make preprod-destroy` / `make preprod-deploy`) without invalidating AWS IAM OIDC trust relationships.
2. **Static OIDC Discovery Document Publication**:
   - Automatically derive JSON Web Key Set (`jwks.json`) and OpenID configuration (`.well-known/openid-configuration`)
     from the public key.
   - Export generated static discovery documents to a local, temporary directory not tracked via git (e.g.
     `.oidc-dist/`), allowing the operator to manually import and publish them to `oidc.os76.xyz` as needed.
3. **Kube-apiserver OIDC Configuration**:
   - Configure kubeadm `ClusterConfiguration` and kube-apiserver static pod arguments:
     - Primary issuer: `https://oidc.os76.xyz`
     - Secondary issuer: `https://kubernetes.default.svc.cluster.local` (ensures 100% backward compatibility for core
       cluster components and standard in-cluster clients)
     - Audiences: `sts.amazonaws.com` and `https://kubernetes.default.svc.cluster.local`
     - Public JWKS URI: `https://oidc.os76.xyz/jwks.json`
4. **CKA Practice Lab Integration & Non-Interference**:
   - Ensure the OIDC federation does not alter, break, or interfere with default CKA certification exercises (chapters
     `00-cluster-installation` through `19-ha-cluster`).
   - Add a dedicated, isolated scenario chapter `20-aws-oidc-iam` in `roles/cka_lab` covering projected service account
     tokens, TokenRequest API mechanics, token inspection with `https-wrench`, and mock AWS Pod identity drills.

> [!IMPORTANT]
> **Documentation Standards**:
> All generated documentation and drill guides must exclusively cite official Kubernetes documentation
> (`kubernetes.io/docs/`) and official AWS STS documentation (`docs.aws.amazon.com`). Never cite proprietary training
> materials or third-party courses.

---

## 2. Technical Architecture & End-to-End Workflow

```text
+-------------------------------------------------------------------------------------------------------+
|                                        Workstation / Repository                                       |
|                                                                                                       |
|  1. Generate RSA Key Pair (sa.key, sa.pub)                                                            |
|  2. Encrypt & Save in secrets.sops.yaml via SOPS / Age                                                |
|  3. Compute RFC 7517 / 7638 JWKS (kid, n, e) & .well-known/openid-configuration                       |
|  4. Export static files to local untracked directory (.oidc-dist/)                                    |
+-------------------------------------------------------------------+-----------------------------------+
                                                                    |
                                        Manual Import & Deployment  |
                                                                    v
                                                     +-------------------------------+
                                                     | Public Web Server             |
                                                     | https://oidc.os76.xyz         |
                                                     | /.well-known/openid-config    |
                                                     | /jwks.json                    |
                                                     +---------------+---------------+
                                                                     ^
                                           AWS STS Validates JWKS    |
                                                                     v
+----------------------------------------------------+       +-------------------------------+
| Kubernetes Control Plane (kube-control-plane)      |       | AWS STS (AssumeRoleWithWebId) |
|                                                    |       |                               |
|  - Injects /etc/kubernetes/pki/sa.key & sa.pub     |       | 1. Accepts Pod JWT token      |
|  - kube-apiserver flags:                           |       | 2. Fetches public JWKS keys   |
|    --service-account-issuer=https://oidc.os76.xyz  |       | 3. Validates signature & sub  |
|    --service-account-issuer=kubernetes.default...  |       | 4. Returns temporary AWS keys |
|    --api-audiences=sts.amazonaws.com               |       +---------------+---------------+
+-------------------------+--------------------------+                       ^
                          | Signs TokenRequest                               |
                          v                                                  |
+----------------------------------------------------+                       |
| Worker Node & Target Pod                           |                       |
|                                                    |                       |
|  - Pod mounts Projected ServiceAccount Token       |                       |
|    audience: sts.amazonaws.com                    |                       |
|  - AWS SDK exchanges token for temporary creds ----+-----------------------+
+----------------------------------------------------+
```

---

## 3. Implementation Steps & Workflows

### Phase 1: Key Pair Generation & SOPS Management

1. **Automation Tooling (`scripts/generate-oidc-sa-keys.sh`)**:
   - Provide a standalone script executable from repository root.
   - Check if `secrets.sops.yaml` already contains `oidc_sa_private_key` and `oidc_sa_public_key`.
   - If missing (or invoked with `--force`), generate:

     ```bash
     openssl genrsa -out /tmp/sa.key 2048
     openssl rsa -in /tmp/sa.key -pubout -out /tmp/sa.pub
     ```

   - Encrypt the keys into `secrets.sops.yaml`:

     ```yaml
     oidc_sa_private_key: |
       <RSA_PRIVATE_KEY_PEM>
     oidc_sa_public_key: |
       <RSA_PUBLIC_KEY_PEM>
     ```

   - Calculate JWK parameters (`n`, `e`, `kid` thumbprint) using Python/OpenSSL and render:
     - `.oidc-dist/.well-known/openid-configuration`
     - `.oidc-dist/jwks.json`
2. **Local Staging Export Configuration**:
   - Export generated static discovery documents to a local staging directory not tracked by Git (default:
     `k8s-homelab/.oidc-dist/`, or override via CLI option `--output-dir` / `OIDC_OUTPUT_DIR`).
   - Add `.oidc-dist/` to `.gitignore` to guarantee generated artifacts remain untracked.
   - The operator manually copies/imports these files to the target public destination (e.g.,
     `/home/xeno/git/gitea/os76-public/content/oidc/` or public S3/web server) when ready.

### Phase 2: Static OIDC Discovery Documents Format

1. **`openid-configuration` Specification**:

   ```json
   {
     "issuer": "https://oidc.os76.xyz",
     "jwks_uri": "https://oidc.os76.xyz/jwks.json",
     "authorization_endpoint": "urn:kubernetes:programmatic_authorization",
     "response_types_supported": [
       "id_token"
     ],
     "subject_types_supported": [
       "public"
     ],
     "id_token_signing_alg_values_supported": [
       "RS256"
     ],
     "claims_supported": [
       "sub",
       "iss"
     ]
   }
   ```

2. **`jwks.json` Specification**:

   ```json
   {
     "keys": [
       {
         "use": "sig",
         "kty": "RSA",
         "kid": "<calculated-rfc7638-thumbprint>",
         "alg": "RS256",
         "n": "<base64url-encoded-modulus>",
         "e": "AQAB"
       }
     ]
   }
   ```

3. **Verification**:
   - Validate token and JWKS matching using `https-wrench`:

     ```bash
     https-wrench jwtinfo --token-file /tmp/sample.jwt --validation-url https://oidc.os76.xyz/jwks.json
     ```

### Phase 3: Ansible `control_plane` Role Updates

1. **Group Variables (`group_vars/all.yml` & `group_vars/control_plane.yml`)**:
   - Add feature toggles and endpoint parameters:

     ```yaml
     oidc_aws_iam_enabled: true
     oidc_issuer_url: "https://oidc.os76.xyz"
     oidc_api_audiences:
       - "sts.amazonaws.com"
       - "https://kubernetes.default.svc.cluster.local"
     oidc_jwks_uri: "https://oidc.os76.xyz/jwks.json"
     oidc_static_export_dir: "{{ playbook_dir }}/.oidc-dist"
     ```

2. **Pre-seeding Service Account Keys**:
   - In `roles/control_plane/tasks/main.yml`, before running `kubeadm init`:
     - Decrypt `oidc_sa_private_key` and `oidc_sa_public_key` from SOPS secrets using `community.sops.sops`.
     - Write to `/etc/kubernetes/pki/sa.key` (`0600 root:root`) and `/etc/kubernetes/pki/sa.pub` (`0644 root:root`).
     - Kubeadm detects pre-existing keys during `kubeadm init phase certs sa` and uses them without regenerating.
3. **Kube-apiserver Configuration Management**:
   - For fresh initializations: include extra arguments in `ClusterConfiguration` (`kubeadm-config.yaml`).
   - For already initialized clusters:
     - Check `/etc/kubernetes/manifests/kube-apiserver.yaml` for:
       - `--service-account-issuer=https://oidc.os76.xyz`
       - `--service-account-issuer=https://kubernetes.default.svc.cluster.local`
       - `--api-audiences=sts.amazonaws.com,https://kubernetes.default.svc.cluster.local`
       - `--service-account-jwks-uri=https://oidc.os76.xyz/jwks.json`
     - Safely update the static pod manifest using the established backup/restore reload pattern in
       `roles/control_plane/tasks/main.yml`.
     - Wait for `/livez` health check confirmation on port 6443.

### Phase 4: CKA Practice Lab Integration (`roles/cka_lab`)

1. **Ensuring Non-Interference**:
   - The secondary issuer `--service-account-issuer=https://kubernetes.default.svc.cluster.local` ensures default
     in-cluster tokens continue to validate seamlessly.
   - Core CKA tasks (`01-jsonpath` to `19-ha-cluster`) remain completely unaware of the OIDC configuration and function
     unhindered.
   - TokenRequest API continues to service standard in-cluster RBAC and service accounts.
2. **Dedicated Scenario: Chapter `20-aws-oidc-iam`**:
   - Add `scenario_aws_oidc_iam.yml` included via `roles/cka_lab/tasks/main.yml` with toggle
     `cka_lab_scenario_aws_oidc_iam_enabled: true`.
   - Provisions directory `/home/vagrant/cka/20-aws-oidc-iam/` (with compatibility symlink `~/cka/aws-oidc-iam/`).
   - Deliverables inside the chapter:
     - `README.md`: Pedagogical explanation of TokenRequest API, OIDC discovery, STS federation, and Pod configuration.
     - `01-create-oidc-token.sh`: Demonstrates imperative token issuance using `kubectl create token` with target
       audience `sts.amazonaws.com`.
     - `02-verify-jwt-jwks.sh`: Uses `https-wrench jwtinfo` to decode the header/claims and verify signature against
       `https://oidc.os76.xyz/jwks.json`.
     - `03-deploy-sample-workload.yaml`: Demonstrates Projected Volume Token specification and AWS STS environment
       variables (`AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`).
     - `verify-oidc-iam.sh`: End-to-end automated verification script confirming token validity, audience alignment,
       and static pod arguments.

---

## 4. AWS Cloud Configuration (Reference)

For reference and documentation completeness, the AWS IAM setup requires:

1. **IAM Identity Provider**:
   - Provider Type: OpenID Connect
   - Provider URL: `https://oidc.os76.xyz`
   - Audience: `sts.amazonaws.com`
2. **IAM Role Trust Policy**:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.os76.xyz"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "oidc.os76.xyz:aud": "sts.amazonaws.com",
             "oidc.os76.xyz:sub": "system:serviceaccount:default:aws-client"
           }
         }
       }
     ]
   }
   ```

---

## 5. Verification & Quality Gates

Before declaring completion of the implementation:

1. **Key & Static Document Verification**:
   - `sa.key` and `sa.pub` correctly encrypted in `secrets.sops.yaml`.
   - `curl -fsSL https://oidc.os76.xyz/.well-known/openid-configuration` returns valid JSON matching the issuer URL.
   - `curl -fsSL https://oidc.os76.xyz/jwks.json` returns valid JWKS containing key ID matching generated tokens.
2. **Cluster Health & In-Cluster Verification**:
   - Kube-apiserver starts cleanly and passes `/livez`.
   - `kubectl create token aws-client --audience sts.amazonaws.com` generates a token with `iss: https://oidc.os76.xyz`.
   - `https-wrench jwtinfo --token-file /tmp/token --validation-url https://oidc.os76.xyz/jwks.json` verifies signature.
3. **CKA Non-Interference Verification**:
   - `scripts/run-playbook.sh playbooks/cka_lab.yml` runs to completion with 0 failures.
   - Existing CKA exercises (`03-rbac`, `15-etcd`, `16-upgrade`) pass all self-tests.
4. **Code Quality Standards**:
   - Markdown line length: `python3 scripts/check-readme-line-length.py k8s-homelab/docs/plan_aws_oidc_iam.md` passes.
   - YAML syntax: `yamllint -c .yamllint` passes.
   - Shell scripts: `shellcheck -s bash` passes on all generated scripts.

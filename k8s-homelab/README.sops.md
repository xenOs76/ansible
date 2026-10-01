# SOPS Secrets Management in k8s-homelab

This document details how secrets (such as the PowerDNS API token used by Caddy for Let's Encrypt DNS-01 ACME challenges) are managed and encrypted in `k8s-homelab` using [Mozilla SOPS](https://github.com/getsops/sops) and [Age](https://github.com/FiloSottile/age) encryption keys.

---

## 1. Multi-Recipient Key Architecture

Secrets in this directory are encrypted for multiple recipients matching the OS76 infrastructure standard defined in `nix-configs/.sops.yaml`. This enables decrypting and editing secrets seamlessly from workstation and server environments:

- **`xeno@zero`**: `age1lsfvx7nwct987yezqud0tt9y05yhmcquckf0kalfqwrqfuygnvhsr09d5g`
- **`xeno@nemo`**: `age1dcgemfs0w6huj0r7058xxjxfe746p2yzyehj9cj00amu54rhaehs7cca07`
- **`server_zero`**: `age1qwdngwfh5adnacezn35lzgnm7jcp0e7j6ts346ufkj58wwpy7d4qr6rm2m`
- **`server_nemo`**: `age1jv4mly2k8jere0jgfxewjgvhdgfc999zxgpqttxecjmc0qr9hs2sgls5my`

The configuration is declared in [`k8s-homelab/.sops.yaml`](file:///home/xeno/git/gitea/os76-ansible/k8s-homelab/.sops.yaml).

---

## 2. Prerequisites & Environment

Both `sops` and `age` CLI binaries are bundled in the Nix development environment:

```bash
cd k8s-homelab
nix-shell
# Or with direnv enabled:
direnv allow
```

Ensure your private Age key exists at `~/.config/sops/age/keys.txt` (or pointed to via `$SOPS_AGE_KEY_FILE`).

---

## 3. Reading Secrets

### View Entire Decrypted File

To inspect the decrypted contents in your terminal without modifying the file:

```bash
sops -d secrets.sops.yaml
```

### Extract a Single Secret Value

To print only a specific key (e.g. for scripting or verification):

```bash
# Extract PowerDNS credentials:
sops -d --extract '["caddy_powerdns_api_token"]' secrets.sops.yaml
sops -d --extract '["caddy_powerdns_server_url"]' secrets.sops.yaml

# Extract Garage S3 binary cache credentials:
sops -d --extract '["caddy_garage_access_key"]' secrets.sops.yaml
sops -d --extract '["caddy_garage_secret_key"]' secrets.sops.yaml
```

---

## 4. Editing Secrets

To modify existing secrets or add new keys:

```bash
sops secrets.sops.yaml
```

This launches your default `$EDITOR` (e.g. `vim`, `nano`, or `code`), decrypts the content into a temporary buffer in memory, and re-encrypts the file automatically upon save and exit.

> [!NOTE]
> SOPS encrypts only the values while keeping YAML keys in plaintext, enabling clean Git diffs and branch conflict reviews.

---

## 5. Adding New Encrypted Files

Any file ending in `.sops.yaml` or `.sops.yml` in this directory is automatically matched by `.sops.yaml` creation rules:

```bash
# Edit a new encrypted file directly:
sops my-new-secrets.sops.yaml

# Or encrypt an existing plaintext file:
sops -e plaintext.yaml > my-new-secrets.sops.yaml
```

---

## 6. Updating Recipient Keys

If recipient keys in `.sops.yaml` change (e.g. adding a new host or rotating a key), re-encrypt existing files without altering their decrypted values:

```bash
sops updatekeys secrets.sops.yaml
```

---

## 7. How Ansible Uses SOPS at Runtime

Ansible uses the `community.sops.sops` lookup plugin to decrypt `secrets.sops.yaml` directly in-memory on the controller workstation during playbook execution:

```yaml
# PowerDNS API credentials
caddy_powerdns_server_url: >-
  {{
    (lookup('community.sops.sops', caddy_sops_secrets_file, errors='ignore') | default('{}', true) | from_yaml).caddy_powerdns_server_url
    | default(lookup('ansible.builtin.env', 'POWERDNS_SERVER_URL') | default('http://192.168.1.1:8081', true))
  }}
caddy_powerdns_api_token: >-
  {{
    (lookup('community.sops.sops', caddy_sops_secrets_file, errors='ignore') | default('{}', true) | from_yaml).caddy_powerdns_api_token
    | default(lookup('ansible.builtin.env', 'POWERDNS_API_TOKEN') | default('', true))
  }}

# Garage S3 binary cache credentials
caddy_garage_access_key: >-
  {{
    (lookup('community.sops.sops', caddy_sops_secrets_file, errors='ignore') | default('{}', true) | from_yaml).caddy_garage_access_key
    | default(lookup('ansible.builtin.env', 'GARAGE_ACCESS_KEY') | default(lookup('ansible.builtin.env', 'AWS_ACCESS_KEY_ID') | default('', true)))
  }}
caddy_garage_secret_key: >-
  {{
    (lookup('community.sops.sops', caddy_sops_secrets_file, errors='ignore') | default('{}', true) | from_yaml).caddy_garage_secret_key
    | default(lookup('ansible.builtin.env', 'GARAGE_SECRET_KEY') | default(lookup('ansible.builtin.env', 'AWS_SECRET_ACCESS_KEY') | default('', true)))
  }}
```

- **In-Memory Decryption**: Plaintext values are never written to disk on the controller.
- **Target Node Protection**: The rendered PowerDNS secret is provisioned into `/etc/caddy/caddy.env` with strict `0600 root:caddy` permissions on the control plane. S3 credentials are used exclusively in-memory by Ansible during the build/restore phase with `no_log: true`.
- **Garage S3 Binary Caching**: When `caddy_s3_cache_enabled` is true, Ansible checks `s3://os76-assets/caddy/{{ caddy_version }}/caddy-powerdns-linux-{{ caddy_arch }}` in Garage before compiling. If found, it skips CPU-intensive Go compilation; if missing, it compiles Caddy via `xcaddy` and uploads the artifact to S3 for future deployments.
- **Graceful Fallback**: If `secrets.sops.yaml` is not present, Ansible falls back to environment variables (`POWERDNS_SERVER_URL`, `POWERDNS_API_TOKEN`, `GARAGE_ACCESS_KEY`, `GARAGE_SECRET_KEY`).

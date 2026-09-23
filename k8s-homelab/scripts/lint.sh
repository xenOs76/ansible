#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${BASE_DIR}/.." && pwd)"

# Verify required tools are present in PATH
for tool in yamllint ansible-playbook ansible-inventory ansible-lint; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Error: Required tool '${tool}' is not installed or not in PATH." >&2
    echo "Hint: If using Nix, run 'direnv allow' or 'nix-shell' in k8s-homelab/." >&2
    echo "      Otherwise, install via pip: pip install ansible ansible-lint yamllint" >&2
    exit 1
  fi
done

echo "=== 1. YAML Lint Validation ==="
if [[ -f "${ROOT_DIR}/.yamllint" ]]; then
  yamllint -c "${ROOT_DIR}/.yamllint" "${BASE_DIR}"
else
  yamllint "${BASE_DIR}"
fi
echo "✔ YAML Lint passed."

echo ""
echo "=== 2. Ansible Playbook Syntax Checks ==="
cd "${BASE_DIR}"
for pb in playbooks/*.yml; do
  echo "  Checking syntax: ${pb}"
  ansible-playbook -i inventory/preprod/hosts.ini "${pb}" --syntax-check
done
echo "✔ Playbook syntax checks passed."

echo ""
echo "=== 3. Ansible Inventory Validation ==="
ansible-inventory -i inventory/preprod/hosts.ini --graph
echo "✔ Preprod inventory graph parsed successfully."

echo ""
echo "=== 4. Ansible-lint Quality Checks ==="
ansible-lint -c "${BASE_DIR}/.ansible-lint" playbooks/ roles/
echo "✔ ansible-lint checks passed."

echo ""
echo "========================================="
echo "🎉 All Ansible code quality checks passed!"
echo "========================================="

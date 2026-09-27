#!/usr/bin/env bash
# ==============================================================================
# Script: run-playbook.sh
# Purpose: Parameterized execution wrapper for Ansible playbooks supporting
#          target environment selection, inventory resolution, tag filtering,
#          and transparent argument forwarding to ansible-playbook.
#
# Context:
#   Executed on the HOST machine. Provides a consistent CLI interface for
#   manual cluster runs, CI/CD stages, and Makefile targets.
#
# Usage:
#   ./scripts/run-playbook.sh [-e <env>] [-p <playbook>] [-t <tags>] [extra args...]
#
# Options:
#   -e, --env       Target environment inventory directory in inventory/
#                   (e.g. 'preprod' -> inventory/preprod/hosts.ini).
#                   Default: preprod
#   -p, --playbook  Name of the playbook file located in playbooks/
#                   (e.g. 'site.yml', 'cni.yml', 'upgrade.yml', 'reset.yml').
#                   Default: site.yml
#   -t, --tags      Comma-separated list of Ansible tags to execute
#                   (e.g. 'common,cri', 'helm', 'k9s', 'control_plane').
#   -h, --help      Display detailed help message and examples.
#   extra args...   Any unrecognized options are forwarded verbatim to
#                   ansible-playbook (e.g. -vvv, --check, --diff, --extra-vars).
#
# Examples:
#   # Run complete deployment on preprod:
#   ./scripts/run-playbook.sh -e preprod -p site.yml
#
#   # Run only container runtime and package tags:
#   ./scripts/run-playbook.sh -e preprod -t "cri,k8s_packages"
#
#   # Run dry-run syntax / check with diffs:
#   ./scripts/run-playbook.sh -e preprod -p site.yml --check --diff
#
#   # Perform rolling upgrade with custom target version:
#   ./scripts/run-playbook.sh -e preprod -p upgrade.yml --extra-vars "k8s_version=1.34.2-1.1"
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV="preprod"
PLAYBOOK="site.yml"
TAGS=""
EXTRA_ARGS=()

usage() {
  cat <<EOF
Usage: $0 [-e <preprod|prod>] [-p <playbook>] [-t <tags>] [extra ansible args...]

Options:
  -e, --env       Target environment (default: preprod)
  -p, --playbook  Playbook file name in playbooks/ (default: site.yml)
  -t, --tags      Ansible tags to execute (e.g. common, cri, cni, upgrade, helm, k9s)
  -h, --help      Show this help message

Examples:
  $0 -e preprod -p site.yml
  $0 -e preprod -t "common,cri"
  $0 -e preprod -p cni.yml
  $0 -e preprod -p upgrade.yml --extra-vars "k8s_version=1.34.2-1.1"
  $0 -e preprod -p site.yml --check --diff
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--env)
      ENV="$2"
      shift 2
      ;;
    -p|--playbook)
      PLAYBOOK="$2"
      shift 2
      ;;
    -t|--tags)
      TAGS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

INVENTORY="${BASE_DIR}/inventory/${ENV}/hosts.ini"
PLAYBOOK_PATH="${BASE_DIR}/playbooks/${PLAYBOOK}"

if [[ ! -f "${INVENTORY}" ]]; then
  echo "Error: Inventory not found at ${INVENTORY}" >&2
  exit 1
fi

if [[ ! -f "${PLAYBOOK_PATH}" ]]; then
  echo "Error: Playbook not found at ${PLAYBOOK_PATH}" >&2
  exit 1
fi

CMD=(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK_PATH}")

if [[ -n "${TAGS}" ]]; then
  CMD+=(--tags "${TAGS}")
fi

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  CMD+=("${EXTRA_ARGS[@]}")
fi

echo "==> Running Ansible Playbook:"
echo "    Inventory: ${INVENTORY}"
echo "    Playbook:  ${PLAYBOOK_PATH}"
[[ -n "${TAGS}" ]] && echo "    Tags:      ${TAGS}"
echo "----------------------------------------------------"

cd "${BASE_DIR}"
exec "${CMD[@]}"

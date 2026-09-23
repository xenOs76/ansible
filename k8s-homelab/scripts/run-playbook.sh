#!/usr/bin/env bash
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
  -t, --tags      Ansible tags to execute (e.g. common, cri, cni, upgrade)
  -h, --help      Show this help message

Examples:
  $0 -e preprod -p site.yml
  $0 -e preprod -t "common,cri"
  $0 -e preprod -p cni.yml
  $0 -e preprod -p upgrade.yml --extra-vars "k8s_version=1.34.2-1.1"
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

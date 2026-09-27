#!/usr/bin/env bash
# ==============================================================================
# Script: shell.sh
# Purpose: Execute commands or open an interactive shell inside the reproducible
#          Nix development environment defined by k8s-homelab/shell.nix.
#
# Context:
#   Executed on the HOST machine. Encapsulates all external tool dependencies:
#   Vagrant (with libvirt provider), Ansible, ansible-lint, yamllint, and jq.
#   Ensures identical toolchain versions across all developer workstations and CI.
#
# Usage:
#   # 1. Interactive Nix shell session:
#   ./scripts/shell.sh
#
#   # 2. Run a specific command and exit:
#   ./scripts/shell.sh --run "vagrant status"
#   ./scripts/shell.sh --run "vagrant ssh kube-control-plane"
#
#   # 3. Compatibility mode for -c flags (e.g. from editor integrations or subshells):
#   ./scripts/shell.sh -c "vagrant provision"
#
# Key Features:
#   - Translates traditional '-c "<command>"' flags into 'nix-shell --run'.
#   - Automatically sets VAGRANT_DEFAULT_PROVIDER=libvirt and VAGRANT_HOME.
#   - Forwards all additional arguments directly to nix-shell.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_NIX="$SCRIPT_DIR/../shell.nix"

# Translate -c "command" to --run for nix-shell compatibility
if [[ "${1:-}" == "-c" ]]; then
  shift
  exec nix-shell "$SHELL_NIX" --run "$*"
fi

exec nix-shell "$SHELL_NIX" "$@"

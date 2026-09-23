#!/usr/bin/env bash
# Enter the nix-shell environment with Vagrant, Ansible, and libvirt support
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_NIX="$SCRIPT_DIR/../shell.nix"

# Translate -c "command" to --run for nix-shell compatibility
if [[ "${1:-}" == "-c" ]]; then
  shift
  exec nix-shell "$SHELL_NIX" --run "$*"
fi

exec nix-shell "$SHELL_NIX" "$@"

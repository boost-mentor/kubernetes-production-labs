#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KUBESPRAY_DIR="$ROOT_DIR/vendor/kubespray"
INV="$ROOT_DIR/inventory/video2/inventory.ini"
PLAYBOOK="$ROOT_DIR/.venv/bin/ansible-playbook"

[[ -x "$PLAYBOOK" && -f "$KUBESPRAY_DIR/cluster.yml" && -f "$INV" ]] || {
  echo "ERROR: run bootstrap, prepare-inventory and preflight first" >&2
  exit 1
}

"$PLAYBOOK" -i "$INV" "$KUBESPRAY_DIR/cluster.yml" -b

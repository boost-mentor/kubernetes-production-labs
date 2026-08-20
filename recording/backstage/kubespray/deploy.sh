#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
KUBESPRAY_DIR="$REPO_ROOT/kubespray/vendor/kubespray"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
PLAYBOOK="$REPO_ROOT/kubespray/.venv/bin/ansible-playbook"
RECORDING_ENV="$REPO_ROOT/recording/.recording.env"

if [[ -f "$RECORDING_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$RECORDING_ENV"
  set +a
fi
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"

[[ -x "$PLAYBOOK" && -f "$KUBESPRAY_DIR/cluster.yml" && -f "$INV" ]] || {
  echo "ERROR: run the backstage bootstrap, prepare-inventory and preflight helpers first" >&2
  exit 1
}
[[ -f "$SSH_KEY" ]] || { echo "ERROR: SSH key not found: $SSH_KEY" >&2; exit 1; }

echo "BACKSTAGE ONLY: REC uses the same ansible-playbook command directly."
cd "$KUBESPRAY_DIR"
"$PLAYBOOK" -i "$INV" cluster.yml -b --private-key "$SSH_KEY"

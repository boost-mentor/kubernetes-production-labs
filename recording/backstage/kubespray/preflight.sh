#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
ANSIBLE="$REPO_ROOT/kubespray/.venv/bin/ansible"
ANSIBLE_INVENTORY="$REPO_ROOT/kubespray/.venv/bin/ansible-inventory"
RECORDING_ENV="$REPO_ROOT/recording/.recording.env"

if [[ -f "$RECORDING_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$RECORDING_ENV"
  set +a
fi
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"

[[ -x "$ANSIBLE" && -x "$ANSIBLE_INVENTORY" ]] || {
  echo "ERROR: run $SCRIPT_DIR/bootstrap.sh" >&2
  exit 1
}
[[ -f "$INV" ]] || { echo "ERROR: run $SCRIPT_DIR/prepare-inventory.sh" >&2; exit 1; }
[[ -f "$SSH_KEY" ]] || { echo "ERROR: SSH key not found: $SSH_KEY" >&2; exit 1; }

"$ANSIBLE_INVENTORY" -i "$INV" --graph
"$ANSIBLE" -i "$INV" all --private-key "$SSH_KEY" -m ping
# shellcheck disable=SC2016 # This expression is intentionally evaluated by the remote shell.
"$ANSIBLE" -i "$INV" all --private-key "$SSH_KEY" -b -m shell -a \
  'test "$(swapon --show --noheadings | wc -l)" -eq 0; test "$(stat -fc %T /sys/fs/cgroup)" = cgroup2fs; ip -4 route show default'

echo "READY: SSH, sudo, swap=off, cgroup v2 and default routes"

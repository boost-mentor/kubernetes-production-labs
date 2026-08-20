#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
KIT_DIR="$REPO_ROOT/ansible/external-ha"
INVENTORY="$KIT_DIR/inventory.ini"
RECORDING_ENV="$REPO_ROOT/recording/.recording.env"

if [[ -f "$RECORDING_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$RECORDING_ENV"
  set +a
fi
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
export ANSIBLE_CONFIG="$KIT_DIR/ansible.cfg"

[[ -f "$INVENTORY" ]] || { echo "ERROR: run $SCRIPT_DIR/prepare-inventory.sh first" >&2; exit 2; }
[[ -f "$SSH_KEY" ]] || { echo "ERROR: SSH key not found: $SSH_KEY" >&2; exit 2; }
command -v ansible-inventory >/dev/null || { echo "ERROR: ansible-inventory not found" >&2; exit 2; }
command -v ansible >/dev/null || { echo "ERROR: ansible not found" >&2; exit 2; }
command -v ansible-playbook >/dev/null || { echo "ERROR: ansible-playbook not found" >&2; exit 2; }

ansible-inventory -i "$INVENTORY" --graph
ansible -i "$INVENTORY" all --private-key "$SSH_KEY" -m ping
ansible-playbook -i "$INVENTORY" "$KIT_DIR/site.yml" --private-key "$SSH_KEY" --syntax-check
ansible-playbook -i "$INVENTORY" "$KIT_DIR/preflight-backends.yml" --private-key "$SSH_KEY"
echo "PRE-FLIGHT OK: 5 VM доступны, 3 backend дают HTTP, Ansible syntax OK"

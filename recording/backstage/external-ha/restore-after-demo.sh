#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
KIT_DIR="$REPO_ROOT/ansible/external-ha"
INVENTORY="$KIT_DIR/inventory.ini"
STATE_FILE="$SCRIPT_DIR/.failed-active-host"
RECORDING_ENV="$REPO_ROOT/recording/.recording.env"

if [[ -f "$RECORDING_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$RECORDING_ENV"
  set +a
fi
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
HA_VIP="${HA_VIP:-10.77.0.10}"
HA_PORT="${HA_PORT:-8080}"
export ANSIBLE_CONFIG="$KIT_DIR/ansible.cfg"

[[ -f "$INVENTORY" ]] || { echo "ERROR: inventory not found: $INVENTORY" >&2; exit 2; }
[[ -f "$SSH_KEY" ]] || { echo "ERROR: SSH key not found: $SSH_KEY" >&2; exit 2; }

if [[ -f "$STATE_FILE" ]]; then
  failed_host=$(<"$STATE_FILE")
  [[ "$failed_host" == "lb1" || "$failed_host" == "lb2" ]] || {
    echo "ERROR: invalid failed-host marker: $failed_host" >&2
    exit 2
  }
  ansible "$failed_host" -i "$INVENTORY" --private-key "$SSH_KEY" -b -a "systemctl start haproxy"
else
  ansible load_balancers -i "$INVENTORY" --private-key "$SSH_KEY" -b -a "systemctl start haproxy"
fi
sleep 3
ansible load_balancers -i "$INVENTORY" --private-key "$SSH_KEY" -b -a "systemctl is-active haproxy keepalived"
ansible lb1 -i "$INVENTORY" --private-key "$SSH_KEY" -b -m uri -a "url=http://$HA_VIP:$HA_PORT/ status_code=200"
rm -f "$STATE_FILE"
echo "RESTORE OK"

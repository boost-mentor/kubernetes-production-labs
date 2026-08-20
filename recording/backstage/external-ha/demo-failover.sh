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

active=''
for host in lb1 lb2; do
  if ansible "$host" -i "$INVENTORY" --private-key "$SSH_KEY" -b -a "ip -4 addr show dev vxlan100" | grep -Fq "$HA_VIP/24"; then
    active=$host
    break
  fi
done
test -n "$active" || { echo "VIP $HA_VIP не найден" >&2; exit 1; }

echo "ACTIVE before failure: $active"
ansible "$active" -i "$INVENTORY" --private-key "$SSH_KEY" -b -a "systemctl stop haproxy"

new_active=''
for _attempt in {1..20}; do
  for host in lb1 lb2; do
    if [[ "$host" != "$active" ]] && \
      ansible "$host" -i "$INVENTORY" --private-key "$SSH_KEY" -b -a "ip -4 addr show dev vxlan100" | grep -Fq "$HA_VIP/24"; then
      new_active=$host
      break
    fi
  done
  if [[ -n "$new_active" ]] && \
    ansible lb1 -i "$INVENTORY" --private-key "$SSH_KEY" -b -m uri -a "url=http://$HA_VIP:$HA_PORT/ status_code=200" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

test -n "$new_active" || { echo "VIP не переехал с $active на второй LB" >&2; exit 1; }

ansible load_balancers -i "$INVENTORY" --private-key "$SSH_KEY" -b -a "ip -4 addr show dev vxlan100"
ansible lb1 -i "$INVENTORY" --private-key "$SSH_KEY" -b -m uri -a "url=http://$HA_VIP:$HA_PORT/ status_code=200"
echo "$active" > "$STATE_FILE"
echo "ACTIVE after failure: $new_active"
echo "FAILOVER OK: VIP переехал с $active на $new_active, HTTP восстановлен."
echo "Restore outside REC: $SCRIPT_DIR/restore-after-demo.sh"

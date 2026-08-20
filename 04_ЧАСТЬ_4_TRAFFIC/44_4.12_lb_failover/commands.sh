#!/usr/bin/env bash
# ЛАБА 4.12 · Failover внешнего LB: измеряем провал и переезд VIP
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

REPO_ROOT="$(git rev-parse --show-toplevel)"
HA_DIR="$REPO_ROOT/ansible/external-ha"
INV="$HA_DIR/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$REPO_ROOT/recording/.recording.env"
source "$REPO_ROOT/kubespray/.venv/bin/activate"

ACTIVE_LB=''
for host in lb1 lb2; do
  if ansible -i "$INV" "$host" --private-key "$SSH_KEY" --become \
    -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100' | \
    grep -q "$HA_VIP/24"; then
    ACTIVE_LB="$host"
  fi
done
test -n "$ACTIVE_LB"
printf '%s\n' "$ACTIVE_LB" > "$HA_DIR/.failed-active-host"
printf 'VIP owner before failure: %s\n' "$ACTIVE_LB"

# Второй терминал: оставить видимой прямую пробу и вернуться сюда.
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.shell \
  -a "for i in \$(seq 1 30); do printf '%s ' \"\$(date +%T)\"; curl --max-time 2 -sS -o /dev/null -w '%{http_code}\\n' http://$HA_VIP:$HA_PORT/readyz || echo timeout; sleep 1; done"

ansible -i "$INV" "$ACTIVE_LB" --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl stop haproxy'
sleep 6
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.shell \
  -a "journalctl -u keepalived --since '2 minutes ago' --no-pager | tail -20"
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"

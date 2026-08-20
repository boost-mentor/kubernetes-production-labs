#!/usr/bin/env bash
# ЛАБА 4.13 · Restore: оба LB active, VIP один, HTTP 200
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

REPO_ROOT="$(git rev-parse --show-toplevel)"
HA_DIR="$REPO_ROOT/ansible/external-ha"
INV="$HA_DIR/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$REPO_ROOT/recording/.recording.env"
source "$REPO_ROOT/kubespray/.venv/bin/activate"

FAILED_LB="$(cat "$HA_DIR/.failed-active-host")"
[[ "$FAILED_LB" == "lb1" || "$FAILED_LB" == "lb2" ]]
ansible -i "$INV" "$FAILED_LB" --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl start haproxy'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl is-active haproxy keepalived'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
rm -f "$HA_DIR/.failed-active-host"

# Из-за nopreempt VIP не обязан вернуться на lb1. Критерий восстановления:
# оба сервиса active, VIP ровно на одном LB, HTTP 200.

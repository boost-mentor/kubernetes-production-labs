#!/usr/bin/env bash
# ЛАБА 1.11 · Внешний HA-вход: VIP → keepalived/VRRP → HAProxy L4 → NodePort
# Выполнять ПО БЛОКАМ. Не запускать файл целиком.

REPO_ROOT="$(git rev-parse --show-toplevel)"
HA_DIR="$REPO_ROOT/ansible/external-ha"
INV="$HA_DIR/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
test -f "$REPO_ROOT/recording/.recording.env" && source "$REPO_ROOT/recording/.recording.env"
HA_VIP="${HA_VIP:-10.77.0.10}"
HA_PORT="${HA_PORT:-8080}"
source "$REPO_ROOT/kubespray/.venv/bin/activate"

# То же приложение публикуем NodePort 30080 для HAProxy backends.
kubectl --context kubespray apply -f "$REPO_ROOT/kubernetes/devops-may-cry/services/nodeport.yaml"
kubectl --context kubespray -n traffic-lab get service devops-may-cry-ha-nodeport
kubectl --context kubespray -n traffic-lab get endpointslice -l kubernetes.io/service-name=devops-may-cry-ha-nodeport -o wide

sed -n '1,180p' "$INV"
ansible-inventory -i "$INV" --graph
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.ping
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.setup \
  -a 'filter=ansible_default_ipv4'

sed -n '1,240p' "$HA_DIR/site.yml"
sed -n '1,220p' "$HA_DIR/roles/haproxy/templates/haproxy.cfg.j2"
sed -n '1,220p' "$HA_DIR/roles/keepalived/templates/keepalived.conf.j2"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" --syntax-check --private-key "$SSH_KEY"
ansible-playbook -i "$INV" "$HA_DIR/preflight-backends.yml" --private-key "$SSH_KEY"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" --private-key "$SSH_KEY"

ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl is-active haproxy keepalived'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"

ACTIVE_LB=''
for host in lb1 lb2; do
  if ansible -i "$INV" "$host" --private-key "$SSH_KEY" --become \
    -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100' | grep -q "$HA_VIP/24"; then
    ACTIVE_LB="$host"
  fi
done
test -n "$ACTIVE_LB"
printf 'VIP owner before failure: %s\n' "$ACTIVE_LB"

# Во втором терминале запусти эту прямую пробу и оставь её видимой:
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a "for i in \$(seq 1 30); do printf '%s ' \"\$(date +%T)\"; curl --max-time 2 -sS -o /dev/null -w '%{http_code}\\n' http://$HA_VIP:$HA_PORT/readyz || echo timeout; sleep 1; done"

ansible -i "$INV" "$ACTIVE_LB" --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl stop haproxy'
sleep 6
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a "journalctl -u keepalived --since '2 minutes ago' --no-pager | tail -20"
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"

ansible -i "$INV" "$ACTIVE_LB" --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl start haproxy'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl is-active haproxy keepalived'
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"
# Из-за nopreempt VIP после restore не обязан возвращаться на lb1. Важен HTTP 200 и оба сервиса active.

#!/usr/bin/env bash
# ЛАБА 4.11 · Внешний HA-вход: прямая установка HAProxy L4 + keepalived
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

REPO_ROOT="$(git rev-parse --show-toplevel)"
HA_DIR="$REPO_ROOT/ansible/external-ha"
INV="$HA_DIR/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
source "$REPO_ROOT/recording/.recording.env"
source "$REPO_ROOT/kubespray/.venv/bin/activate"

# MetalLB был отдельной реальной практикой. Теперь убираем его data plane,
# чтобы не выдавать две разные точки входа за одну схему.
kubectl --context kubespray -n traffic-lab delete service \
  devops-may-cry-metallb --ignore-not-found
helm --kube-context kubespray uninstall metallb -n metallb-system || true

kubectl --context kubespray apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context kubespray -n traffic-lab rollout status \
  deployment/devops-may-cry --timeout=180s
kubectl --context kubespray apply -f \
  "$REPO_ROOT/kubernetes/devops-may-cry/services/nodeport.yaml"
kubectl --context kubespray -n traffic-lab get service \
  devops-may-cry-ha-nodeport -o wide
kubectl --context kubespray -n traffic-lab get endpointslice \
  -l kubernetes.io/service-name=devops-may-cry-ha-nodeport -o wide

sed -n '1,180p' "$INV"
ansible-inventory -i "$INV" --graph
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.ping
ansible -i "$INV" all --private-key "$SSH_KEY" -m ansible.builtin.setup \
  -a 'filter=ansible_default_ipv4'

sed -n '1,240p' "$HA_DIR/site.yml"
sed -n '1,220p' "$HA_DIR/roles/haproxy/templates/haproxy.cfg.j2"
sed -n '1,220p' "$HA_DIR/roles/keepalived/templates/keepalived.conf.j2"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" \
  --syntax-check --private-key "$SSH_KEY"
ansible-playbook -i "$INV" "$HA_DIR/preflight-backends.yml" \
  --private-key "$SSH_KEY"
ansible-playbook -i "$INV" "$HA_DIR/site.yml" --private-key "$SSH_KEY"

ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'systemctl is-active haproxy keepalived'
ansible -i "$INV" load_balancers --private-key "$SSH_KEY" --become \
  -m ansible.builtin.command -a 'ip -4 addr show dev vxlan100'
ansible -i "$INV" lb1 --private-key "$SSH_KEY" --become \
  -m ansible.builtin.uri \
  -a "url=http://$HA_VIP:$HA_PORT/readyz status_code=200"

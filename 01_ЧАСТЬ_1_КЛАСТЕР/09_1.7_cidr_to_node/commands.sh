#!/usr/bin/env bash
# ЛАБА 1.7 · CIDR: по IP пода угадываем ноду
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/09_1.7_cidr_to_node"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/09_1.7_cidr_to_node"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"

kubectl --context kubespray get nodes \
  -o custom-columns='NODE:.metadata.name,INTERNAL-IP:.status.addresses[?(@.type=="InternalIP")].address,POD-CIDR:.spec.podCIDR'
# Node.spec.podCIDR и Calico IPAM block — не одно и то же.
kubectl --context kubespray get ippools.crd.projectcalico.org -o yaml | \
  grep -E 'cidr:|blockSize:|ipipMode:|vxlanMode:'
kubectl --context kubespray get blockaffinities.crd.projectcalico.org \
  -o custom-columns='NODE:.spec.node,CIDR:.spec.cidr,STATE:.spec.state'

kubectl --context kubespray apply -f "$LAB_DIR/calico-proof.yaml"
kubectl --context kubespray -n network-proof wait --for=condition=Ready pod --all --timeout=120s
kubectl --context kubespray -n network-proof get pods -o wide

POD_A_IP="$(kubectl --context kubespray -n network-proof get pod calico-a -o jsonpath='{.status.podIP}')"
POD_B_IP="$(kubectl --context kubespray -n network-proof get pod calico-b -o jsonpath='{.status.podIP}')"
kubectl --context kubespray -n network-proof exec calico-a -- ip address show eth0
kubectl --context kubespray -n network-proof exec calico-a -- ping -c 3 "$POD_B_IP"

source "$REPO_ROOT/kubespray/.venv/bin/activate"
ansible -i "$INV" node2 --private-key "$SSH_KEY" --become -m ansible.builtin.shell \
  -a "ip route get $POD_B_IP; ip -o link | grep cali | head; ip -d link show vxlan.calico || true"

kubectl --context kubespray get svc kubernetes
kubectl --context kubespray -n kube-system get svc kube-dns
kubectl --context kubespray delete namespace network-proof --wait=true

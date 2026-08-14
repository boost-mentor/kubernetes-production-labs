#!/usr/bin/env bash
# ЛАБА 4.11 · Внешний HA-вход: HAProxy L4 + keepalived/VRRP
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/43_4.11_external_ha_setup"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

# MetalLB был реальной практикой части 1. Перед отдельным внешним HA-этажом
# убираем его Service/data plane, чтобы не выдавать две точки входа за одну.
kubectl --context kubespray -n traffic-lab delete svc devops-may-cry-metallb --ignore-not-found
helm --kube-context kubespray uninstall metallb -n metallb-system --ignore-not-found

kubectl --context kubespray apply -k "$REPO_ROOT/00_DEVOPS_MAY_CRY_APP/k8s/base"
kubectl --context kubespray -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl --context kubespray apply -f ./lb-demo.yaml
kubectl --context kubespray -n traffic-lab get svc devops-may-cry-ha-nodeport -o wide

HA_DIR="$LAB_DIR/ha"
cd "$HA_DIR"
read -r -p "public IP lb1: " LB1_IP
read -r -p "public IP lb2: " LB2_IP
read -r -p "public IP node1: " NODE1_IP
read -r -p "public IP node2: " NODE2_IP
read -r -p "public IP node3: " NODE3_IP
./prepare-inventory.sh "$LB1_IP" "$LB2_IP" "$NODE1_IP" "$NODE2_IP" "$NODE3_IP" ~/.ssh/k8s_stand
./preflight.sh
ansible-playbook -i inventory.ini site.yml
./show-state.sh

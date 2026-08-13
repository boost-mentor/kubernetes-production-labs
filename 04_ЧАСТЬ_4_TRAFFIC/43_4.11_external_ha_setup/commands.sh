#!/usr/bin/env bash
# ЛАБА 1.12 · HAProxy L4 перед кластером: балансируем на NodePort
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl --context kubespray apply -k "$REPO_ROOT/00_NIGHT_SHIFT_APP/k8s/base"
kubectl --context kubespray -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl --context kubespray apply -f ./lb-demo.yaml
kubectl --context kubespray -n traffic-lab get svc night-shift-ha-nodeport -o wide

cd ha
read -r -p "public IP lb1: " LB1_IP
read -r -p "public IP lb2: " LB2_IP
read -r -p "public IP node1: " NODE1_IP
read -r -p "public IP node2: " NODE2_IP
read -r -p "public IP node3: " NODE3_IP
./prepare-inventory.sh "$LB1_IP" "$LB2_IP" "$NODE1_IP" "$NODE2_IP" "$NODE3_IP" ~/.ssh/k8s_stand
./preflight.sh
ansible-playbook -i inventory.ini site.yml
./show-state.sh

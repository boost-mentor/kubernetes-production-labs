#!/usr/bin/env bash
# ЛАБА 1.4-БИС · Подготовка трёх машин: то, из-за чего Kubespray падает на середине
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cd "$LAB_DIR/kubespray-kit"
./bootstrap.sh
read -r -p "public IP node1: " NODE1_PUBLIC_IP
read -r -p "public IP node2: " NODE2_PUBLIC_IP
read -r -p "public IP node3: " NODE3_PUBLIC_IP
read -r -p "path to SSH key: " SSH_KEY_PATH
./prepare-inventory.sh "$NODE1_PUBLIC_IP" "$NODE2_PUBLIC_IP" "$NODE3_PUBLIC_IP" "$SSH_KEY_PATH"
./preflight.sh
# Доказательство: public/floating IP нужен только для SSH, private IP сняты Ansible facts.
sed -n '1,80p' inventory/video2/inventory.ini

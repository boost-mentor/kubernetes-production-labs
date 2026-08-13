#!/usr/bin/env bash
# ЛАБА 1.4-БИС · Подготовка трёх машин: то, из-за чего Kubespray падает на середине
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/06_1.4bis_node_preflight"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

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

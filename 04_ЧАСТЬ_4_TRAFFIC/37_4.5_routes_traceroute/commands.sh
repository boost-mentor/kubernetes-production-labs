#!/usr/bin/env bash
# ЛАБА 4.5 · traceroute + таблица маршрутов: по маске выбирается интерфейс
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

route -n get default
read -r -p "public IP node1: " NODE1_PUBLIC_IP
route -n get "$NODE1_PUBLIC_IP"
traceroute -m 5 "$NODE1_PUBLIC_IP" || true

read -r -p "public IP node2: " NODE2_PUBLIC_IP
read -r -p "private IP node3: " NODE3_PRIVATE_IP
ssh "root@$NODE2_PUBLIC_IP" "ip -4 route; ip route get '$NODE3_PRIVATE_IP'"
# Мы читаем маршрут; системный VPN и routes не трогаем.

#!/usr/bin/env bash
# ЛАБА 1.7 · CIDR: по IP пода угадываем ноду
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/09_1.7_cidr_to_node"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
# → node1  10.233.64.0/24
#   node2  10.233.65.0/24
#   node3  10.233.66.0/24


kubectl get pods -A -o wide | head -15
# → сверь: третий октет IP пода = кусок его ноды


kubectl get svc kubernetes            # → ClusterIP 10.233.0.1 — ПЕРВЫЙ адрес Service CIDR
kubectl -n kube-system get svc        # → CoreDNS тоже из 10.233.0.0/18 (обычно .3 или .10 — проверь!)

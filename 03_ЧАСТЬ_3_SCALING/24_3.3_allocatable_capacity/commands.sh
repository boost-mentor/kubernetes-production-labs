#!/usr/bin/env bash
# ЛАБА 3.3 · Allocatable ≠ Capacity: куда делись гигабайты
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/24_3.3_allocatable_capacity"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl describe node node2 | grep -A8 'Capacity:'
# → Capacity: cpu … memory …  и ниже Allocatable: меньше!
kubectl get node node2 -o jsonpath='{.status.allocatable}'; echo

#!/usr/bin/env bash
# ЛАБА 3.3 · Allocatable ≠ Capacity: куда делись гигабайты
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl describe node node2 | grep -A8 'Capacity:'
# → Capacity: cpu … memory …  и ниже Allocatable: меньше!
kubectl get node node2 -o jsonpath='{.status.allocatable}'; echo

#!/usr/bin/env bash
# ЛАБА 2.3 · DB nodeAffinity: `IgnoredDuringExecution` вживую
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/16_2.3_node_affinity"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl -n traffic-lab get pod -l app=devops-may-cry-postgres -o wide
kubectl label node node3 workload.boostmentor.dev/tier-
kubectl -n traffic-lab get pod -l app=devops-may-cry-postgres -o wide
# → уже запущенный PostgreSQL остался на node3


kubectl -n traffic-lab delete pod -l app=devops-may-cry-postgres
kubectl -n traffic-lab get pod -l app=devops-may-cry-postgres -w
# → новый pod Pending: required affinity больше невыполнима (Ctrl+C)
kubectl label node node3 workload.boostmentor.dev/tier=database --overwrite
kubectl -n traffic-lab rollout status deploy/devops-may-cry-postgres --timeout=120s

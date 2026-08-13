#!/usr/bin/env bash
# ЛАБА 2.3 · DB nodeAffinity: `IgnoredDuringExecution` вживую
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl -n traffic-lab get pod -l app=night-shift-postgres -o wide
kubectl label node node3 workload.boostmentor.dev/tier-
kubectl -n traffic-lab get pod -l app=night-shift-postgres -o wide
# → уже запущенный PostgreSQL остался на node3


kubectl -n traffic-lab delete pod -l app=night-shift-postgres
kubectl -n traffic-lab get pod -l app=night-shift-postgres -w
# → новый pod Pending: required affinity больше невыполнима (Ctrl+C)
kubectl label node node3 workload.boostmentor.dev/tier=database --overwrite
kubectl -n traffic-lab rollout status deploy/night-shift-postgres --timeout=120s

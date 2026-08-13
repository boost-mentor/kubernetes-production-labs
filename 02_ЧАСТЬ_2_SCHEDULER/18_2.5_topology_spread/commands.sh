#!/usr/bin/env bash
# ЛАБА 2.5 · Night Shift topology spread: измеряем перекос
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl -n traffic-lab scale deploy night-shift --replicas=4
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab get pod -l app=night-shift -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
# → 2+2
kubectl -n traffic-lab scale deploy night-shift --replicas=5
kubectl -n traffic-lab get pod -l app=night-shift -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --sort-by=.spec.nodeName
# → 3+2, maxSkew=1


kubectl uncordon node3 2>/dev/null
kubectl -n traffic-lab scale deploy night-shift --replicas=2
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s

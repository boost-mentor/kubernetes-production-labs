#!/usr/bin/env bash
# ЛАБА 2.4 · Night Shift anti-affinity: доступность против жёсткости
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl apply -f ./night-shift.yaml
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab get pod -l app=night-shift -o wide
# → обе реплики живы на node2: preferred уступил доступности


kubectl -n traffic-lab delete deploy/night-shift-postgres svc/night-shift-postgres --ignore-not-found
kubectl -n traffic-lab delete secret/night-shift-db configmap/night-shift-db-init --ignore-not-found
kubectl taint node node3 dedicated=database:NoSchedule-
kubectl label node node3 workload.boostmentor.dev/tier-
kubectl -n traffic-lab rollout restart deploy/night-shift
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s
kubectl -n traffic-lab get pod -l app=night-shift -o wide
# → node2 + node3

kubectl -n traffic-lab patch deploy night-shift --type merge --patch-file ./required-anti-affinity-patch.yaml
kubectl -n traffic-lab scale deploy night-shift --replicas=3
kubectl -n traffic-lab get pod -l app=night-shift -o wide
# → две реплики Running на разных workers, третья Pending


kubectl apply -f ./night-shift.yaml
kubectl -n traffic-lab scale deploy night-shift --replicas=2
kubectl -n traffic-lab rollout status deploy/night-shift --timeout=180s

#!/usr/bin/env bash
# ЛАБА 3.4 · Overcommit: limits 200% — это нормально (пока не проснулись все)
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./requests_limits.yaml
kubectl -n traffic-lab scale deploy/night-shift-burstable --replicas=12
kubectl -n traffic-lab rollout status deploy/night-shift-burstable --timeout=180s
for node in node2 node3; do
  echo "=== $node"
  kubectl describe node "$node" | sed -n '/Allocated resources:/,/Events:/p'
done
# Requests должны помещаться; сумма limits может быть выше 100%. Это риск,
# который принимают осознанно вместе с наблюдаемостью и capacity policy.
kubectl -n traffic-lab scale deploy/night-shift-burstable --replicas=1

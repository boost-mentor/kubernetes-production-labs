#!/usr/bin/env bash
# ЛАБА 3.4 · Overcommit: limits 200% — это нормально (пока не проснулись все)
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/25_3.4_overcommit"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./requests_limits.yaml
kubectl -n traffic-lab scale deploy/devops-may-cry-burstable --replicas=12
kubectl -n traffic-lab rollout status deploy/devops-may-cry-burstable --timeout=180s
for node in node2 node3; do
  echo "=== $node"
  kubectl describe node "$node" | sed -n '/Allocated resources:/,/Events:/p'
done
# Requests должны помещаться; сумма limits может быть выше 100%. Это риск,
# который принимают осознанно вместе с наблюдаемостью и capacity policy.
kubectl -n traffic-lab scale deploy/devops-may-cry-burstable --replicas=1

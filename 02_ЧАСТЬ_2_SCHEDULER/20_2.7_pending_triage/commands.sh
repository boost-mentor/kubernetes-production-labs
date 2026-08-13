#!/usr/bin/env bash
# ЛАБА 2.7 · Рефлекс «под в Pending»: читаем, а не гадаем
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

kubectl create namespace pending-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl -n pending-lab run stuck-selector --image=nginx:1.27 --overrides='{"spec":{"nodeSelector":{"disktype":"nvme"}}}'
kubectl -n pending-lab run stuck-resources --image=nginx:1.27 --overrides='{"spec":{"containers":[{"name":"stuck-resources","image":"nginx:1.27","resources":{"requests":{"cpu":"64","memory":"200Gi"}}}]}}'
kubectl taint nodes node2 maintenance=true:NoSchedule
kubectl taint nodes node3 maintenance=true:NoSchedule
kubectl -n pending-lab run stuck-taint --image=nginx:1.27
kubectl -n pending-lab get pods
for pod in stuck-selector stuck-resources stuck-taint; do
  echo "=== $pod"; kubectl -n pending-lab describe pod "$pod" | sed -n '/Events:/,$p'
done
kubectl taint nodes node2 maintenance=true:NoSchedule-
kubectl taint nodes node3 maintenance=true:NoSchedule-
kubectl delete namespace pending-lab

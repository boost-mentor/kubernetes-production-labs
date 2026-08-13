#!/usr/bin/env bash
# ЛАБА 2.2 · Выделенная DB-нода: taint — это вход по пропускам
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/02_ЧАСТЬ_2_SCHEDULER/15_2.2_taint_toleration"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl describe node node1 | grep -i taint     # → встроенный control-plane:NoSchedule
kubectl label node node3 workload.boostmentor.dev/tier=database --overwrite
kubectl taint node node3 dedicated=database:NoSchedule

read -r -s -p 'temporary DB password: ' DB_PASSWORD; echo
kubectl -n traffic-lab create secret generic night-shift-db \
  --from-literal=POSTGRES_DB=nightshift \
  --from-literal=POSTGRES_USER=nightshift \
  --from-literal=POSTGRES_PASSWORD="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
unset DB_PASSWORD

kubectl apply -f ./postgres-pending.yaml
kubectl -n traffic-lab get pod -l app=night-shift-postgres -o wide
kubectl -n traffic-lab describe pod -l app=night-shift-postgres | sed -n '/Events:/,$p'
# → Pending: pod требует database-ноду, но не tolerates dedicated=database:NoSchedule


kubectl -n traffic-lab create configmap night-shift-db-init \
  --from-file=001_init.sql=./001_init.sql \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ./postgres-scheduled.yaml
kubectl -n traffic-lab rollout status deploy/night-shift-postgres --timeout=120s
kubectl -n traffic-lab get pod -l app=night-shift-postgres -o wide
# → Running на node3

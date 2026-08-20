#!/usr/bin/env bash
# ЛАБА 3.8 · Детерминированный Evicted: OOMKill ≠ Eviction
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/29_3.8_eviction"
cd "$LAB_DIR" || exit

kubectl create namespace traffic-lab --dry-run=client -o yaml | kubectl apply -f -

# До: нода здорова. Мы не будем забивать всю её память или диск.
kubectl get nodes -o custom-columns='NAME:.metadata.name,MEMORY:.status.conditions[?(@.type=="MemoryPressure")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,PID:.status.conditions[?(@.type=="PIDPressure")].status'

# Действие ограничено одним Pod: он пишет 64 MiB в emptyDir с sizeLimit 16 MiB.
sed -n '1,220p' ./eviction-demo.yaml
kubectl apply -f ./eviction-demo.yaml

# После: Pod Failed/Reason=Evicted, а container Last State не OOMKilled.
# На медленном kubelet проверка ephemeral storage может занять 1–2 минуты.
kubectl -n traffic-lab wait \
  --for=jsonpath='{.status.reason}'=Evicted \
  pod/ephemeral-storage-hog --timeout=300s
kubectl -n traffic-lab get pod ephemeral-storage-hog \
  -o jsonpath='phase={.status.phase}{" reason="}{.status.reason}{"\nmessage="}{.status.message}{"\n"}'
test "$(kubectl -n traffic-lab get pod ephemeral-storage-hog \
  -o jsonpath='{.status.reason}')" = "Evicted"
kubectl -n traffic-lab get events \
  --field-selector involvedObject.name=ephemeral-storage-hog \
  --sort-by=.lastTimestamp

# Restore только этот Pod. Не удаляем все Failed-поды кластера.
kubectl -n traffic-lab delete pod ephemeral-storage-hog --ignore-not-found

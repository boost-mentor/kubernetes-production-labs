#!/usr/bin/env bash
# ЛАБА 1.6 · прямая проверка: «ноды живы» ≠ «кластер работает»
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/08_1.6_verify_cluster"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

kubectl --context kubespray get nodes -o wide
kubectl --context kubespray get --raw='/readyz?verbose' | tail -12
kubectl --context kubespray -n kube-system get pods -o wide
kubectl --context kubespray -n kube-system get daemonset calico-node
kubectl --context kubespray -n kube-system get deployment coredns

kubectl --context kubespray apply -k "$REPO_ROOT/kubernetes/devops-may-cry/base"
kubectl --context kubespray -n traffic-lab rollout status deployment/devops-may-cry --timeout=180s
kubectl --context kubespray -n traffic-lab get pods,service,endpointslice -o wide

kubectl --context kubespray -n traffic-lab run verify-client \
  --image=curlimages/curl:8.12.1 --restart=Never --command -- sleep 3600
kubectl --context kubespray -n traffic-lab wait --for=condition=Ready pod/verify-client --timeout=120s
kubectl --context kubespray -n traffic-lab exec verify-client -- \
  curl -fsS http://devops-may-cry/readyz
kubectl --context kubespray -n traffic-lab delete pod verify-client --wait=true

kubectl --context kubespray get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -12

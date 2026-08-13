#!/usr/bin/env bash
# ЛАБА 3.0 · Metrics Server: почему Helm, а не `kubectl apply` (и что такое `--kubelet-insecure-tls`)
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cp ./addons-metrics-server.yml "$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/07_1.5_kubespray_full/kubespray-kit/inventory/video2/group_vars/k8s_cluster/addons.yml"
cd "$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/07_1.5_kubespray_full/kubespray-kit"
./deploy.sh
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
kubectl top nodes
# Если kubelet serving certificate не проходит проверку, исправляем SAN/CSR;
# --kubelet-insecure-tls в production-маршрут не добавляем.

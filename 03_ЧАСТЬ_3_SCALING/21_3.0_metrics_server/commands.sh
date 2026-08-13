#!/usr/bin/env bash
# ЛАБА 3.0 · Metrics Server: почему Helm, а не `kubectl apply` (и что такое `--kubelet-insecure-tls`)
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/21_3.0_metrics_server"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

KUBESPRAY_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/06_1.4bis_node_preflight/kubespray-kit"
cp ./addons-metrics-server.yml "$KUBESPRAY_DIR/inventory/video2/group_vars/k8s_cluster/addons.yml"
cd "$KUBESPRAY_DIR"
./deploy.sh
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s
kubectl top nodes
# Если kubelet serving certificate не проходит проверку, исправляем SAN/CSR;
# --kubelet-insecure-tls в production-маршрут не добавляем.

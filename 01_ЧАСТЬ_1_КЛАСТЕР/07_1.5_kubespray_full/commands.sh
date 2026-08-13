#!/usr/bin/env bash
# ЛАБА 1.5 · Kubespray full: из трёх Linux-машин — кластер
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cd "$LAB_DIR/kubespray-kit"
./bootstrap.sh
sed -n '1,220p' vendor/kubespray/cluster.yml
find vendor/kubespray/roles -maxdepth 1 -mindepth 1 -type d | head -20
sed -n '1,120p' inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml
./deploy.sh
./verify.sh

# Kubespray сохранил настоящий CA и сертификат с public SAN — TLS не отключаем.
KUBECONFIG_FILE="inventory/video2/artifacts/admin.conf"
mkdir -p ~/.kube
KUBECONFIG="$HOME/.kube/config:$KUBECONFIG_FILE" kubectl config view --flatten > /tmp/video2-kubeconfig
install -m 0600 /tmp/video2-kubeconfig "$HOME/.kube/config"
kubectl config rename-context kubernetes-admin@cluster.local kubespray 2>/dev/null || true
kubectl --context kubespray get nodes -o wide

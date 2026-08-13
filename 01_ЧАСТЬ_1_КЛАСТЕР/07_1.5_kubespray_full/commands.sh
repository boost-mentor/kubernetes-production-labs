#!/usr/bin/env bash
# ЛАБА 1.5 · Kubespray full: из трёх Linux-машин — кластер
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/07_1.5_kubespray_full"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

KUBESPRAY_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/06_1.4bis_node_preflight/kubespray-kit"
cd "$KUBESPRAY_DIR"
./bootstrap.sh
test -f inventory/video2/inventory.ini || {
  echo "Сначала выполни лабу 1.4-БИС: она создаёт inventory из IP стенда" >&2
  return 1 2>/dev/null || exit 1
}
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

#!/usr/bin/env bash
# ЛАБА 1.5 · Kubespray full: из трёх Linux-машин — кластер
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

REPO_ROOT="$(git rev-parse --show-toplevel)"
KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
UPSTREAM="$KUBESPRAY_ROOT/vendor/kubespray"
INV="$KUBESPRAY_ROOT/inventory/video2/inventory.ini"
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"
PLAYBOOK="$KUBESPRAY_ROOT/.venv/bin/ansible-playbook"

sed -n '1,220p' "$UPSTREAM/cluster.yml"
sed -n '1,220p' "$UPSTREAM/playbooks/cluster.yml"
sed -n '1,200p' "$KUBESPRAY_ROOT/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml"
find "$UPSTREAM/roles" -mindepth 1 -maxdepth 1 -type d -print | sort | sed -n '1,24p'

"$PLAYBOOK" -i "$INV" "$UPSTREAM/cluster.yml" \
  --become --private-key "$SSH_KEY"

# Kubespray сохранил настоящий CA и сертификат с public SAN — TLS не отключаем.
KUBECONFIG_FILE="$KUBESPRAY_ROOT/inventory/video2/artifacts/admin.conf"
OLD_CONTEXT="$(KUBECONFIG="$KUBECONFIG_FILE" kubectl config current-context)"
KUBECONFIG="$KUBECONFIG_FILE" kubectl config rename-context "$OLD_CONTEXT" kubespray
mkdir -p ~/.kube
KUBECONFIG="$HOME/.kube/config:$KUBECONFIG_FILE" kubectl config view --flatten > /tmp/video2-kubeconfig
install -m 0600 /tmp/video2-kubeconfig "$HOME/.kube/config"
kubectl --context kubespray get nodes -o wide

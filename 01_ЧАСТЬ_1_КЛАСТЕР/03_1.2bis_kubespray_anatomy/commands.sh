#!/usr/bin/env bash
# ЛАБА 1.2-БИС · Kubespray — большой Ansible-проект с обычными playbook и roles
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

REPO_ROOT="$(git rev-parse --show-toplevel)"
KUBESPRAY_ROOT="$REPO_ROOT/kubespray"
UPSTREAM="$KUBESPRAY_ROOT/vendor/kubespray"
cd "$REPO_ROOT"

cat "$KUBESPRAY_ROOT/VERSION"
test -f "$UPSTREAM/cluster.yml"
sed -n '1,180p' "$UPSTREAM/cluster.yml"
find "$UPSTREAM/roles" -mindepth 1 -maxdepth 1 -type d -print | sort | sed -n '1,24p'
sed -n '1,180p' "$KUBESPRAY_ROOT/inventory/video2/inventory.example.ini"
sed -n '1,180p' "$KUBESPRAY_ROOT/inventory/video2/group_vars/k8s_cluster/k8s-cluster.yml"

#!/usr/bin/env bash
# ЛАБА 1.4 · Managed-кластер через terraform apply
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/05_1.4_managed_cluster"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

cd "$LAB_DIR/terraform"
cp terraform.tfvars.example terraform.tfvars
# Заполни folder_id, service_account_id, public_key и разрешённые CIDR.
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out=managed.tfplan
terraform apply managed.tfplan

yc managed-kubernetes cluster list
yc managed-kubernetes node-group list
yc managed-kubernetes cluster get-credentials k8s-managed --external --force
kubectl config rename-context "$(kubectl config current-context)" yc-managed
kubectl --context yc-managed get nodes -o wide
# В браузере: Yandex Cloud -> Managed Service for Kubernetes -> Nodes.
# Этот стенд нужен в Ч3 для Cluster Autoscaler, поэтому здесь не destroy.

#!/usr/bin/env bash
# ЛАБА 1.4 · Managed-кластер через terraform apply
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/05_1.4_managed_cluster"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

cd "$REPO_ROOT/infra/managed/terraform"
test -f private.auto.tfvars || cp private.auto.tfvars.example private.auto.tfvars
# До REC укажи в private.auto.tfvars свой public IP /32.
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
terraform apply

yc managed-kubernetes cluster list
yc managed-kubernetes node-group list
terraform output cidrs
$(terraform output -raw get_credentials_command)
kubectl config rename-context "$(kubectl config current-context)" yc-managed
kubectl --context yc-managed get nodes -o wide
# В браузере: Yandex Cloud -> Managed Service for Kubernetes -> Nodes.
# Этот стенд нужен в Ч3 для Cluster Autoscaler, поэтому здесь не destroy.

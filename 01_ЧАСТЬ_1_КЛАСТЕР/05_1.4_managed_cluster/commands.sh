#!/usr/bin/env bash
# ЛАБА 1.4 · Managed-кластер через terraform apply
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cd ../terraform_yandex_managed
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan        # → ~10 ресурсов: сеть, сервисный аккаунт, IAM-роли, кластер, node group
terraform apply       # yes, ~10 минут — запусти и иди дальше по тетради


yc managed-kubernetes cluster list                                   # → k8s-managed  RUNNING
yc managed-kubernetes cluster get-credentials k8s-managed --external --force
kubectl config rename-context $(kubectl config current-context) yc-managed
kubectl --context yc-managed get nodes    # → 2 ноды, ROLES <none>  ← мастера в списке НЕТ

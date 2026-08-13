#!/usr/bin/env bash
# ЛАБА 1.3 · Три ВМ кодом: terraform вместо кликов в консоли
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cd "$LAB_DIR/terraform"
cp terraform.tfvars.example terraform.tfvars
# Перед командой укажи свой public IP /32 и SSH public key.
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out=video2.tfplan
terraform apply video2.tfplan
terraform output nodes
terraform output -raw kubespray_inventory > /tmp/video2-kubespray.ini
cat /tmp/video2-kubespray.ini
yc compute instance list

# Это временная демонстрация «тот же стенд кодом». Основная лаба уже живёт
# в BoostMentor, поэтому после сравнения платные VM удаляем.
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan

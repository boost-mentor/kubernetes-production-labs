#!/usr/bin/env bash
# ЛАБА 1.3 · Три ВМ кодом: terraform вместо кликов в консоли
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/04_1.3_five_vm_terraform"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

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
# У Terraform-VM cloud user задаётся переменной (по умолчанию ubuntu).
# У BoostMentor lesson-VM ниже — root. Это два стенда одинаковой формы,
# но inventory нельзя смешивать после destroy демонстрационного стенда.

# Это временная демонстрация «тот же стенд кодом». Основная лаба уже живёт
# в BoostMentor, поэтому после сравнения платные VM удаляем.
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan

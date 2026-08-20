#!/usr/bin/env bash
# ЛАБА 1.3 · Пять ВМ кодом: Terraform вместо кликов в консоли
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/04_1.3_five_vm_terraform"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

cd "$REPO_ROOT/infra/self-managed/terraform"
test -f terraform.tfvars || cp terraform.tfvars.example terraform.tfvars
# Перед командой укажи свой public IP /32 и SSH public key.
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
terraform apply
terraform output nodes
mkdir -p "$REPO_ROOT/kubespray/inventory/video2/group_vars/all"
terraform output -raw kubespray_inventory > "$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
terraform output -raw kubespray_all_yml > "$REPO_ROOT/kubespray/inventory/video2/group_vars/all/all.yml"
terraform output -raw external_ha_inventory > "$REPO_ROOT/ansible/external-ha/inventory.ini"
sed -n '1,120p' "$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
sed -n '1,80p' "$REPO_ROOT/kubespray/inventory/video2/group_vars/all/all.yml"
sed -n '1,120p' "$REPO_ROOT/ansible/external-ha/inventory.ini"
yc compute instance list
# Эти пять VM не уничтожаем: на node1-node3 дальше идёт Kubespray,
# а lb1/lb2 используются в сцене внешнего HA. Destroy — только после REC.

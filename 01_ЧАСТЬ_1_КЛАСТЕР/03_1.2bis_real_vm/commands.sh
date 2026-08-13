#!/usr/bin/env bash
# ЛАБА 1.2-БИС · Одна НАСТОЯЩАЯ ВМ: Terraform создал → Ansible настроил
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cd "$LAB_DIR"
# Credentials приходят из secret manager/текущей shell, не из репозитория.
test -n "${OS_AUTH_URL:-}" && test -n "${OS_PASSWORD:-}" && test -n "${TF_VAR_network_id:-}"
terraform init
terraform validate
terraform plan -out=vm.tfplan
terraform apply vm.tfplan
VM_IP="$(terraform output -raw vm_ip)"; echo "$VM_IP"

printf '[demo_vm]
%s ansible_user=root
' "$VM_IP" > vm_inventory.ini
ansible -i vm_inventory.ini all -m ping
ansible-playbook -i vm_inventory.ini site_vm.yml
open "http://$VM_IP/"
ansible-playbook -i vm_inventory.ini site_vm.yml

terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan

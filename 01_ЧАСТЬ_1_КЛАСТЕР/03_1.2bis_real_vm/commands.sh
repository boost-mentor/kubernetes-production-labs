#!/usr/bin/env bash
# ЛАБА 1.2-БИС · Одна НАСТОЯЩАЯ ВМ: Terraform создал → Ansible настроил
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/03_1.2bis_real_vm"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

cd "$LAB_DIR"
# Credentials приходят из secret manager/текущей shell, не из репозитория.
test -n "${OS_AUTH_URL:-}" && test -n "${OS_PASSWORD:-}" && test -n "${TF_VAR_network_id:-}"
terraform init
terraform validate
terraform plan -out=vm.tfplan
terraform apply vm.tfplan
VM_IP="$(terraform output -raw vm_ip)"; echo "$VM_IP"
SSH_USER="$(terraform output -raw ssh_user)"; echo "$SSH_USER"
SSH_KEY="$HOME/.ssh/video2_recording"
test -f "$SSH_KEY" || { echo "missing private key: $SSH_KEY" >&2; return 1 2>/dev/null || exit 1; }
chmod 0600 "$SSH_KEY"

printf '[demo_vm]
%s ansible_user=%s ansible_ssh_private_key_file=%s
'   "$VM_IP" "$SSH_USER" "$SSH_KEY" > vm_inventory.ini
ansible -i vm_inventory.ini all -m ping
ansible-playbook -i vm_inventory.ini site_vm.yml
open "http://$VM_IP/"
ansible-playbook -i vm_inventory.ini site_vm.yml

terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan

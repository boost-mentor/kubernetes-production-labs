# Self-managed Kubernetes stand — Terraform

Один root module создаёт сеть, подсеть, security group и вызывает typed child
module `modules/k8s_nodes` для пяти VM: `node1`–`node3` и `lb1`–`lb2`.
Стабильные ключи `for_each` не сдвигают адреса ресурсов при изменении карты.

## Структура

- `versions.tf` — версии Terraform и провайдера;
- `providers.tf` — provider без токенов в коде;
- `variables.tf` / `terraform.tfvars.example` — входной контракт;
- `locals.tf` — состав и роли пяти VM;
- `network.tf` / `security_groups.tf` — сеть и доступ;
- `compute.tf` — вызов переиспользуемого модуля;
- `outputs.tf` — IP, SSH и готовый Kubespray inventory;
- `modules/k8s_nodes/` — cohesive typed module;
- `backend.s3.tf.example` — production-pattern удалённого state, не активен в lab.

## Безопасный цикл записи

```bash
cp terraform.tfvars.example terraform.tfvars
# Укажи свой публичный IP /32 и правильный SSH public key.
export YC_TOKEN="$(yc iam create-token)"
export YC_CLOUD_ID="$(yc config get cloud-id)"
export YC_FOLDER_ID="$(yc config get folder-id)"

terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out=video2.tfplan
terraform apply video2.tfplan
terraform output kubespray_inventory

# После сравнения с уже созданной учебной лабораторией:
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

`terraform.tfvars`, state и plan содержат чувствительные данные и не попадают в
git. В production state должен жить в отдельном versioned/encrypted bucket с
locking и отдельным ключом на окружение; credentials приходят из CI/Vault/OIDC,
а не из `.tf`.

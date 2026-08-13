# ХЕЛЛО-ОБЛАКО: ОДНА реальная ВМ в Selectel — «то, что кнопка платформы и клики
# в консоли делают под капотом». Минимальный пример под кадр C1.1.
#
# АУТЕНТИФИКАЦИЯ (перед запуском, значения из deploy/secrets.env платформы):
#   export OS_AUTH_URL=$SELECTEL_AUTH_URL           # https://cloud.api.selcloud.ru/identity/v3
#   export OS_USER_ID=$SELECTEL_SERVICE_USER_ID
#   export OS_PASSWORD=$SELECTEL_SERVICE_USER_PASSWORD
#   export OS_PROJECT_ID=$SELECTEL_PROJECT_ID
#   export OS_REGION_NAME=$SELECTEL_REGION
#   export OS_USER_DOMAIN_NAME=$SELECTEL_ACCOUNT_ID
#   export TF_VAR_flavor_id=$SELECTEL_FLAVOR_2VCPU_4GB
#   export TF_VAR_image_id=$SELECTEL_IMAGE_UBUNTU2404
#   export TF_VAR_network_id=$SELECTEL_LAB_NET_ID
#   (готовый блок export-ов: source ../../scripts/selectel_env.sh)
#
# В КАДРЕ: terraform init → plan (читаем: + create 1 ресурс) → apply → output ip
# После демо: terraform destroy (ВМ платная!)

terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.4.0" # Selectel — это OpenStack: тот же провайдер
    }
  }
}

provider "openstack" {} # всё берёт из OS_* переменных окружения — секретов в коде нет

variable "flavor_id" { type = string } # размер машины (2 vCPU / 4 ГБ)
variable "image_id" { type = string }  # образ Ubuntu 24.04
variable "network_id" { type = string }

resource "openstack_compute_instance_v2" "demo" {
  name      = "hello-terraform-vm"
  flavor_id = var.flavor_id
  network {
    uuid = var.network_id
  }
  block_device { # диск из образа: у Selectel машины бутуются с сетевого диска
    uuid                  = var.image_id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 10
    delete_on_termination = true # снесли ВМ — снесли и диск, мусора не остаётся
  }
}

output "vm_ip" {
  value = openstack_compute_instance_v2.demo.access_ip_v4
}

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
# В КАДРЕ: terraform init → plan (VM + keypair + SG + floating IP) → apply → output ip
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
variable "external_network_name" {
  description = "Имя внешней сети/пула floating IP в текущем OpenStack project"
  type        = string
}
variable "ssh_public_key" {
  description = "Публичная часть временного recording key; private key в Terraform не попадает"
  type        = string
}
variable "allowed_ingress_cidr" {
  description = "Текущий public IP ноутбука /32 для SSH и HTTP"
  type        = string
  validation {
    condition     = can(cidrhost(var.allowed_ingress_cidr, 0)) && var.allowed_ingress_cidr != "0.0.0.0/0" && var.allowed_ingress_cidr != "::/0"
    error_message = "Укажи ограниченный CIDR, например 203.0.113.42/32."
  }
}
variable "ssh_user" {
  description = "Default cloud user выбранного Ubuntu image"
  type        = string
  default     = "ubuntu"
}

resource "openstack_compute_keypair_v2" "demo" {
  name       = "video2-recording"
  public_key = var.ssh_public_key
}

resource "openstack_networking_secgroup_v2" "demo" {
  name        = "video2-recording"
  description = "Recording demo: SSH and NIGHT SHIFT only from one trusted CIDR"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ingress_cidr
  security_group_id = openstack_networking_secgroup_v2.demo.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.allowed_ingress_cidr
  security_group_id = openstack_networking_secgroup_v2.demo.id
}

resource "openstack_networking_floatingip_v2" "demo" {
  pool = var.external_network_name
}

resource "openstack_compute_instance_v2" "demo" {
  name            = "hello-terraform-vm"
  flavor_id       = var.flavor_id
  key_pair        = openstack_compute_keypair_v2.demo.name
  security_groups = [openstack_networking_secgroup_v2.demo.name]
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

resource "openstack_networking_floatingip_associate_v2" "demo" {
  floating_ip = openstack_networking_floatingip_v2.demo.address
  port_id     = openstack_compute_instance_v2.demo.network[0].port
}

output "vm_ip" {
  value = openstack_networking_floatingip_v2.demo.address
}

output "ssh_user" {
  value = var.ssh_user
}

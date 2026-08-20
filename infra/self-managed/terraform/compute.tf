# Образ ОС общий для всех нод. Модуль получает уже выбранный image_id.
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

# Cohesive typed module: root передаёт карту нод, сеть и общие настройки;
# for_each и устройство каждой ВМ инкапсулированы внутри модуля.
module "k8s_nodes" {
  source = "./modules/k8s_nodes"

  cluster_name       = var.cluster_name
  nodes              = local.nodes
  zone               = var.zone
  image_id           = data.yandex_compute_image.ubuntu.id
  subnet_id          = yandex_vpc_subnet.this.id
  security_group_ids = [yandex_vpc_security_group.k8s.id]
  ssh_user           = var.ssh_user
  ssh_public_key     = file(pathexpand(var.ssh_public_key_path))
}

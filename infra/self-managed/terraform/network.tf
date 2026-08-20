# Сеть и подсеть под ноды кластера.
resource "yandex_vpc_network" "this" {
  name = "${var.cluster_name}-net"
}

resource "yandex_vpc_subnet" "this" {
  name           = "${var.cluster_name}-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.vpc_cidr]
}

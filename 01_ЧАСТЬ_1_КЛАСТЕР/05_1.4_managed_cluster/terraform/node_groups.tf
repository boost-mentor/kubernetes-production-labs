resource "yandex_kubernetes_node_group" "workers" {
  cluster_id = yandex_kubernetes_cluster.this.id
  name       = "${var.cluster_name}-workers"
  version    = var.k8s_version
  # ⚠️ Правило Яндекса: версия группы узлов НЕ МОЖЕТ быть выше версии мастера,
  # и разница не более ДВУХ минорных (в ванильном k8s допускается три).

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores  = 2
      memory = 4
    }

    boot_disk {
      type = "network-ssd"
      size = 30
    }

    network_interface {
      nat                = true
      subnet_ids         = [yandex_vpc_subnet.this.id]
      security_group_ids = [yandex_vpc_security_group.k8s.id]
    }

    scheduling_policy { preemptible = false }

    container_runtime { type = "containerd" }
  }

  scale_policy {
    dynamic "fixed_scale" {
      for_each = var.enable_autoscaling ? [] : [1]
      content {
        size = var.node_count
      }
    }

    dynamic "auto_scale" {
      for_each = var.enable_autoscaling ? [1] : []
      content {
        min     = var.autoscaling_min_nodes
        max     = var.autoscaling_max_nodes
        initial = var.node_count
      }
    }
  }

  allocation_policy {
    location { zone = var.zone }
  }

  maintenance_policy {
    auto_upgrade = false # для стенда — контролируем момент апгрейда сами
    auto_repair  = true
  }
}

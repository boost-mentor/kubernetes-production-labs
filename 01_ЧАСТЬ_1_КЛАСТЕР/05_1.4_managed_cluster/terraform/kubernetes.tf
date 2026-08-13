resource "yandex_kubernetes_cluster" "this" {
  name       = var.cluster_name
  network_id = yandex_vpc_network.this.id

  master {
    version = var.k8s_version

    # Зональный мастер — для стенда. Для прода: regional{} с тремя зонами.
    master_location {
      zone      = var.zone
      subnet_id = yandex_vpc_subnet.this.id
    }

    public_ip = true # чтобы ходить kubectl'ом снаружи

    security_group_ids = [yandex_vpc_security_group.k8s.id]

    maintenance_policy {
      auto_upgrade = false # ⚠️ для стенда выключаем: не хотим сюрпризов на записи
      # В канале RAPID выключить НЕЛЬЗЯ — только REGULAR/STABLE.
    }
  }

  # Pod CIDR и Service CIDR. Здесь они задаются терраформом,
  # в self-managed это делает Kubespray в group_vars — сравнить в кадре.
  cluster_ipv4_range = var.cluster_ipv4_range
  service_ipv4_range = var.service_ipv4_range

  service_account_id      = yandex_iam_service_account.cluster.id
  node_service_account_id = yandex_iam_service_account.nodes.id

  release_channel = var.release_channel

  depends_on = [
    yandex_resourcemanager_folder_iam_member.cluster_editor,
    yandex_resourcemanager_folder_iam_member.cluster_lb,
    yandex_resourcemanager_folder_iam_member.nodes_puller,
  ]
}

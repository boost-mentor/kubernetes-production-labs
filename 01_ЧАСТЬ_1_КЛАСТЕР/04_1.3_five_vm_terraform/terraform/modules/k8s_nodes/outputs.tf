output "nodes" {
  description = "Ноды с адресами и ролями для следующего слоя автоматизации"
  value = {
    for name, instance in yandex_compute_instance.this : name => {
      external_ip = instance.network_interface[0].nat_ip_address
      internal_ip = instance.network_interface[0].ip_address
      role        = var.nodes[name].role
      instance_id = instance.id
    }
  }
}

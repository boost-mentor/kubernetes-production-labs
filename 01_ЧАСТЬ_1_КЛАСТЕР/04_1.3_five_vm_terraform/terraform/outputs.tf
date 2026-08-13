output "nodes" {
  description = "Все пять VM: node1-node3 + lb1-lb2"
  value       = module.k8s_nodes.nodes
}

# ⭐ Главный output: готовый inventory для Kubespray.
# Не переписываем IP руками — генерируем.
output "kubespray_inventory" {
  description = "Скопировать в inventory/mycluster/inventory.ini"
  value       = <<-EOT
    [all]
    %{for k, v in module.k8s_nodes.nodes~}
    %{if v.role != "load-balancer"~}
    ${k} ansible_host=${v.external_ip} ip=${v.internal_ip} access_ip=${v.internal_ip} ansible_user=${var.ssh_user}
    %{endif~}
    %{endfor~}

    [kube_control_plane]
    node1

    [etcd]
    node1

    [kube_node]
    %{for k, v in module.k8s_nodes.nodes~}
    %{if local.nodes[k].role == "worker"~}
    ${k}
    %{endif~}
    %{endfor~}

    [k8s_cluster:children]
    kube_control_plane
    kube_node
  EOT
}

output "ssh_commands" {
  description = "Готовые команды для проверки доступа"
  value = [
    for k, v in module.k8s_nodes.nodes :
    "ssh ${var.ssh_user}@${v.external_ip}"
  ]
}

output "load_balancers" {
  description = "lb1/lb2 для внешнего HA-входа в C4.5"
  value = {
    for name, node in module.k8s_nodes.nodes : name => node
    if node.role == "load-balancer"
  }
}

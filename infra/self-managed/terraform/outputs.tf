output "nodes" {
  description = "Все пять VM: node1-node3 + lb1-lb2"
  value       = module.k8s_nodes.nodes
  sensitive   = true
}

# ⭐ Главный output: готовый inventory для Kubespray.
# Не переписываем IP руками — генерируем.
output "kubespray_inventory" {
  description = "Готовый inventory для kubespray/inventory/video2/inventory.ini"
  value       = <<-EOT
    [all]
    %{for k, v in module.k8s_nodes.nodes~}
    %{if !contains(v.roles, "load-balancer")~}
    ${k} ansible_host=${v.external_ip} ip=${v.internal_ip} access_ip=${v.internal_ip} ansible_user=${var.ssh_user}
    %{endif~}
    %{endfor~}

    [kube_control_plane]
    node1
    node2

    [etcd]
    node1
    node2
    node3

    [kube_node]
    %{for k, v in module.k8s_nodes.nodes~}
    %{if contains(local.nodes[k].roles, "worker")~}
    ${k}
    %{endif~}
    %{endfor~}

    [k8s_cluster:children]
    kube_control_plane
    kube_node
  EOT
  sensitive   = true
}

output "kubespray_all_yml" {
  description = "SAN публичного API endpoint для kubeconfig с ноутбука"
  value       = <<-EOT
    ---
    supplementary_addresses_in_ssl_keys:
      - ${module.k8s_nodes.nodes["node1"].external_ip}
  EOT
  sensitive   = true
}

output "external_ha_inventory" {
  description = "Inventory для ansible/external-ha; private IP идут в data plane, public IP только в ansible_host"
  value       = <<-EOT
    [load_balancers]
    lb1 ansible_host=${module.k8s_nodes.nodes["lb1"].external_ip} private_ip=${module.k8s_nodes.nodes["lb1"].internal_ip} ha_overlay_ip=10.77.0.11 ha_priority=150
    lb2 ansible_host=${module.k8s_nodes.nodes["lb2"].external_ip} private_ip=${module.k8s_nodes.nodes["lb2"].internal_ip} ha_overlay_ip=10.77.0.12 ha_priority=100

    [kubernetes_nodes]
    node1 ansible_host=${module.k8s_nodes.nodes["node1"].external_ip} private_ip=${module.k8s_nodes.nodes["node1"].internal_ip}
    node2 ansible_host=${module.k8s_nodes.nodes["node2"].external_ip} private_ip=${module.k8s_nodes.nodes["node2"].internal_ip}
    node3 ansible_host=${module.k8s_nodes.nodes["node3"].external_ip} private_ip=${module.k8s_nodes.nodes["node3"].internal_ip}

    [all:vars]
    ansible_user=${var.ssh_user}
    ansible_python_interpreter=/usr/bin/python3
    ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
    ha_vip=10.77.0.10
    ha_vip_prefix=24
    ha_frontend_port=8080
    k8s_nodeport=30080
  EOT
  sensitive   = true
}

output "ssh_commands" {
  description = "Готовые команды для проверки доступа"
  value = [
    for k, v in module.k8s_nodes.nodes :
    "ssh ${var.ssh_user}@${v.external_ip}"
  ]
  sensitive = true
}

output "load_balancers" {
  description = "lb1/lb2 для внешнего HA-входа в C4.5"
  value = {
    for name, node in module.k8s_nodes.nodes : name => node
    if contains(node.roles, "load-balancer")
  }
  sensitive = true
}

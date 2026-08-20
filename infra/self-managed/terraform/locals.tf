locals {
  # Один и тот же стенд живёт до конца выпуска. Root описывает состав и роли,
  # модуль создаёт однотипные VM. Роли здесь совпадают с inventory Kubespray.
  nodes = {
    node1 = { roles = ["control-plane", "etcd"], resources = var.control_plane_resources }
    node2 = { roles = ["control-plane", "etcd", "worker"], resources = var.control_plane_resources }
    node3 = { roles = ["etcd", "worker"], resources = var.worker_resources }
    lb1   = { roles = ["load-balancer"], resources = var.load_balancer_resources }
    lb2   = { roles = ["load-balancer"], resources = var.load_balancer_resources }
  }

  kubernetes_nodes = {
    for name, node in local.nodes : name => node
    if !contains(node.roles, "load-balancer")
  }
}

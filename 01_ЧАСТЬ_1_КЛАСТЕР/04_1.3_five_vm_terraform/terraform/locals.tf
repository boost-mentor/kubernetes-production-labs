locals {
  # Root отвечает за состав стенда и роли; модуль — за реализацию нод.
  nodes = {
    node1 = { role = "control-plane", resources = var.control_plane_resources }
    node2 = { role = "worker", resources = var.worker_resources }
    node3 = { role = "worker", resources = var.worker_resources }
    lb1   = { role = "load-balancer", resources = var.load_balancer_resources }
    lb2   = { role = "load-balancer", resources = var.load_balancer_resources }
  }

  kubernetes_nodes = {
    for name, node in local.nodes : name => node
    if node.role != "load-balancer"
  }
}

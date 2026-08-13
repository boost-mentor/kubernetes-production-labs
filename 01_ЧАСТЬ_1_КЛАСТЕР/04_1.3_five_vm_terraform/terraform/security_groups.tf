# Security group для нод кластера.
# Разбираем в кадре: почему именно эти порты и почему "разрешить всё внутри группы".
resource "yandex_vpc_security_group" "k8s" {
  name       = "${var.cluster_name}-sg"
  network_id = yandex_vpc_network.this.id

  # --- ВХОДЯЩИЙ ТРАФИК ---

  ingress {
    description    = "SSH — сюда ходит Ansible и ты сам"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description    = "Kubernetes API — kubectl с твоей машины"
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description       = "Весь трафик ВНУТРИ кластера между нодами"
    protocol          = "ANY"
    predefined_target = "self_security_group"
    # ← Ключевой момент: ноды должны свободно общаться между собой.
    #   etcd (2379/2380), kubelet (10250), CNI (BGP 179 у Calico, VXLAN 4789),
    #   NodePort (30000-32767) — всё это внутрикластерное.
    #   Перечислять по одному порту — путь к отладке «почему под не видит под».
  }

  ingress {
    description    = "NodePort-диапазон — если будешь публиковать сервисы напрямую"
    protocol       = "TCP"
    from_port      = 30000
    to_port        = 32767
    v4_cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description    = "ICMP — чтобы ping работал при диагностике"
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # --- ИСХОДЯЩИЙ ТРАФИК ---
  egress {
    description    = "Наружу всё: apt, докер-образы, github (Kubespray качает бинари)"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

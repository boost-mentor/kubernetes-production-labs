variable "cluster_name" {
  description = "Префикс имён облачных ресурсов"
  type        = string
}

variable "nodes" {
  description = "Карта нод: стабильный ключ, набор ролей и ресурсы"
  type = map(object({
    roles = set(string)
    resources = object({
      cores  = number
      memory = number
      disk   = number
    })
  }))

  validation {
    condition = length(var.nodes) > 0 && alltrue([
      for node in values(var.nodes) :
      length(node.roles) > 0 && alltrue([
        for role in node.roles :
        contains(["control-plane", "etcd", "worker", "load-balancer"], role)
      ])
    ])
    error_message = "nodes must be non-empty; roles must contain only control-plane, etcd, worker or load-balancer"
  }
}

variable "zone" {
  type = string
}

variable "image_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "ssh_user" {
  type = string
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

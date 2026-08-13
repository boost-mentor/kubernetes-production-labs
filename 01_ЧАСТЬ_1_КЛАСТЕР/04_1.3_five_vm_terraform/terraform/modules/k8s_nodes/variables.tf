variable "cluster_name" {
  description = "Префикс имён облачных ресурсов"
  type        = string
}

variable "nodes" {
  description = "Карта нод: стабильный ключ, роль и ресурсы"
  type = map(object({
    role = string
    resources = object({
      cores  = number
      memory = number
      disk   = number
    })
  }))

  validation {
    condition = length(var.nodes) > 0 && alltrue([
      for node in values(var.nodes) :
      contains(["control-plane", "worker", "load-balancer"], node.role)
    ])
    error_message = "nodes must be non-empty; role must be control-plane, worker or load-balancer"
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

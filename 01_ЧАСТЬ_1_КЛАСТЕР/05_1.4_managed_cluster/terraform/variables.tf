variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "cluster_name" {
  type    = string
  default = "k8s-managed"
}

variable "vpc_cidr" {
  description = "Подсеть для нод кластера"
  type        = string
  default     = "10.20.0.0/24" # ⚠️ ДРУГАЯ, чем у self-managed (10.10.0.0/24)!
  # Если оба кластера в одном облаке и когда-нибудь будут пирится — пересечение
  # диапазонов сломает маршрутизацию. Разводим сразу.
}

# --- CIDR для подов и сервисов. В managed их задаёт ТЕРРАФОРМ, не Kubespray ---
variable "cluster_ipv4_range" {
  description = "Pod CIDR"
  type        = string
  default     = "10.112.0.0/16"
}

variable "service_ipv4_range" {
  description = "Service CIDR"
  type        = string
  default     = "10.96.0.0/16"
}

variable "k8s_version" {
  description = "Версия Kubernetes. Проверено 29.07.2026: 1.34 в канале STABLE"
  type        = string
  default     = "1.34"
}

variable "release_channel" {
  description = "RAPID / REGULAR / STABLE. ⚠️ Сменить после создания НЕЛЬЗЯ"
  type        = string
  default     = "STABLE"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "enable_autoscaling" {
  description = "Переключает node group с fixed_scale на auto_scale"
  type        = bool
  default     = false
}

variable "autoscaling_min_nodes" {
  type    = number
  default = 2
}

variable "autoscaling_max_nodes" {
  type    = number
  default = 5

  validation {
    condition     = var.autoscaling_max_nodes >= var.autoscaling_min_nodes
    error_message = "autoscaling_max_nodes must be >= autoscaling_min_nodes"
  }
}

variable "allowed_nodeport_cidr" {
  description = "Доверенный CIDR для NodePort/ICMP, обычно текущий public IP /32"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_nodeport_cidr, 0)) && var.allowed_nodeport_cidr != "0.0.0.0/0" && var.allowed_nodeport_cidr != "::/0"
    error_message = "Укажи ограниченный CIDR, например 203.0.113.42/32."
  }
}

variable "allowed_api_cidr" {
  description = "Доверенный CIDR управления Kubernetes API, обычно текущий public IP /32"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_api_cidr, 0)) && var.allowed_api_cidr != "0.0.0.0/0" && var.allowed_api_cidr != "::/0"
    error_message = "Укажи ограниченный CIDR управления, например 203.0.113.42/32."
  }
}

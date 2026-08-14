# DEVOPS MAY CRY · ДИСПЕТЧЕРСКАЯ — весь цикл Terraform за две минуты:
# init → plan → apply → дрифт → destroy. Без облака, без токенов
# (но init всё же ходит в интернет за провайдером — прогнать до записи).
# Ресурсы — обычные файлы: неважно ЧТО создаём, важно КАК Terraform этим управляет.
#
# ЗАПУСК (в кадре):
#   terraform init      # притащил провайдер (появились .terraform/ и .terraform.lock.hcl)
#   terraform plan      # "+ create" ×2 — ЧТО собирается сделать. Ничего не создал!
#   terraform apply     # yes (только слово целиком) → журнал и сводка на диске + terraform.tfstate
#   terraform plan      # "No changes" ← смена уже такая, как в коде
#
# ДРИФТ (главный момент демо):
#   echo "тут никого не было, честно" > zhurnal.txt   # ← дежурный поправил журнал руками
#   terraform plan      # id ресурса = sha1 содержимого, sha1 не сошёлся → "will be created"
#   terraform apply     # вернул. Истина — код, а не то, что на диске.
#
#   terraform destroy   # снёс ровно то, что создавал (что лежит В STATE)

terraform {
  # Версии пиним ВСЕГДА — иначе завтрашний init принесёт другой провайдер.
  # .terraform.lock.hcl из-за этого КОММИТИМ, а не игнорим: он и делает пин настоящим.
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}

# variable = вход. Меняется без правки кода: -var 'dispatcher=Витёк'
variable "dispatcher" {
  description = "Кто сегодня на телефоне"
  type        = string
  default     = "дежурный"
}

variable "shift" {
  description = "Часы смены в шапке журнала"
  type        = string
  default     = "22:00-06:00"
}

# resource = ЖЕЛАЕМОЕ СОСТОЯНИЕ. Не «создай файл», а «файл должен БЫТЬ вот таким».
# Разницу между желаемым и реальным разгребает Terraform, а не ты руками.
resource "local_file" "zhurnal" {
  filename        = "${path.module}/zhurnal.txt"
  file_permission = "0644"
  content         = <<-EOT
    DEVOPS MAY CRY · ЖУРНАЛ ЗАЯВОК      смена ${var.shift}
    На телефоне: ${var.dispatcher}
    ----------------------------------------------------------
    401  ул. Тихая, 12   бабайка под кроватью   ночной тариф x2
    402  чердак, дом 7   шорохи, кто-то ходит   выехали
    403  подъезд 4       свет мигает сам себе   ждём электрика
    404  вентиляция      вой на девятом         выехали, не нашли
    ----------------------------------------------------------
    Правки в журнале руками не считаются. Считается то, что в plan.
  EOT
}

# Второй ресурс ССЫЛАЕТСЯ на первый → Terraform сам строит граф зависимостей:
# сначала журнал, потом сводка. Порядок строк в файле не важен вообще.
# (destroy пойдёт в обратном порядке: сводка, потом журнал — смену сдают с конца)
# length() на строке считает СИМВОЛЫ, а не байты: в журнале 488 символов и 711 байт.
resource "local_file" "svodka" {
  filename        = "${path.module}/svodka.txt"
  file_permission = "0644"
  content         = <<-EOT
    DEVOPS MAY CRY · СВОДКА СМЕНЫ
    Журнал: ${local_file.zhurnal.filename}, ${length(local_file.zhurnal.content)} символов
    Принято 4 · закрыто 3 · висит заявка 404
    Смену сдал: ${var.dispatcher}. Пицца дежурным — по факту закрытия 404.
    В 03:40 кончился кофе. Заявку на это не примут, а зря.
  EOT
}

# output = что показать после apply и что заберёт следующий инструмент.
# Ровно так мы отдадим IP-адреса ВМ в inventory Kubespray.
output "smena" {
  description = "Что появилось на диске за смену"
  value       = [local_file.zhurnal.filename, local_file.svodka.filename]
}

output "on_duty" {
  description = "Кто дежурит"
  value       = var.dispatcher
}

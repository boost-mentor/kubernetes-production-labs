# Пины версий. Без них завтрашний apply может дать другой результат.
# Проверено 29.07.2026: последний Terraform 1.15.8, YC provider 0.220.0.
# required_version намеренно диапазоном: локально может стоять 1.13.x — конфиг
# совместим. Провайдер запинен ЖЁСТКО: без этого завтрашний init принесёт другую
# версию и plan может отличаться.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.219.0"
    }
  }
}

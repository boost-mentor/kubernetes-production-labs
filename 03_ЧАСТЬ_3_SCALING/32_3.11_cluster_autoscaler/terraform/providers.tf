# Аутентификация — через переменные окружения, НЕ через переменную с токеном в коде.
#   export YC_TOKEN=$(yc iam create-token)
#   export YC_CLOUD_ID=$(yc config get cloud-id)
#   export YC_FOLDER_ID=$(yc config get folder-id)
# Так токен не попадёт ни в .tf, ни в state, ни в git.
provider "yandex" {
  zone = var.zone
}

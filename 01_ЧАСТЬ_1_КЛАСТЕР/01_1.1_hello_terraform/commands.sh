#!/usr/bin/env bash
# ЛАБА 1.1 · hello-terraform: смена в диспетчерской NIGHT SHIFT
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/01_1.1_hello_terraform"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

cd "$LAB_DIR"
rm -f zhurnal.txt svodka.txt terraform.tfstate terraform.tfstate.backup
terraform init          # прогнать ДО камеры: init лезет в интернет за провайдером


cd "$LAB_DIR"
terraform init        # → Terraform has been successfully initialized!  (+ .terraform/ и .terraform.lock.hcl)
terraform plan
# → Terraform will perform the following actions:
# →   # local_file.svodka will be created
# →   # local_file.zhurnal will be created   ← и полный текст обоих файлов, экран забьётся
# → Plan: 2 to add, 0 to change, 0 to destroy.
# → Changes to Outputs:  + on_duty = "дежурный"  + smena = [...]


terraform apply       # напечатать ровно yes (буква y НЕ принимается)
# → local_file.zhurnal: Creation complete after 0s [id=44281110112ea03dfbe73fb4a7fc6c8d70188950]
# → local_file.svodka:  Creation complete after 0s [id=32a9f4be2d0c232be451c4a723a677bad25874da]
# → Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
# →
# → Outputs:
# →
# → on_duty = "дежурный"
# → smena = [
# →   "./zhurnal.txt",
# →   "./svodka.txt",
# → ]
cat zhurnal.txt
# → NIGHT SHIFT · ЖУРНАЛ ЗАЯВОК      смена 22:00-06:00
# → На телефоне: дежурный
# → ----------------------------------------------------------
# → 401  ул. Тихая, 12   бабайка под кроватью   ночной тариф x2
# → 402  чердак, дом 7   шорохи, кто-то ходит   выехали
# → 403  подъезд 4       свет мигает сам себе   ждём электрика
# → 404  вентиляция      вой на девятом         выехали, не нашли
# → ----------------------------------------------------------
# → Правки в журнале руками не считаются. Считается то, что в plan.
cat svodka.txt
# → NIGHT SHIFT · СВОДКА СМЕНЫ
# → Журнал: ./zhurnal.txt, 488 символов
# → Принято 4 · закрыто 3 · висит заявка 404
# → Смену сдал: дежурный. Пицца дежурным — по факту закрытия 404.
# → В 03:40 кончился кофе. Заявку на это не примут, а зря.


terraform plan                # → No changes. Your infrastructure matches the configuration.
terraform output
# → on_duty = "дежурный"
# → smena = [
# →   "./zhurnal.txt",
# →   "./svodka.txt",
# → ]
terraform output -raw on_duty # → дежурный   ← без кавычек И без перевода строки: так значение забирает следующий инструмент


echo "тут никого не было, честно" > zhurnal.txt
terraform plan
# → local_file.zhurnal: Refreshing state... [id=44281110112ea03dfbe73fb4a7fc6c8d70188950]
# → local_file.svodka:  Refreshing state... [id=32a9f4be2d0c232be451c4a723a677bad25874da]
# →   # local_file.zhurnal will be created
# → Plan: 1 to add, 0 to change, 0 to destroy.
terraform apply       # yes
# → Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
head -2 zhurnal.txt   # → снова NIGHT SHIFT · ЖУРНАЛ ЗАЯВОК… / На телефоне: дежурный


terraform apply -var 'dispatcher=Витёк'     # yes
# → -/+ destroy and then create replacement
# →   # local_file.zhurnal must be replaced
# →       ~ content = <<-EOT # forces replacement
# →           - На телефоне: дежурный
# →           + На телефоне: Витёк
# →   # local_file.svodka must be replaced          ← ПЕРЕСЧИТАЛАСЬ САМА
# →       ~ content = <<-EOT # forces replacement
# →           - Журнал: ./zhurnal.txt, 488 символов
# →           + Журнал: ./zhurnal.txt, 485 символов
# → Plan: 2 to add, 0 to change, 2 to destroy.
# → local_file.svodka: Destroying... → local_file.zhurnal: Destroying...
# → local_file.zhurnal: Creating... → local_file.svodka: Creating...
# → Apply complete! Resources: 2 added, 0 changed, 2 destroyed.
grep "Смену сдал" svodka.txt    # → Смену сдал: Витёк. Пицца дежурным — по факту закрытия 404.


cp terraform.tfstate /tmp/tfstate.keep    # ← страховка дубля
rm terraform.tfstate
terraform plan
# → # local_file.zhurnal will be created
# → # local_file.svodka  will be created
# → Plan: 2 to add, 0 to change, 0 to destroy.   ← хотя оба файла лежат на диске


cp /tmp/tfstate.keep terraform.tfstate    # вариант «из бэкапа»
# ИЛИ, если бэкап не сделал:
terraform apply                           # yes → пересоздаст файлы по коду и заново соберёт state


terraform destroy     # → yes
# → local_file.svodka: Destroying... → local_file.zhurnal: Destroying...
# → Destroy complete! Resources: 2 destroyed.
rm -f /tmp/tfstate.keep

#!/usr/bin/env bash
# ЛАБА 1.2 · hello-ansible: диспетчерская открывается сама
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/02_1.2_hello_ansible"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

cd "$LAB_DIR"
rm -rf /tmp/night_office            # иначе первый прогон даст changed=0 вместо changed=4
grep 404 vars/prices.yml            # должно быть 4000 — иначе sed ниже не сработает


cd "$LAB_DIR"
cat inventory.ini                          # → [night_office] / localhost ansible_connection=local
ansible -i inventory.ini all -m ping
# → [WARNING]: Host 'localhost' is using the discovered Python interpreter at '...' — это норма, см. грабли
# → localhost | SUCCESS => { "ansible_facts": {"discovered_interpreter_python": "..."}, "changed": false, "ping": "pong" }
ansible-playbook -i inventory.ini playbook.yml
# → TASK [Диспетчерская открыта] ............ changed: [localhost]
# → TASK [Вывеска висит] .................... changed: [localhost]
# → TASK [Прайс на выезды вывешен] .......... changed: [localhost]
# → TASK [Посмотреть, что в диспетчерской] ... ok: [localhost]
# → TASK [Показать листинг] ................. ok: [localhost] => { "msg": ["prays.txt", "vyveska.txt"] }
# → RUNNING HANDLER [Разослать дежурным новый тариф] ... changed: [localhost]
# → PLAY RECAP: localhost : ok=6  changed=4  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
cat /tmp/night_office/prays.txt
# → NIGHT SHIFT · ПРАЙС НА НОЧНЫЕ ВЫЗОВЫ
# → 401 · бабайка под кроватью       3000 ₽
# → 402 · шорохи на чердаке          2500 ₽
# → 403 · свет мигает в подъезде     1500 ₽
# → 404 · вой в вентиляции           4000 ₽
# → После 02:00 тариф двойной. Это не жадность, это биология.
cat /tmp/night_office/rassylka.txt
# → Тариф обновлён, дежурные оповещены.
# → Полный набор нечисти по прайсу: 11000 ₽.


ansible-playbook -i inventory.ini playbook.yml
# → все задачи ok, RUNNING HANDLER не появился вообще
# → TASK [Показать листинг] → msg: ["prays.txt", "rassylka.txt", "vyveska.txt"]
# → PLAY RECAP: localhost : ok=5  changed=0


sed -i '' 's/: 4000/: 6000/' vars/prices.yml   # macOS; на Linux sed -i без ''
ansible-playbook -i inventory.ini playbook.yml
# → TASK [Прайс на выезды вывешен] .......... changed: [localhost]
# → RUNNING HANDLER [Разослать дежурным новый тариф] ... changed: [localhost]
# → PLAY RECAP: localhost : ok=6  changed=2
cat /tmp/night_office/rassylka.txt
# → Тариф обновлён, дежурные оповещены.
# → Полный набор нечисти по прайсу: 13000 ₽.


rm -rf /tmp/night_office
sed -i '' 's/: 6000/: 4000/' vars/prices.yml   # вернуть прайс как было
grep 404 vars/prices.yml                       # убедиться: 4000. Иначе следующий дубль поедет

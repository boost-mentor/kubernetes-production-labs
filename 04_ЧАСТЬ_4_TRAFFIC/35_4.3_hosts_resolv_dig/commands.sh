#!/usr/bin/env bash
# ЛАБА 4.3 · Кто отвечает первым: hosts → resolv.conf → dig +trace
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/35_4.3_hosts_resolv_dig"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

cat /etc/hosts            # 1. локальный файл — бьёт всё (для системного резолвера!)
cat /etc/resolv.conf      # 2. какой DNS-сервер спрашиваем
dig example.com           # → секции QUESTION / ANSWER (+TTL) — читаем структуру ответа
dig +trace example.com    # → вся иерархия: корень → .com → авторитетный сервер


echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
ping -c1 myapp.local      # → резолвится! (ping идёт через СИСТЕМНЫЙ резолвер: hosts первым)
dig myapp.local +short    # → ПУСТО! (dig идёт СРАЗУ на DNS-сервер, МИМО hosts)


sudo sed -i '' '/myapp.local/d' /etc/hosts      # Linux: sudo sed -i '/myapp.local/d' /etc/hosts

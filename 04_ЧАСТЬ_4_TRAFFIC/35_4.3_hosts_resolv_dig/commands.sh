#!/usr/bin/env bash
# ЛАБА 4.3 · Кто отвечает первым: hosts → resolv.conf → dig +trace
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

cat /etc/hosts            # 1. локальный файл — бьёт всё (для системного резолвера!)
cat /etc/resolv.conf      # 2. какой DNS-сервер спрашиваем
dig example.com           # → секции QUESTION / ANSWER (+TTL) — читаем структуру ответа
dig +trace example.com    # → вся иерархия: корень → .com → авторитетный сервер


echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
ping -c1 myapp.local      # → резолвится! (ping идёт через СИСТЕМНЫЙ резолвер: hosts первым)
dig myapp.local +short    # → ПУСТО! (dig идёт СРАЗУ на DNS-сервер, МИМО hosts)


sudo sed -i '' '/myapp.local/d' /etc/hosts      # Linux: sudo sed -i '/myapp.local/d' /etc/hosts

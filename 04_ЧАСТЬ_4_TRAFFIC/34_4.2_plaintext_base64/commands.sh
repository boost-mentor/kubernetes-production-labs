#!/usr/bin/env bash
# ЛАБА 4.2 · Пароль открытым текстом + base64 — это НЕ шифрование
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

# окно 1 (перезапуск, ASCII-режим):
sudo tcpdump -i lo0 -n -A 'tcp port 8080 and greater 100'
# окно 2:
curl -s http://localhost:8080/secret -H "Authorization: Basic dXNlcjpwYXNz" >/dev/null


echo dXNlcjpwYXNz | base64 -d; echo     # → user:pass


kill %1 2>/dev/null; jobs     # прибрать http.server

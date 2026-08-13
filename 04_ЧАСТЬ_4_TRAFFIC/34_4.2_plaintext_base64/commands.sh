#!/usr/bin/env bash
# ЛАБА 4.2 · Пароль открытым текстом + base64 — это НЕ шифрование
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/34_4.2_plaintext_base64"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

# окно 1 (перезапуск, ASCII-режим):
sudo tcpdump -i lo0 -n -A 'tcp port 8080 and greater 100'
# окно 2:
curl -s http://localhost:8080/secret -H "Authorization: Basic dXNlcjpwYXNz" >/dev/null


echo dXNlcjpwYXNz | base64 -d; echo     # → user:pass


kill %1 2>/dev/null; jobs     # прибрать http.server

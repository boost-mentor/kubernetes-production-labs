#!/usr/bin/env bash
# ЛАБА 4.1 · TCP handshake вживую: три пакета в tcpdump
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/33_4.1_tcp_handshake"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

# окно 1:
sudo tcpdump -i lo0 -n 'tcp port 8080'          # Linux: -i lo
# окно 2:
python3 -m http.server 8080 &
curl -s http://localhost:8080/ >/dev/null


ss -tan | head        # macOS: netstat -an | head   → LISTEN / ESTABLISHED / TIME_WAIT

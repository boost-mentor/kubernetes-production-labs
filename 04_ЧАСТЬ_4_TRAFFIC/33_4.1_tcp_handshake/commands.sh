#!/usr/bin/env bash
# ЛАБА 4.1 · TCP handshake вживую: три пакета в tcpdump
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

# окно 1:
sudo tcpdump -i lo0 -n 'tcp port 8080'          # Linux: -i lo
# окно 2:
python3 -m http.server 8080 &
curl -s http://localhost:8080/ >/dev/null


ss -tan | head        # macOS: netstat -an | head   → LISTEN / ESTABLISHED / TIME_WAIT

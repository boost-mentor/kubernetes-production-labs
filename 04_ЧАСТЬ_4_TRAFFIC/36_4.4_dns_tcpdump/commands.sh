#!/usr/bin/env bash
# ЛАБА 4.4 · DNS на проводе: tcpdump port 53
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/04_ЧАСТЬ_4_TRAFFIC/36_4.4_dns_tcpdump"
SOURCE_ROOT="$REPO_ROOT"
cd "$LAB_DIR"

DNS_SERVER="$(scutil --dns | awk '/nameserver\[[0-9]+\]/{print $3; exit}')"
test -n "$DNS_SERVER" || { echo "DNS resolver not found" >&2; exit 1; }
IFACE="$(route -n get "$DNS_SERVER" | awk '/interface:/{print $2; exit}')"
printf 'resolver=%s interface=%s\n' "$DNS_SERVER" "$IFACE"
# Терминал A: только наблюдаем трафик, VPN/routes/DNS не меняем.
sudo tcpdump -i "$IFACE" -n "host $DNS_SERVER and port 53"
# Терминал B:
dig @"$DNS_SERVER" example.com A

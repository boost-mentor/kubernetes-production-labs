#!/usr/bin/env bash
# ЛАБА 4.4 · DNS на проводе: tcpdump port 53
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$LAB_DIR/../.." && pwd -P)"
SOURCE_ROOT="$REPO_ROOT"

DNS_SERVER="$(scutil --dns | awk '/nameserver[[0-9]+]/{print $3; exit}')"
test -n "$DNS_SERVER" || { echo "DNS resolver not found" >&2; exit 1; }
IFACE="$(route -n get "$DNS_SERVER" | awk '/interface:/{print $2; exit}')"
printf 'resolver=%s interface=%s
' "$DNS_SERVER" "$IFACE"
# Терминал A: только наблюдаем трафик, VPN/routes/DNS не меняем.
sudo tcpdump -i "$IFACE" -n "host $DNS_SERVER and port 53"
# Терминал B:
dig @"$DNS_SERVER" example.com A

#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "Usage: $0 LB1_IP LB2_IP NODE1_IP NODE2_IP NODE3_IP SSH_KEY" >&2
  exit 2
fi

lb1_ip=$1
lb2_ip=$2
node1_ip=$3
node2_ip=$4
node3_ip=$5
ssh_key=$6

if [[ ! -f "$ssh_key" ]]; then
  echo "SSH key not found: $ssh_key" >&2
  exit 2
fi
chmod 600 "$ssh_key"

script_dir=$(cd "$(dirname "$0")" && pwd)
inventory_path="$script_dir/inventory.ini"

sed \
  -e "s|__LB1_IP__|$lb1_ip|g" \
  -e "s|__LB2_IP__|$lb2_ip|g" \
  -e "s|__NODE1_IP__|$node1_ip|g" \
  -e "s|__NODE2_IP__|$node2_ip|g" \
  -e "s|__NODE3_IP__|$node3_ip|g" \
  -e "s|__SSH_KEY__|$ssh_key|g" \
  "$script_dir/inventory.example.ini" > "$inventory_path"

echo "Inventory ready: $inventory_path"

#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 NODE1_PUBLIC_IP NODE2_PUBLIC_IP NODE3_PUBLIC_IP SSH_KEY" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
NODE1_PUBLIC="$1"
NODE2_PUBLIC="$2"
NODE3_PUBLIC="$3"
KEY_INPUT="$4"
KEY_DIR="$(cd "$(dirname "$KEY_INPUT")" && pwd -P)"
KEY_PATH="$KEY_DIR/$(basename "$KEY_INPUT")"
INVENTORY_DIR="$ROOT_DIR/inventory/video2"
BOOTSTRAP_INVENTORY="$INVENTORY_DIR/bootstrap.ini"
ANSIBLE="$ROOT_DIR/.venv/bin/ansible"

[[ -f "$KEY_PATH" ]] || { echo "ERROR: SSH key not found: $KEY_PATH" >&2; exit 1; }
chmod 600 "$KEY_PATH"
[[ -x "$ANSIBLE" ]] || { echo "ERROR: run ./bootstrap.sh" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq not found" >&2; exit 1; }

mkdir -p "$INVENTORY_DIR/facts" "$INVENTORY_DIR/group_vars/all" "$INVENTORY_DIR/group_vars/k8s_cluster"
cat >"$BOOTSTRAP_INVENTORY" <<EOF
[all]
node1 ansible_host=$NODE1_PUBLIC
node2 ansible_host=$NODE2_PUBLIC
node3 ansible_host=$NODE3_PUBLIC

[all:vars]
ansible_user=root
ansible_ssh_private_key_file=$KEY_PATH
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
EOF

"$ANSIBLE" -i "$BOOTSTRAP_INVENTORY" all -m setup \
  -a 'filter=ansible_default_ipv4' --tree "$INVENTORY_DIR/facts" >/dev/null

private_ip() {
  jq -er '.ansible_facts.ansible_default_ipv4.address' "$INVENTORY_DIR/facts/$1"
}

NODE1_PRIVATE="$(private_ip node1)"
NODE2_PRIVATE="$(private_ip node2)"
NODE3_PRIVATE="$(private_ip node3)"

cat >"$INVENTORY_DIR/inventory.ini" <<EOF
[all]
node1 ansible_host=$NODE1_PUBLIC ip=$NODE1_PRIVATE access_ip=$NODE1_PRIVATE
node2 ansible_host=$NODE2_PUBLIC ip=$NODE2_PRIVATE access_ip=$NODE2_PRIVATE
node3 ansible_host=$NODE3_PUBLIC ip=$NODE3_PRIVATE access_ip=$NODE3_PRIVATE

[kube_control_plane]
node1
node2

[etcd]
node1
node2
node3

[kube_node]
node2
node3

[k8s_cluster:children]
kube_control_plane
kube_node

[all:vars]
ansible_user=root
ansible_ssh_private_key_file=$KEY_PATH
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
EOF

cat >"$INVENTORY_DIR/group_vars/all/all.yml" <<EOF
---
supplementary_addresses_in_ssl_keys:
  - $NODE1_PUBLIC
EOF

cat >"$INVENTORY_DIR/group_vars/k8s_cluster/k8s-cluster.yml" <<'EOF'
---
kube_version: 1.34.7
kube_network_plugin: calico
container_manager: containerd
kube_proxy_mode: ipvs
kube_proxy_strict_arp: true
kube_service_addresses: 10.233.0.0/18
kube_pods_subnet: 10.233.64.0/18
kube_network_node_prefix: 24
cluster_name: cluster.local
dns_mode: coredns
enable_nodelocaldns: true
kubeconfig_localhost: true
kubectl_localhost: false
EOF

rm -rf "$INVENTORY_DIR/facts" "$BOOTSTRAP_INVENTORY"
echo "READY: inventory/video2/inventory.ini"
printf 'public -> private: node1 %s -> %s; node2 %s -> %s; node3 %s -> %s\n' \
  "$NODE1_PUBLIC" "$NODE1_PRIVATE" "$NODE2_PUBLIC" "$NODE2_PRIVATE" "$NODE3_PUBLIC" "$NODE3_PRIVATE"

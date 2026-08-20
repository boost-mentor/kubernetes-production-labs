#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TF_DIR="$REPO_ROOT/infra/self-managed/terraform"
ENV_FILE="$REPO_ROOT/recording/.recording.env"
INVENTORY_DIR="$REPO_ROOT/kubespray/inventory/video2"
INVENTORY="$INVENTORY_DIR/inventory.ini"
ALL_VARS="$INVENTORY_DIR/group_vars/all/all.yml"

mkdir -p "$(dirname "$ALL_VARS")"
tmp_inventory="$(mktemp "${TMPDIR:-/tmp}/video2-kubespray-inventory.XXXXXX")"
tmp_all="$(mktemp "${TMPDIR:-/tmp}/video2-kubespray-all.XXXXXX")"
cleanup() { rm -f "$tmp_inventory" "$tmp_all"; }
trap cleanup EXIT

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -n "${NODE1_SSH_HOST:-}" && -n "${NODE2_SSH_HOST:-}" && -n "${NODE3_SSH_HOST:-}" ]]; then
  ssh_user="${VIDEO2_SSH_USER:-root}"
  cat > "$tmp_inventory" <<EOF
[all]
node1 ansible_host=$NODE1_SSH_HOST ansible_user=$ssh_user
node2 ansible_host=$NODE2_SSH_HOST ansible_user=$ssh_user
node3 ansible_host=$NODE3_SSH_HOST ansible_user=$ssh_user

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
EOF
  cat > "$tmp_all" <<EOF
---
supplementary_addresses_in_ssl_keys:
  - $NODE1_SSH_HOST
EOF
  source_note="BoostMentor lesson addresses; private IPs are gathered by Ansible facts"
else
  command -v terraform >/dev/null || { echo "ERROR: terraform not found" >&2; exit 1; }
  [[ -f "$TF_DIR/terraform.tfstate" ]] || {
    echo "ERROR: fill NODE1_SSH_HOST..NODE3_SSH_HOST in $ENV_FILE or provide Terraform state" >&2
    exit 1
  }
  terraform -chdir="$TF_DIR" output -raw kubespray_inventory > "$tmp_inventory"
  terraform -chdir="$TF_DIR" output -raw kubespray_all_yml > "$tmp_all"
  source_note="Terraform outputs; public/floating IPs remain SSH-only"
fi

grep -q '^\[kube_control_plane\]$' "$tmp_inventory"
grep -q '^\[etcd\]$' "$tmp_inventory"
grep -q '^\[kube_node\]$' "$tmp_inventory"
grep -q '^supplementary_addresses_in_ssl_keys:' "$tmp_all"

mv "$tmp_inventory" "$INVENTORY"
mv "$tmp_all" "$ALL_VARS"
echo "READY: $INVENTORY"
echo "READY: $ALL_VARS"
echo "NOTE: $source_note."

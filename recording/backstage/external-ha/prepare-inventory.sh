#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  echo "Addresses come from recording/.recording.env or an existing Terraform state." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TF_DIR="$REPO_ROOT/infra/self-managed/terraform"
ENV_FILE="$REPO_ROOT/recording/.recording.env"
KIT_DIR="$REPO_ROOT/ansible/external-ha"
INVENTORY="$KIT_DIR/inventory.ini"

tmp_inventory="$(mktemp "${TMPDIR:-/tmp}/video2-external-ha-inventory.XXXXXX")"
cleanup() { rm -f "$tmp_inventory"; }
trap cleanup EXIT

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -n "${NODE1_SSH_HOST:-}" && -n "${NODE2_SSH_HOST:-}" && -n "${NODE3_SSH_HOST:-}" && -n "${LB1_SSH_HOST:-}" && -n "${LB2_SSH_HOST:-}" ]]; then
  ssh_user="${VIDEO2_SSH_USER:-root}"
  cat > "$tmp_inventory" <<EOF
[load_balancers]
lb1 ansible_host=$LB1_SSH_HOST ansible_user=$ssh_user ha_overlay_ip=10.77.0.11 ha_priority=150
lb2 ansible_host=$LB2_SSH_HOST ansible_user=$ssh_user ha_overlay_ip=10.77.0.12 ha_priority=100

[kubernetes_nodes]
node1 ansible_host=$NODE1_SSH_HOST ansible_user=$ssh_user
node2 ansible_host=$NODE2_SSH_HOST ansible_user=$ssh_user
node3 ansible_host=$NODE3_SSH_HOST ansible_user=$ssh_user

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ha_vip=${HA_VIP:-10.77.0.10}
ha_vip_prefix=24
ha_frontend_port=${HA_PORT:-8080}
k8s_nodeport=${K8S_NODEPORT:-30080}
EOF
else
  command -v terraform >/dev/null || { echo "ERROR: terraform not found" >&2; exit 1; }
  [[ -f "$TF_DIR/terraform.tfstate" ]] || {
    echo "ERROR: fill the five SSH host variables in $ENV_FILE or provide Terraform state" >&2
    exit 1
  }
  terraform -chdir="$TF_DIR" output -raw external_ha_inventory > "$tmp_inventory"
fi
grep -q '^\[load_balancers\]$' "$tmp_inventory"
grep -q '^\[kubernetes_nodes\]$' "$tmp_inventory"
mv "$tmp_inventory" "$INVENTORY"

echo "READY: $INVENTORY"
echo "NOTE: ansible_host is public/floating and used only for SSH; data plane uses gathered private IPs."

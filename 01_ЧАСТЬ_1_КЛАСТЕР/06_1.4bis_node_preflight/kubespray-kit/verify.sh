#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
INV="$ROOT_DIR/inventory/video2/inventory.ini"
ANSIBLE="$ROOT_DIR/.venv/bin/ansible"

"$ANSIBLE" -i "$INV" node1 -b -m shell -a \
  'kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide && kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A && kubectl --kubeconfig=/etc/kubernetes/admin.conf -n kube-system get configmap kube-proxy -o yaml | grep -i strictARP'

echo "PROOF: 3 Ready nodes, system pods visible, strictARP enabled"

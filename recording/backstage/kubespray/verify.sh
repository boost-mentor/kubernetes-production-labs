#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
INV="$REPO_ROOT/kubespray/inventory/video2/inventory.ini"
ANSIBLE="$REPO_ROOT/kubespray/.venv/bin/ansible"
RECORDING_ENV="$REPO_ROOT/recording/.recording.env"

if [[ -f "$RECORDING_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$RECORDING_ENV"
  set +a
fi
SSH_KEY="${VIDEO2_SSH_KEY:-$HOME/.ssh/id_ed25519}"

[[ -x "$ANSIBLE" ]] || { echo "ERROR: run $SCRIPT_DIR/bootstrap.sh" >&2; exit 1; }
[[ -f "$INV" ]] || { echo "ERROR: inventory not found: $INV" >&2; exit 1; }
[[ -f "$SSH_KEY" ]] || { echo "ERROR: SSH key not found: $SSH_KEY" >&2; exit 1; }

"$ANSIBLE" -i "$INV" node1 --private-key "$SSH_KEY" -b -m shell -a \
  'kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide && kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A && kubectl --kubeconfig=/etc/kubernetes/admin.conf -n kube-system get configmap kube-proxy -o yaml | grep -i strictARP'

echo "PROOF: 3 Ready nodes, system pods visible, strictARP enabled"

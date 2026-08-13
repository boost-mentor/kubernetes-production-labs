#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
KUBESPRAY_DIR="$ROOT_DIR/vendor/kubespray"
KUBESPRAY_TAG="v2.31.0"

command -v git >/dev/null || { echo "ERROR: git not found" >&2; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 not found" >&2; exit 1; }

if [[ ! -d "$KUBESPRAY_DIR/.git" ]]; then
  mkdir -p "$(dirname "$KUBESPRAY_DIR")"
  git clone --branch "$KUBESPRAY_TAG" --depth 1 \
    https://github.com/kubernetes-sigs/kubespray.git "$KUBESPRAY_DIR"
fi

actual_tag="$(git -C "$KUBESPRAY_DIR" describe --tags --exact-match 2>/dev/null || true)"
[[ "$actual_tag" == "$KUBESPRAY_TAG" ]] || {
  echo "ERROR: expected $KUBESPRAY_TAG, got ${actual_tag:-unknown}" >&2
  exit 1
}

python3 -m venv "$ROOT_DIR/.venv"
"$ROOT_DIR/.venv/bin/pip" install --disable-pip-version-check -r "$KUBESPRAY_DIR/requirements.txt"
echo "READY: Kubespray $actual_tag and isolated Python environment"

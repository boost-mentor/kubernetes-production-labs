#!/usr/bin/env bash
set -euo pipefail

vpa_version=1.7.0
vpa_commit=6a616ea0c5ea0cb6111240073a9273b3467c064e
cache_root=${XDG_CACHE_HOME:-$HOME/.cache}/video2-vpa
repo_dir=$cache_root/autoscaler

mkdir -p "$cache_root"
if [[ ! -d "$repo_dir/.git" ]]; then
  git clone --depth 1 \
    --branch "vertical-pod-autoscaler-${vpa_version}" \
    https://github.com/kubernetes/autoscaler.git "$repo_dir"
fi

actual_commit=$(git -C "$repo_dir" rev-parse HEAD)
if [[ $actual_commit != "$vpa_commit" ]]; then
  echo "unexpected VPA source commit: $actual_commit" >&2
  echo "expected: $vpa_commit" >&2
  echo "move $repo_dir aside and rerun; the script never deletes an unknown checkout" >&2
  exit 1
fi

(
  cd "$repo_dir/vertical-pod-autoscaler"
  ./hack/vpa-up.sh
)

echo "VPA ${vpa_version} installed from verified commit ${vpa_commit}"

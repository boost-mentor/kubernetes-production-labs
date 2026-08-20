#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
LAB_DIR="$REPO_ROOT/01_ЧАСТЬ_1_КЛАСТЕР/11_1.9_metallb"
BASE_DIR="$REPO_ROOT/kubernetes/devops-may-cry/base"
LB_SERVICE="$LAB_DIR/devops-may-cry-loadbalancer.yaml"
POOL_TEMPLATE="$LAB_DIR/metallb-demo.yaml"
RECORDING_ENV="$REPO_ROOT/recording/.recording.env"

if [[ -f "$RECORDING_ENV" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$RECORDING_ENV"
  set +a
fi
SELF_CONTEXT="${SELF_CONTEXT:-kubespray}"

work_file=$(mktemp "${TMPDIR:-/tmp}/video2-metallb.XXXXXX.yaml")
trap 'rm -f "$work_file"' EXIT

case $# in
  0)
    pool_start="${METALLB_POOL_START:-}"
    pool_end="${METALLB_POOL_END:-}"
    ;;
  2)
    pool_start=$1
    pool_end=$2
    ;;
  *)
    echo "usage: $0 [pool-start pool-end]" >&2
    exit 2
    ;;
esac
[[ -n "$pool_start" && -n "$pool_end" ]] || {
  echo "ERROR: set METALLB_POOL_START/METALLB_POOL_END or pass both arguments" >&2
  exit 2
}

[[ -f "$POOL_TEMPLATE" && -f "$LB_SERVICE" && -f "$BASE_DIR/kustomization.yaml" ]] || {
  echo "ERROR: canonical MetalLB/app manifests are missing" >&2
  exit 1
}
python3 - "$pool_start" "$pool_end" <<'PY'
import ipaddress
import sys

start = ipaddress.ip_address(sys.argv[1])
end = ipaddress.ip_address(sys.argv[2])
if start.version != 4 or end.version != 4 or int(start) > int(end):
    raise SystemExit("invalid IPv4 MetalLB range")
PY

helm repo add metallb https://metallb.github.io/metallb >/dev/null 2>&1 || true
helm repo update metallb
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace \
  --version 0.16.1 \
  --kube-context "$SELF_CONTEXT" \
  --wait --timeout 5m

sed \
  -e "s/__POOL_START__/$pool_start/g" \
  -e "s/__POOL_END__/$pool_end/g" \
  "$POOL_TEMPLATE" > "$work_file"

echo "MetalLB explicit reserved pool: $pool_start-$pool_end"
kubectl --context "$SELF_CONTEXT" apply -k "$BASE_DIR"
kubectl --context "$SELF_CONTEXT" apply -f "$LB_SERVICE"
kubectl --context "$SELF_CONTEXT" apply -f "$work_file"

for _attempt in {1..30}; do
  external_ip=$(kubectl --context "$SELF_CONTEXT" -n traffic-lab get svc devops-may-cry-metallb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [[ -n "$external_ip" ]] && break
  sleep 2
done

test -n "${external_ip:-}" || { kubectl --context "$SELF_CONTEXT" -n traffic-lab describe svc devops-may-cry-metallb; exit 1; }
kubectl --context "$SELF_CONTEXT" -n metallb-system get pods
kubectl --context "$SELF_CONTEXT" -n metallb-system get ipaddresspool,l2advertisement
kubectl --context "$SELF_CONTEXT" -n traffic-lab get deploy,pod,svc,endpointslice -o wide
echo "METALLB DEMO OK: Service LoadBalancer получил EXTERNAL-IP=$external_ip"

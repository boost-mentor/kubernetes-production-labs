#!/usr/bin/env bash
# ЛАБА 3.10 · VPA recommender-only: показываем манифесты, не прячем их в install.sh
# Выполнять ПО БЛОКАМ во время лабораторной. Не запускать файл целиком.

# Первый блок работает и при копировании из VS Code в новый терминал:
# путь вычисляется от корня git clone, а не от случайного текущего каталога.
REPO_ROOT="$(git rev-parse --show-toplevel)"
LAB_DIR="$REPO_ROOT/03_ЧАСТЬ_3_SCALING/31_3.10_vpa"
cd "$LAB_DIR" || exit

kubectl apply -k ./base
kubectl -n traffic-lab delete hpa devops-may-cry --ignore-not-found
kubectl -n traffic-lab rollout status deploy/devops-may-cry --timeout=180s
kubectl top pods -n traffic-lab -l app=devops-may-cry

# Фиксируем не только tag, но и commit. Если cache уже есть и он другой,
# test остановит сцену; мы не удаляем неизвестный checkout.
VPA_VERSION="1.7.0"
VPA_COMMIT="6a616ea0c5ea0cb6111240073a9273b3467c064e"
VPA_SOURCE="${XDG_CACHE_HOME:-$HOME/.cache}/video2-vpa/autoscaler"
if [[ ! -d "$VPA_SOURCE/.git" ]]; then
  mkdir -p "$(dirname "$VPA_SOURCE")"
  git clone --depth 1 --branch "vertical-pod-autoscaler-$VPA_VERSION" \
    https://github.com/kubernetes/autoscaler.git "$VPA_SOURCE"
fi
test "$(git -C "$VPA_SOURCE" rev-parse HEAD)" = "$VPA_COMMIT"
VPA_DEPLOY="$VPA_SOURCE/vertical-pod-autoscaler/deploy"

# Для updateMode=Off нужны CRD, RBAC и recommender. Updater и admission-controller
# не ставим: в этой сцене никто не имеет права пересоздавать workload.
test -z "$(kubectl -n kube-system get deploy \
  vpa-updater vpa-admission-controller --ignore-not-found -o name)"
sed -n '1,80p' "$VPA_DEPLOY/recommender-deployment.yaml"
kubectl apply -f "$VPA_DEPLOY/vpa-v1-crd-gen.yaml"
kubectl apply -f "$VPA_DEPLOY/vpa-rbac.yaml"
kubectl apply -f "$VPA_DEPLOY/recommender-deployment.yaml"
kubectl -n kube-system rollout status deploy/vpa-recommender --timeout=180s
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io

PODS_BEFORE="$(kubectl -n traffic-lab get pod -l app=devops-may-cry \
  -o jsonpath='{range .items[*]}{.metadata.uid}{"\n"}{end}' | sort | tr '\n' ' ')"
kubectl apply -f ./vpa_lab.yaml

# Recommender нужна история samples. Ждём не статус объекта, а непустую target-рекомендацию.
VPA_TARGET=""
for attempt in $(seq 1 36); do
  VPA_TARGET="$(kubectl -n traffic-lab get vpa devops-may-cry \
    -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}{" / "}{.status.recommendation.containerRecommendations[0].target.memory}' \
    2>/dev/null || true)"
  [[ "$VPA_TARGET" != " / " && -n "$VPA_TARGET" ]] && break
  printf 'waiting for VPA recommendation (%s/36)\r' "$attempt"
  sleep 10
done
test "$VPA_TARGET" != " / "
printf 'VPA target cpu / memory: %s\n' "$VPA_TARGET"
kubectl -n traffic-lab describe vpa devops-may-cry | sed -n '/Recommendation:/,$p'

# Доказываем обе части фразы: recommendation есть, UID подов не изменились.
PODS_AFTER="$(kubectl -n traffic-lab get pod -l app=devops-may-cry \
  -o jsonpath='{range .items[*]}{.metadata.uid}{"\n"}{end}' | sort | tr '\n' ' ')"
printf 'pod UIDs before: %s\npod UIDs after:  %s\n' "$PODS_BEFORE" "$PODS_AFTER"
test "$PODS_BEFORE" = "$PODS_AFTER"

# Production caveat: recommendation — не готовый values.yaml. Сверяем её с p95/p99,
# OOM/throttling, startup latency и сезонностью. Auto/Initial может дать disruption.
kubectl -n traffic-lab delete vpa devops-may-cry --ignore-not-found

#!/usr/bin/env bash
set -euo pipefail

kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null
for deployment in vpa-admission-controller vpa-recommender vpa-updater; do
  kubectl -n kube-system rollout status "deployment/$deployment" --timeout=180s
done
kubectl -n kube-system get deploy,pod -l app.kubernetes.io/name=vpa -o wide 2>/dev/null || \
  kubectl -n kube-system get deploy,pod | grep -E 'NAME|vpa-'
kubectl top nodes >/dev/null

echo "VPA PRE-FLIGHT OK: CRD, admission controller, recommender, updater, Metrics API"

# VPA recording kit

Живая лаборатория использует официальный release
`vertical-pod-autoscaler-1.7.0` и дополнительно фиксирует commit
`6a616ea0c5ea0cb6111240073a9273b3467c064e`. Ветку `master` и `latest` не
скачиваем.

```bash
./install.sh
./preflight.sh
kubectl apply -f ../vpa_lab.yaml
```

В объекте DEVOPS MAY CRY стоит `updateMode: Off`: мы собираем рекомендацию и не
разрешаем VPA самовольно пересоздавать pod во время записи. В production режим
выбирают с учётом PDB, disruption budget, startup latency и поддержки in-place
resize конкретной версией Kubernetes. VPA зависит от Metrics API; зелёный CRD
без работающего recommender ещё ничего не доказывает.

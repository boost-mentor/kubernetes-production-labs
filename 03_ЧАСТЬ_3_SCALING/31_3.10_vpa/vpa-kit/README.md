# VPA recording kit

Живая лаборатория использует официальный release
`vertical-pod-autoscaler-1.7.0` и дополнительно фиксирует commit
`6a616ea0c5ea0cb6111240073a9273b3467c064e`. Ветку `master` и `latest` не
скачиваем.

`install.sh` и `preflight.sh` — только backstage-подстраховка. В REC их не
запускаем: `commands.sh` отдельно показывает upstream CRD, RBAC и
recommender Deployment, применяет их тремя прямыми `kubectl apply` и
доказывает, что `updateMode: Off` не заменил Pod.

В объекте DEVOPS MAY CRY стоит `updateMode: Off`: мы собираем рекомендацию и не
разрешаем VPA самовольно пересоздавать pod во время записи. В production режим
выбирают с учётом PDB, disruption budget, startup latency и поддержки in-place
resize конкретной версией Kubernetes. VPA зависит от Metrics API; зелёный CRD
без работающего recommender ещё ничего не доказывает.

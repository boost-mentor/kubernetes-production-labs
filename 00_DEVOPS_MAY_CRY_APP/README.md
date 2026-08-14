# DevOps May Cry

Сквозное приложение видео №2: диспетчерская ночных дежурных принимает заказы на
устранение «демонов»-инцидентов. Визуальный референс — готический neon-action,
но вселенная, названия и тексты полностью оригинальные.

Это не код внутри Kubernetes YAML. Здесь отдельно живут Go API, тесты,
multi-stage Dockerfile, PostgreSQL-миграция, Compose и Kubernetes-манифесты.

## Локальная проверка

```bash
cp .env.example .env
# замени пароль в .env
go test ./...
go test -race ./...
go vet ./...
docker compose up --build -d
curl -s http://127.0.0.1:8080/quote
curl -s 'http://127.0.0.1:8080/order?on=dns-ghost'
curl -s http://127.0.0.1:8080/readyz
docker compose down -v
```

Публикуемый образ собирается для `linux/amd64` и `linux/arm64`, получает OCI
metadata (`version`, commit, build time), SBOM/provenance и в Kubernetes
фиксируется по digest. `latest` в учебном и production-маршруте не используется.

## API, которое используется в лабораторных

- `GET /` и `GET /quote` — фраза, pod и тип хранилища;
- `GET /order?on=dns-ghost` и `POST /orders` — заказ;
- `GET /overload?sec=60` — управляемая CPU-нагрузка для изолированной лабы;
- `GET /wound?mb=200` — удержание памяти для OOM-лабы;
- `GET /healthz`, `/livez`, `/readyz`, `/metrics` — эксплуатационные ручки.

Без `DB_HOST` API использует память: это удобно в лабораториях по HPA и сети.
Compose подключает PostgreSQL. Локальный DB-вариант в Kubernetes нужен для
демонстрации scheduling; в production базу выносят в managed service или
оператор, используют CSI-диски, backup/PITR и отдельный failure domain.

Самонагрузочные `/overload` и `/wound` по умолчанию выключены. Они включаются
только явным `LAB_ENDPOINTS_ENABLED=true` в изолированном стенде; публично
оставлять такие ручки нельзя.

В `k8s/scheduling/production-reference/postgres.yaml` лежит reference с
StatefulSet и PVC. Это не готовая PostgreSQL HA: в production предпочтительны
managed database или оператор, TLS, backup/PITR и отдельный failure domain.
Для живой Ч2 есть отдельный `postgres-disposable.yaml` с `emptyDir`: он не
притворяется хранилищем данных и удаляется вместе с scheduling-демо.

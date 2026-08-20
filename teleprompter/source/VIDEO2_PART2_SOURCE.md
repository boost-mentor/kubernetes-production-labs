# VIDEO2 · Часть 2 · Scheduler: почему Pod попал именно на эту ноду

> Читай только «ГОВОРЮ». «ЭКРАН», «ПОКАЗАТЬ» и «ПОСЛЕ КОМАНДЫ» — режиссёрские карточки. Команды вставляются из отдельного ручного командника по ID.

---

## C2.0 · DEVOPS MAY CRY и задача этой части

**Время:** 00:00–04:00  
**ЭКРАН:** доска: агентство → диспетчерская → три Kubernetes-ноды.

### 🎙 ГОВОРЮ

«DEVOPS MAY CRY — наша учебная ночная диспетчерская. В первой части мы собрали для неё кластер и запустили Go-сервис. Теперь решим, где в этом кластере должны жить разные компоненты.

У приложения есть stateless-диспетчеры и PostgreSQL. Диспетчеры можно размножать и раскладывать по workers. Базу иногда приходится привязать к отдельному классу нод: другой диск, больше памяти, отдельная зона отказа. Kubernetes сам не угадает такое решение. Мы задаём его через taints, tolerations, affinity и topology spread.

В этой части я специально получу несколько Pending. Это не поломка стенда. Каждый раз сначала читаю Events, потом меняю ровно одно условие. Так видно, какое правило реально принял Scheduler».

### 🖥 ПОКАЗАТЬ

- `kubernetes/devops-may-cry/base`: две реплики stateless-приложения.
- `02_ЧАСТЬ_2_SCHEDULER/15_2.2_taint_toleration`: два варианта PostgreSQL.
- На доске: node1 — control plane; node2/node3 — workers.

### ПЕРЕХОД

«Начну не с YAML из интернета, а со схемы, которую знает сам API Server».

---

## C2.1 · required, preferred и длинный хвост IgnoredDuringExecution

**Время:** 04:00–11:00  
**ЭКРАН:** терминал, затем `kubectl explain` рядом с доской Scheduler.

### 🎙 ГОВОРЮ

«`required` — обязательное условие. Если подходящей ноды нет, Pod остаётся Pending. `preferred` — вес в пользу подходящей ноды; Scheduler может выбрать другую, если идеального варианта нет.

Хвост `IgnoredDuringExecution` относится к уже запущенному Pod. Условие проверяется при планировании. Если потом label ноды изменился, kubelet не выселяет Pod только из-за этого. Через несколько минут это проверим на PostgreSQL».

{{COMMAND:V2-C2-S01-C01}}

### 🧠 ЧТО ЭТО ЗНАЧИТ

`kubectl explain` берёт OpenAPI-схему из текущего API Server. Это надёжнее памяти и случайного блога: поля соответствуют версии нашего кластера.

### ПЕРЕХОД

«Теперь зададим ноде две независимые характеристики: label говорит, что это database-нода; taint запрещает случайным Pod'ам на неё заходить».

---

## C2.2 · Taint отталкивает, toleration разрешает вход

**Время:** 11:00–26:00  
**ЭКРАН:** `postgres-pending.yaml` → `postgres-scheduled.yaml` → терминал.

### 🎙 ГОВОРЮ

«На node3 ставлю label `tier=database` и taint `dedicated=database:NoSchedule`. Label сам никого не притягивает. Taint сам не выбирает нужный workload — он только не пускает Pod без пропуска.

Секрет создаю из терминала с выключенным echo. В Git пароль не хранится, на экране его тоже нет. Для настоящего production здесь был бы внешний secret manager или оператор, но механизм Scheduler от этого не меняется».

{{COMMAND:V2-C2-S02-C01}}

### 🖥 ПОКАЗАТЬ

Открыть `postgres-pending.yaml` и назвать четыре вещи:

1. required nodeAffinity ищет label database;
2. toleration отсутствует;
3. образ PostgreSQL закреплён digest'ом;
4. данные лежат в `emptyDir` — это одноразовая scheduler-лаба, не production storage.

### 🎙 ГОВОРЮ

«Этот манифест намеренно неполный. Он хочет node3 по affinity, но не умеет пройти её taint. Применяю и не гадаю по статусу — читаю Events».

{{COMMAND:V2-C2-S02-C02}}

### 🎙 ГОВОРЮ

«В исправленном файле появляется toleration с тем же key, value и effect. Теперь два фильтра согласованы: affinity выбирает класс ноды, toleration разрешает вход. ConfigMap передаёт SQL-инициализацию отдельно от образа».

### 🖥 ПОКАЗАТЬ

- `postgres-scheduled.yaml`: tolerations и nodeAffinity рядом.
- probes, requests/limits, non-root security context.
- `emptyDir` проговорить как ограничение этой лаборатории.

{{COMMAND:V2-C2-S02-C03}}

### 🏭 В ПРОДЕ

Боевой PostgreSQL обычно живёт в managed-сервисе или под оператором со StatefulSet, CSI/PVC, backup и проверенным restore. Здесь нужен живой процесс базы для Scheduler, поэтому storage одноразовый и это подписано прямо в манифесте.

### ПЕРЕХОД

«Pod запущен на node3. Теперь удалю label и проверю, что означает слово Ignored в длинном имени правила».

---

## C2.3 · NodeAffinity не является постоянным контроллером

**Время:** 26:00–34:00  
**ЭКРАН:** Pod на node3 → удаление label → тот же Pod → пересоздание.

### 🎙 ГОВОРЮ

«Сначала фиксирую имя Pod и ноду. Удаляю label. Запущенный процесс остаётся на месте: Scheduler не пересматривает его каждую секунду, а kubelet не выселяет его из-за nodeAffinity».

{{COMMAND:V2-C2-S03-C01}}

### 🎙 ГОВОРЮ

«Удаляю Pod. Deployment создаёт новый, и вот для нового планирования label уже обязателен. Получаем Pending. Возвращаю label — условие снова выполнимо, Pod запускается».

{{COMMAND:V2-C2-S03-C02}}

### 🧠 ЧТО ЭТО ЗНАЧИТ

Affinity — входное условие Scheduler. Это не policy engine, который непрерывно двигает уже запущенные Pod'ы. Для постоянного контроля конфигурации нужны отдельные проверки и автоматика.

### ПЕРЕХОД

«С базой закончили. Возвращаю node3 в общий worker-pool и перехожу к доступности stateless-приложения».

---

## C2.4 · Pod anti-affinity: полезное правило может заблокировать scale

**Время:** 34:00–48:00  
**ЭКРАН:** base Deployment → required anti-affinity patch → Pod'ы на двух workers.

### 🎙 ГОВОРЮ

«Удаляю одноразовую базу, secret и configmap, снимаю taint и label. Это обязательный cleanup: в следующей части обе worker-ноды снова нужны приложению.

В base у DEVOPS MAY CRY мягкая anti-affinity и мягкий topology spread. Две реплики стараются разойтись, но правило не блокирует rollout».

{{COMMAND:V2-C2-S04-C01}}

### 🖥 ПОКАЗАТЬ

- `kubernetes/devops-may-cry/base/deployment.yaml`.
- `podAntiAffinity.preferred...`.
- `topologySpreadConstraints`, `topologyKey: kubernetes.io/hostname`.

### 🎙 ГОВОРЮ

«Если добавить required anti-affinity поверх живого RollingUpdate с `maxUnavailable: 0`, surge Pod сам может заблокировать rollout раньше нашей проверки. Поэтому для этой лаборатории делаю воспроизводимый reset: временно scale в ноль, жду удаления старых Pod'ов, применяю required-правило и сразу запускаю три новые реплики. Это лабораторный приём, а не рекомендация останавливать production.

Workers только два. Первые две реплики размещаются, третьей физически негде выполнить правило».

{{COMMAND:V2-C2-S04-C02}}

### 🎙 ГОВОРЮ

«Это нормальный компромисс: required защищает от совместного падения, но может остановить масштабирование и rollout. Для небольшого кластера часто разумнее `preferred`, плюс PDB и запас capacity. Удаляю жёсткое поле и возвращаю две реплики».

{{COMMAND:V2-C2-S04-C03}}

### ПЕРЕХОД

«Anti-affinity отвечает на вопрос “не клади рядом с такими Pod'ами”. Topology spread формулирует цель иначе: держи измеримый перекос не больше заданного».

---

## C2.5 · Topology spread: maxSkew считаем по фактическим нодам

**Время:** 48:00–58:00  
**ЭКРАН:** `hard-spread-patch.yaml` → таблица Pod/NODE.

### 🎙 ГОВОРЮ

«Патч задаёт `topologyKey: kubernetes.io/hostname`, `maxSkew: 1` и `DoNotSchedule`. На четырёх репликах ожидаю два Pod'а на node2 и два на node3. На пяти — три и два. Не важны конкретные имена Pod'ов; важна разница между доменами».

{{COMMAND:V2-C2-S05-C01}}

### 🧠 ЧТО ЭТО ЗНАЧИТ

`maxSkew: 1` не означает “всегда поровну”. Для нечётного числа реплик разница в одну допустима. При недоступной зоне `DoNotSchedule` может оставить Pod Pending; `ScheduleAnyway` разрешает работу ценой временного перекоса.

{{COMMAND:V2-C2-S05-C02}}

### ПЕРЕХОД

«До сих пор ограничения жили в PodSpec. Теперь поставим рамки на весь namespace команды».

---

## C2.6 · LimitRange и ResourceQuota работают в паре

**Время:** 58:00–68:00  
**ЭКРАН:** `limitrange_resourcequota.yaml` → Pod resources → quota Used/Hard.

### 🎙 ГОВОРЮ

«LimitRange задаёт минимум, максимум и defaults для одного контейнера. ResourceQuota считает суммарное потребление namespace. Это разные задачи.

Создаю отдельный `team-dev`, чтобы учебная квота не сломала `traffic-lab`. Запускаю nginx без resources. Admission подставляет defaults из LimitRange до того, как quota посчитает запрос».

{{COMMAND:V2-C2-S06-C01}}

### 🖥 ПОКАЗАТЬ

- `defaultRequest` и `default`.
- суммарные `requests.cpu`, `limits.cpu`, число Pod/Service/PVC.
- лимит на `services.loadbalancers`: в облаке такой Service может стоить денег.

### 🎙 ГОВОРЮ

«Второй Pod просит 64 CPU. API отклоняет объект до запуска контейнера. Поэтому искать его application logs бессмысленно: процесса не было. После доказательства удаляю весь namespace».

{{COMMAND:V2-C2-S06-C02}}

### ПЕРЕХОД

«Финальная привычка этой части: Pending — это статус, а не диагноз».

---

## C2.7 · Pending triage: три симптома, три причины

**Время:** 68:00–79:00  
**ЭКРАН:** три Pod'а → Events каждого → cleanup.

### 🎙 ГОВОРЮ

«Создам три Pending одновременно. Первый требует несуществующий label `disktype=nvme`. Второй просит 64 CPU и 200 GiB памяти. Для третьего временно taint'ю оба workers, а toleration ему не даю.

`kubectl get pods` покажет один и тот же статус. `describe` в Events разделит причины. Это быстрее, чем наугад править image, CNI или приложение».

{{COMMAND:V2-C2-S07-C01}}

### 🧠 ЧТО ЭТО ЗНАЧИТ

Порядок triage короткий: Scheduler Events → node labels/taints → allocatable и requests → только потом более редкие причины. Если Pod ещё не назначен на ноду, пустые application logs ожидаемы.

### 🎙 ГОВОРЮ

«Перед переходом снимаю оба maintenance-taint и удаляю namespace. Затем проверяю, что DEVOPS MAY CRY снова Ready. Без этого следующая часть началась бы на испорченном стенде».

{{COMMAND:V2-C2-S07-C02}}

### ПЕРЕХОД

«Scheduler выбрал ноду по requests и правилам размещения. В части 3 посмотрим, что после запуска делают limits, cgroups, OOM, throttling, HPA, VPA и Cluster Autoscaler».

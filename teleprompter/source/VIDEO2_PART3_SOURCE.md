# VIDEO2 · Часть 3 · Ресурсы, отказы и автомасштабирование

> Рабочий суфлёр. Читай блоки «ГОВОРЮ». Строки «ЭКРАН», «ПОКАЗАТЬ» и «ЕСЛИ НЕ СОВПАЛО» управляют записью. Команды подставляются из отдельного ручного командника по стабильным ID.  
> Целевой чистый хронометраж: 1:50–2:25. С ожиданиями Metrics Server, VPA и новой managed-ноды сырьё займёт 3–4 часа.  
> Если фактический вывод расходится с «После команды», останови дубль. Не объясняй результат, которого нет на экране.

---

## C3.0 · Сначала измерение, потом масштабирование

**Время:** 00:00–12:00  
**ЭКРАН:** доска, блок Ч3 → VS Code, `03_ЧАСТЬ_3_SCALING/21_3.0_metrics_server`.

### 🎙 ГОВОРЮ

«В предыдущей части мы разобрали, как scheduler выбирает ноду. Теперь посмотрим, что происходит после назначения: какие ограничения получает процесс, почему один контейнер замедляется, а другой завершается, и кто добавляет Pod'ы или ноды.

DEVOPS MAY CRY остаётся тем же приложением. Мы не меняем бинарник под каждый вывод. Меняем policy вокруг него: requests, limits, QoS, HPA и VPA. Так видно, что поведение создаёт Kubernetes-конфигурация, а не скрытая разница между тестовыми приложениями.

Масштабирование начинается не с HPA, а с измерения. В обычном кластере `kubectl top` не читает данные прямо из kubelet. Команда идёт в aggregated API `metrics.k8s.io`, который обслуживает Metrics Server. Он хранит короткий актуальный срез CPU и memory. Это не замена Prometheus: истории, алертов и произвольных метрик здесь нет.

Сначала фиксирую корень клона, два kube-context и pinned Kubespray. До изменения проверяю, существует ли Metrics API. Ошибка `Metrics API not available` в этой точке — ожидаемое состояние, а не поломка стенда».

### 🖥 ПОКАЗАТЬ ДО КОМАНДЫ

1. `03_ЧАСТЬ_3_SCALING/21_3.0_metrics_server/addons-metrics-server.yml`.
2. `metrics_server_enabled: true`.
3. Учебный параметр `metrics_server_kubelet_insecure_tls: true`.
4. `kubespray/VERSION` — upstream закреплён, не скачивается из случайной ветки.

{{COMMAND:V2-C3-S01-C01}}

### 🎙 ГОВОРЮ ПЕРЕД УСТАНОВКОЙ

«Копирую два параметра в group_vars нашего inventory и запускаю официальный `cluster.yml` только с тегом `metrics_server`. Ansible-вызов и выбранная роль остаются видны в кадре.

После `PLAY RECAP` проверяю три разных слоя. Deployment должен раскатиться. Aggregated APIService должен стать Available. И только затем сырой API и `kubectl top` должны вернуть samples».

{{COMMAND:V2-C3-S01-C02}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

Metrics Server опрашивает kubelet summary API, а API Server публикует его через aggregation layer. HPA позже читает тот же resource metrics API. Сам `kubectl top` ничего не измеряет — он форматирует готовый ответ.

### ⚠️ PRODUCTION NUANCE

В учебном стенде включён TLS-компромисс для self-signed kubelet serving certificates. В рабочей среде такой флаг не копируют автоматически: выпускают проверяемые serving-сертификаты, настраивают trust chain и проверяют APIService. Зелёный `kubectl top` также не подтверждает, что requests/limits выбраны правильно.

### ПЕРЕХОД

«Метрики появились. Теперь откроем один Pod одновременно глазами scheduler и глазами Linux kernel».

---

## C3.1 · Requests для scheduler, limits для cgroup

**Время:** 12:00–25:00  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/22_3.1_requests_limits_cgroup/requests_limits.yaml` → терминал → SSH на worker.

### 🎙 ГОВОРЮ

«В `requests_limits.yaml` три Deployment используют один immutable image DEVOPS MAY CRY. Сейчас беру вариант `Burstable`: request `100m CPU` и `64Mi memory`, limit `500m` и `256Mi`.

Request отвечает на вопрос scheduler: на какой ноде зарезервировать место. Limit отвечает на другой вопрос: сколько процессу разрешит runtime. Scheduler не ждёт фактическую нагрузку и не читает cgroup. Он складывает requests из Pod spec.

Сначала применяю манифест, нахожу конкретный Pod и ноду. Затем показываю его QoS и секцию `Allocated resources` этой ноды».

### 🖥 ПОКАЗАТЬ

- Один и тот же digest image у всех трёх Deployment.
- У `devops-may-cry-burstable`: requests меньше limits.
- `automountServiceAccountToken: false`, non-root, dropped capabilities, read-only root filesystem.
- Не листать весь YAML: остановиться на `resources` и `securityContext`.

{{COMMAND:V2-C3-S02-C01}}

### 🎙 ГОВОРЮ ПЕРЕД SSH

«Теперь проверю, во что kubelet и container runtime превратили limit. В контейнере нет shell и `cat`: образ distroless. Это не недостаток приложения, а уменьшение поверхности атаки.

Поэтому беру container ID из Pod status, а `nodeName` автоматически сопоставляю с `NODE1_SSH_HOST`, `NODE2_SSH_HOST` или `NODE3_SSH_HOST` из локального env. Адрес руками не угадываю. Через SSH и `crictl inspect` получаю PID и читаю cgroup из mount namespace процесса. Public IP нужен только для SSH. Сам Pod работает в private cluster network».

{{COMMAND:V2-C3-S02-C02}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

Для cgroup v2 `memory.max` — предел памяти в байтах. `cpu.max` содержит quota и period: при `500m` контейнер получает примерно половину одного CPU во времени. Kubernetes Quantity из YAML превратился в параметры Linux kernel.

### ⚠️ ЛОВУШКА

Не устанавливать shell в production image ради диагностики. Для редких случаев есть ephemeral debug container, runtime-инструменты на ноде и отдельные debug-образы. Доступ к ноде должен быть ограничен и аудироваться.

### ПЕРЕХОД

«Мы записали память с суффиксом `Mi`. Сейчас покажу, почему это не косметика».

---

## C3.2 · `memory: 128` — это 128 байт

**Время:** 25:00–32:00  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/23_3.2_memory_units/oom_cpu_demo.yaml`, затем терминал.

### 🎙 ГОВОРЮ

«Kubernetes использует формат Quantity. Для CPU `1` означает одно ядро, `1000m` — то же самое, `100m` — десятую часть. Для памяти bare integer — байты. Поэтому `memory: 128` означает не 128 мегабайт, а 128 байт.

`M` — десятичные мегабайты, `Mi` — двоичные mebibytes. Обычно для памяти в манифестах пишут `Mi` и `Gi`, чтобы не гадать о единицах.

В `oom_cpu_demo.yaml` нормальный limit записан как `96Mi`. Для контраста создаю один временный Pod того же DEVOPS MAY CRY image с limit `128`. Полный security context передаю в объекте, поэтому Pod проходит restricted policy namespace. Жду не абстрактный CrashLoop, а конкретный `OOMKilled` и exit code».

### 🖥 ПОКАЗАТЬ

- В `oom_cpu_demo.yaml`: `requests.memory: 64Mi`, `limits.memory: 96Mi`.
- Команду с ошибочным `"memory":"128"`.
- После запуска — jsonpath с исходным limit, reason и exit code.

{{COMMAND:V2-C3-S03-C01}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

API Server не исправляет смысл значения за автора. Он принимает валидную Quantity, runtime создаёт почти нулевой cgroup limit, а kernel завершает процесс, который физически не может уместиться.

### ⚠️ PRODUCTION NUANCE

Такие ошибки лучше ловить до кластера: schema validation, policy engine и review правил на минимальные/максимальные ресурсы. Одной проверки, что YAML парсится, недостаточно.

### ПЕРЕХОД

«Даже с правильными единицами нельзя делить всю память ноды между приложениями. Часть ресурсов Kubernetes оставляет самой машине».

---

## C3.3 · Capacity и Allocatable — не одно число

**Время:** 32:00–39:00  
**ЭКРАН:** терминал, объект `Node/node2`; локального манифеста в этой сцене нет.

### 🎙 ГОВОРЮ

«Capacity — то, что kubelet увидел на машине. Allocatable — то, что нода объявляет доступным Pod'ам после системных резервов и eviction threshold. Scheduler планирует по Allocatable.

В этой лаборатории нет YAML, который создаёт Capacity: это status объекта Node, его заполняет kubelet. Сравниваю оба поля на `node2`, затем смотрю уже назначенные requests и limits».

{{COMMAND:V2-C3-S04-C01}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

Упрощённо: `Allocatable = Capacity − system reserved − kube reserved − eviction reserve`. Точная разница зависит от конфигурации kubelet и ОС. Если reservations не настроены, системные процессы всё равно потребляют ресурсы, но scheduler может этого не учесть достаточно консервативно.

### ⚠️ ЛОВУШКА

Нельзя обещать приложениям 100% RAM ноды. Kernel, runtime, kubelet и системные DaemonSet тоже должны пережить пик. Для capacity planning смотрят Allocatable, DaemonSet overhead и реальное использование, а не только паспорт VM.

### ПЕРЕХОД

«Requests должны помещаться в Allocatable. А вот limits Kubernetes разрешает продать несколько раз».

---

## C3.4 · Overcommit: резервируем меньше, разрешаем больше

**Время:** 39:00–49:00  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/25_3.4_overcommit/requests_limits.yaml` → терминал.

### 🎙 ГОВОРЮ

«У Burstable-варианта request CPU `100m`, limit `500m`. Масштабирую его до двенадцати реплик на двух workers.

Scheduler проверяет сумму requests. Поэтому Pod'ы могут разместиться, даже если сумма limits на ноде превышает 100%. Это overcommit: мы рассчитываем, что не все контейнеры одновременно потребуют максимум.

После rollout показываю `Allocated resources` на node2 и node3. Затем удаляю только три Deployment этой лабы, чтобы следующий отказ не смешивался с фоновыми Pod'ами».

{{COMMAND:V2-C3-S05-C01}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

CPU — compressible resource: при конкуренции процессы получают меньше CPU и работают дольше. Memory — non-compressible: если физическая память закончилась, кто-то будет reclaim'иться, evict'иться или получит OOM. Поэтому одинаковый процент overcommit для CPU и memory имеет разный риск.

### ⚠️ PRODUCTION NUANCE

Overcommit выбирают по профилю нагрузки, p95/p99, SLO и запасу ноды. Если все ночные batch-задачи стартуют одновременно, предположение «пики не совпадут» перестаёт работать. Capacity policy должна учитывать такой сценарий.

### ПЕРЕХОД

«Теперь специально превысим memory limit одного контейнера и отделим cgroup OOM от нехватки памяти на всей ноде».

---

## C3.5 · OOMKilled: limit одного контейнера

**Время:** 49:00–61:00  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/26_3.5_oomkilled/oom_cpu_demo.yaml` → терминал → коротко SSH.

### 🎙 ГОВОРЮ

«В первом документе `oom_cpu_demo.yaml` DEVOPS MAY CRY имеет request `64Mi` и limit `96Mi`. Endpoint `/wound` включён только переменной `LAB_ENDPOINTS_ENABLED=true` в этой изолированной лабе. В обычном base он недоступен.

Приложение выделяет 160Mi и касается каждой страницы памяти. Это важно: просто создать большой slice недостаточно, пока kernel физически не закоммитил страницы.

Применяю файл, оставляю только OOM-вариант, фиксирую restartCount и вызываю `/wound` одноразовым контейнером с тем же image. Жду, пока restartCount действительно увеличится».

### 🖥 ПОКАЗАТЬ

- `LAB_ENDPOINTS_ENABLED: "true"`.
- `limits.memory: 96Mi`.
- Readiness probe и restricted security context.
- Второй Deployment в файле существует для следующей сцены; сейчас он удаляется.

{{COMMAND:V2-C3-S06-C01}}

### 🎙 ГОВОРЮ ПЕРЕД ДОКАЗАТЕЛЬСТВОМ

«Оборванный HTTP-запрос ещё ничего не доказывает. Читаю `Last State` контейнера: reason должен быть `OOMKilled`, exit code — `137`. Это `128 + 9`, где 9 — `SIGKILL`.

Дополнительно смотрю kernel log на той ноде, которую вернул Pod spec; её SSH-адрес команда берёт из локального env. Эта строка зависит от ОС и политики доступа, поэтому переносимый acceptance criterion — Pod status. После проверки удаляю OOM workload».

{{COMMAND:V2-C3-S06-C02}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

Здесь нода могла иметь свободную память. Процесс завершил memory controller именно его cgroup, потому что контейнер превысил собственный limit. kubelet затем перезапустил контейнер внутри того же Pod по restart policy Deployment.

### ⚠️ ЛОВУШКА

Exit `137` часто указывает на SIGKILL, но сам по себе не называет источник. Сверяем `lastState.terminated.reason`, события, метрики и kernel log. `kubectl logs` текущего контейнера без `--previous` может быть пустым или показывать уже новый процесс.

### ПЕРЕХОД

«С памятью процесс завершился. На CPU limit результат другой: процесс останется жив, но будет ждать quota».

---

## C3.6 · CPU throttling: медленнее, но без restart

**Время:** 61:00–72:00  
**ЭКРАН:** второй документ `03_ЧАСТЬ_3_SCALING/27_3.6_cpu_throttling/oom_cpu_demo.yaml` → терминал.

### 🎙 ГОВОРЮ

«У throttled-варианта request `100m`, limit `200m`. Endpoint `/overload` запускает две CPU-bound goroutine на 120 секунд. Контейнер попытается взять больше quota, чем разрешено.

До нагрузки читаю cAdvisor counter `container_cpu_cfs_throttled_periods_total`. После запроса жду двадцать секунд и читаю тот же counter. Проверяю два условия: значение выросло, restartCount остался нулём».

### 🖥 ПОКАЗАТЬ

- `limits.cpu: 200m`.
- Тот же digest DEVOPS MAY CRY.
- Команду выборки одного Pod из cAdvisor metrics по container и pod label.

{{COMMAND:V2-C3-S07-C01}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

Linux CFS выдаёт процессу quota на period. Когда quota исчерпана, runnable thread ждёт следующего периода. Контейнер остаётся Running, но latency растёт. Поэтому «Pod не перезапускается» не означает «CPU limit не влияет».

### ⚠️ PRODUCTION NUANCE

Искать throttling только через `kubectl top` неудобно: top показывает usage sample, а не время ожидания quota. Для расследования нужны throttling counters рядом с latency, saturation и requests. Иногда CPU limit снимают, но это решение принимают по профилю нагрузки, а не как универсальное правило.

### ПЕРЕХОД

«Requests и limits также определяют QoS-класс. Проверим классы на одном image, а потом разберём, чего QoS не гарантирует».

---

## C3.7 · QoS без мифа об абсолютном порядке убийства

**Время:** 72:00–82:00  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/28_3.7_qos_oom/requests_limits.yaml` → терминал.

### 🎙 ГОВОРЮ

«В файле три Deployment одного приложения.

`Guaranteed`: у каждого контейнера заданы CPU и memory, request равен limit. `BestEffort`: requests и limits нет вообще. Всё остальное попадает в `Burstable`.

Применяю файл и проверяю каждый класс как acceptance criterion. Не делаю вывод по имени Deployment — читаю `.status.qosClass`, который присвоил kubelet».

{{COMMAND:V2-C3-S08-C01}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

QoS влияет на параметры cgroup и на поведение kubelet при pressure. Но фраза «BestEffort всегда умирает первым» слишком грубая. При memory pressure kubelet учитывает, превышает ли Pod request, его Priority и насколько usage превышает request. При cgroup OOM внутри собственного limit картина снова другая.

### ⚠️ ЛОВУШКА

Guaranteed не означает «никогда не завершится» и не создаёт дополнительную память. Он фиксирует reservation и limit. Для критичного workload дополнительно нужны PriorityClass, topology, PDB, capacity и нормальные probes.

### ПЕРЕХОД

«OOMKilled был решением memory controller для процесса. Eviction — решение kubelet для Pod. Получим второй результат отдельно».

---

## C3.8 · Evicted — это не OOMKilled

**Время:** 82:00–92:00  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/29_3.8_eviction/eviction-demo.yaml` → терминал.

### 🎙 ГОВОРЮ

«Я не буду забивать память или диск всей worker-ноды. Лаба ограничена одним Pod.

В `eviction-demo.yaml` контейнер пишет 64Mi в `emptyDir`. У volume и container ephemeral-storage limit — 16Mi. `emptyDir.sizeLimit` не создаёт отдельный маленький диск; kubelet периодически считает local ephemeral storage и, когда Pod превышает лимит, evict'ит его.

До запуска показываю, что у нод нет MemoryPressure, DiskPressure и PIDPressure. Затем применяю один Pod и жду конкретный `.status.reason=Evicted`».

### 🖥 ПОКАЗАТЬ

- `restartPolicy: Never`.
- `requests.ephemeral-storage: 8Mi`, `limits: 16Mi`.
- `emptyDir.sizeLimit: 16Mi`.
- Restricted security context и pinned debug image.

{{COMMAND:V2-C3-S09-C01}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

Eviction переводит Pod в phase `Failed` и reason `Evicted`. Это объект уровня kubelet/Pod, не lastState `OOMKilled` одного процесса. Поскольку здесь standalone Pod, controller не создаёт замену. У Deployment на его месте ReplicaSet создал бы новый Pod.

### ⚠️ PRODUCTION NUANCE

Причиной eviction может быть node pressure или Pod-level превышение local storage. Поэтому рядом с reason читают message, events и Node conditions. Массовое удаление всех Failed Pod'ов стирает доказательства и затрагивает чужие workload — здесь удаляем только свой Pod.

### ПЕРЕХОД

«Теперь у нас есть метрики и корректные requests. Этого достаточно, чтобы HPA посчитал нужное число реплик».

---

## C3.9 · HPA: больше Pod'ов по CPU utilization

**Время:** 92:00–106:00  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/30_3.9_hpa/app` → `hpa_lab.yaml` → терминал.

### 🎙 ГОВОРЮ

«Base DEVOPS MAY CRY выглядит как обычный workload: Deployment, ClusterIP Service, PDB, probes, requests/limits и restricted security context. Endpoint нагрузки в base выключен. Overlay `recording` добавляет только `LAB_ENDPOINTS_ENABLED=true` для этой сцены.

В `hpa_lab.yaml` target — Deployment, минимум две реплики, максимум шесть, CPU utilization 50%. Utilization считается относительно CPU request контейнера. Без request HPA по этой метрике не сможет посчитать процент.

Сначала применяю overlay, отдельный debug client и HPA. Проверяю baseline: две Ready-реплики, request `100m`, HPA видит метрику».

### 🖥 ПОКАЗАТЬ

1. `app/base/deployment.yaml`: resources и probes.
2. `app/overlays/recording/enable-lab-endpoints.yaml`: одна env-переменная.
3. `hpa_lab.yaml`: min/max, target 50%, scaleUp и scaleDown behavior.
4. `debug-client.yaml`: отдельный ограниченный Pod, а не shell внутри production image.

{{COMMAND:V2-C3-S10-C01}}

### 🎙 ГОВОРЮ ПЕРЕД НАГРУЗКОЙ

«Из debug client отправляю восемь запросов к `/overload`. Endpoint быстро отвечает, а CPU-работа продолжается девяносто секунд внутри Pod'ов.

Упрощённая формула HPA: `ceil(current replicas × current utilization / target utilization)`. Контроллер применяет tolerance и behavior policy, поэтому число меняется не мгновенно и не обязано перескочить сразу на максимум.

Жду, пока desiredReplicas станет больше двух, показываю новые Pod'ы и затем возвращаю стенд к baseline».

{{COMMAND:V2-C3-S10-C02}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

HPA меняет поле replicas у target workload. Он создаёт Pod'ы через Deployment/ReplicaSet, но не создаёт VM. Если новым Pod'ам некуда сесть, они останутся Pending — это уже задача Cluster Autoscaler.

### ⚠️ ЛОВУШКА

Один короткий spike, отсутствующий request или запаздывающий Metrics API дают другой результат. Scale-down обычно стабилизируют дольше, чтобы реплики не дёргались туда-сюда. В рабочей среде target выбирают по latency, saturation и стоимости, а не потому что `50%` выглядит аккуратно.

### ПЕРЕХОД

«HPA меняет количество Pod'ов. VPA отвечает на другой вопрос: какой request разумно дать одному Pod'у».

---

## C3.10 · VPA в режиме рекомендации, без пересоздания Pod'ов

**Время:** 106:00–120:00 плюс ожидание samples  
**ЭКРАН:** `03_ЧАСТЬ_3_SCALING/31_3.10_vpa/vpa_lab.yaml` → pinned upstream manifests → терминал.

### 🎙 ГОВОРЮ

«VPA состоит из CRD и контроллеров. Для этой сцены нужны CRD, RBAC и recommender. Updater и admission-controller не ставлю: я не хочу, чтобы лаборатория сама пересоздала workload или переписала request.

Source закреплён одновременно тегом `vertical-pod-autoscaler-1.7.0` и точным commit. Перед apply показываю upstream `recommender-deployment.yaml`, затем применяю конкретные CRD/RBAC/recommender manifests. Каждый устанавливаемый объект остаётся виден».

### 🖥 ПОКАЗАТЬ

- `vpa_lab.yaml`: targetRef на DEVOPS MAY CRY.
- `updateMode: "Off"`.
- minAllowed/maxAllowed и controlledResources.
- В терминале — exact tag/commit и отсутствие updater/admission-controller.

{{COMMAND:V2-C3-S11-C01}}

### 🎙 ГОВОРЮ ПЕРЕД ОЖИДАНИЕМ

«Перед созданием VPA сохраняю UID текущих Pod'ов. Recommender нужна история metrics, поэтому опрашиваю не просто существование объекта, а непустую target recommendation.

Когда target CPU/memory появился, сравниваю UID. В `Off` режиме они должны совпасть: VPA посчитал рекомендацию, но ничего не применил».

{{COMMAND:V2-C3-S11-C02}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

VPA анализирует usage samples и предлагает requests. Рекомендация — вход для инженерного решения, а не готовый production values-файл. Её сверяют с p95/p99, startup, OOM, throttling и сезонностью.

### ⚠️ ЛОВУШКА

HPA по CPU utilization делит usage на request. Если VPA одновременно меняет request, горизонтальная формула тоже меняется. Совместную политику проектируют явно: например, VPA рекомендует, а человек обновляет requests; либо HPA масштабирует по метрике, которая не конфликтует с изменяемым request.

### ПЕРЕХОД

«Pod'ы мы масштабировать умеем. Остался случай, когда третий Pod корректный, но двум нодам физически некуда его поставить».

---

## C3.11 · Cluster Autoscaler: Pending создаёт потребность в ноде

**Время:** 120:00–139:00 плюс создание VM  
**ЭКРАН:** `infra/managed/terraform/kubernetes.tf` → `03_ЧАСТЬ_3_SCALING/32_3.11_cluster_autoscaler/devops_may_cry.yaml` → Yandex Cloud UI и терминал.

### 🎙 ГОВОРЮ

«Для Cluster Autoscaler переключаюсь на managed-кластер. Self-managed CA тоже возможен, но ему нужен provider integration и права создавать ноды. В managed node group эту интеграцию обслуживает облако.

Продолжаю тот же Terraform state, которым managed-кластер создан в части 1. Второй одноимённый кластер из другого state не создаю. Перед plan обновляю IAM-токен в текущем терминале: с момента первой части могло пройти больше срока его жизни.

В `infra/managed/terraform/kubernetes.tf` один dynamic block выбирает fixed scale, другой — auto scale. Включаю диапазон от двух до пяти нод. Plan должен менять существующую node group, а не собирать новый кластер. После apply проверяю baseline — ровно две Ready-ноды».

### 🖥 ПОКАЗАТЬ

- `enable_autoscaling` в `main.tf`.
- `fixed_scale` и `auto_scale` в `kubernetes.tf`.
- `min=2`, `max=5`, `initial=node_count`.
- В Yandex Cloud UI — node group и autoscaling range после apply.

{{COMMAND:V2-C3-S12-C01}}

### 🎙 ГОВОРЮ ПЕРЕД PENDING

«Применяю DEVOPS MAY CRY в managed-кластер. У каждой ноды два vCPU, а request каждой реплики ставлю `1500m`. На одну ноду помещается только одна такая реплика. Чтобы rolling update не создал промежуточный surge Pod и не запустил autoscaling раньше нужного кадра, здесь делаю контролируемый lab-reset: временно scale в ноль, меняю request и затем сразу запускаю три реплики. Для production-деплоя так делать не надо; здесь это только способ получить воспроизводимое доказательство scheduler-а.

Две ноды принимают две реплики; третья гарантированно остаётся Pending.

Сначала доказываю причину через событие `Insufficient cpu`. Высокая загрузка CPU сама по себе не является сигналом Cluster Autoscaler. Сигнал — unschedulable Pod, который смог бы разместиться на новой ноде подходящей группы.

Затем жду два факта: число Ready-нод стало больше baseline, и тот же Pending Pod перешёл в Running. После доказательства возвращаю request `100m` и две реплики».

### 🖥 ПОКАЗАТЬ

- `devops_may_cry.yaml`: две replicas, request `100m`, PDB и topology spread.
- Контролируемый lab-reset: scale в ноль → patch `1500m` → scale до трёх.
- Events Pending Pod.
- В отдельный момент — Yandex Cloud UI, новая VM в node group.
- Финальный `get pods -o wide`: третья реплика сидит на новой ноде.

{{COMMAND:V2-C3-S12-C02}}

### 🧠 ФИЗИЧЕСКИЙ СМЫСЛ

Scheduler создаёт доказательство нехватки места — Pending с причиной. Cluster Autoscaler моделирует, поможет ли новая нода, просит provider увеличить node group, а после регистрации kubelet scheduler назначает тот же Pod.

### ⚠️ PRODUCTION NUANCE

Нода может не появиться из-за quota, недоступной зоны, taint, affinity, слишком большого request или неподходящей node group. Поэтому acceptance criterion включает Pending event, изменение node group, Ready-ноду и Running Pod. Одной строки «autoscaling enabled» в Terraform мало.

### ПЕРЕХОД

«Теперь понятно, как Kubernetes измеряет, ограничивает и масштабирует приложение. В четвёртой части пройдём путь запроса: DNS, Service, EndpointSlice, kube-proxy, NodePort и внешний HA-вход».

---

## C3.12 · Короткий итог части

**Время:** 139:00–143:00  
**ЭКРАН:** итоговая доска Ч3.

### 🎙 ГОВОРЮ

«Соберу цепочку без новых терминов.

Metrics Server дал текущие resource samples. Requests зарезервировали место у scheduler. Limits превратились в cgroup. Memory limit дал OOMKilled, CPU limit — throttling без restart. Kubelet отдельно показал Evicted. HPA увеличил число Pod'ов, VPA в режиме Off посчитал request, Cluster Autoscaler добавил ноду для доказанного Pending.

Это три разных контура. HPA не создаёт VM. VPA не лечит нехватку capacity. Cluster Autoscaler не исправляет неверный request. Когда каждый отвечает на свой сигнал, масштабирование можно проверять по фактам, а не по одному зелёному статусу».

### ✅ ЧЕКПОЙНТ ПЕРЕД Ч4

- Self-managed context остался `kubespray`.
- Managed context остался `yc-managed`.
- HPA, VPA и временные fault-workload удалены или возвращены к baseline.
- Managed DEVOPS MAY CRY: две реплики, request `100m`.
- Node group остаётся auto scale `2..5`; её cleanup будет в финальном cleanup выпуска.

# VIDEO2 — мастер-пульт записи

Один вход для подготовки и записи всех четырёх частей. Основной принцип тот же,
что в удачном пакете первого видео: читаю реплику, показываю указанный файл,
копирую блок с тем же ID, сверяю ожидаемый результат, объясняю его и иду дальше.
Во время REC не открываю README и не ищу команды по проекту.

## Первое действие утром

Открыть этот файл и выполнить раздел «T−60 → REC» сверху вниз:

```bash
open "/Users/vectoreal/Desktop/VIDEO2_CODE/recording/MASTER_RECORDING_PLAN.md"
```

Не начинать с доски, терминала или нового ревью. Сначала этот пульт.

## Что готово

- один переносимый Git-репозиторий без абсолютных ссылок и секретов;
- 45 лабораторных: `13 + 7 + 12 + 13`;
- 94 ручных командных блока: `41 + 15 + 18 + 20`;
- отдельный суфлёр и отдельный командник для каждой части;
- реальное Go-приложение DEVOPS MAY CRY, Dockerfile, Compose + PostgreSQL,
  миграция и отдельные Kubernetes manifests;
- два Terraform root: self-managed пять VM и managed Kubernetes;
- pinned Kubespray, собственные inventory/group_vars и прямой `cluster.yml`;
- MetalLB L2 с реальной установкой; BGP — только reference без выдуманного peer;
- HAProxy L4 + keepalived/VRRP + VIP + измеряемый failover + restore;
- часть 4 доказывает путь запроса до Pod; прямо сказано, что в видео №1 этого
  ещё не было.

## Реальный хронометраж

| Часть | Чистый материал | Реальное сырьё с ожиданиями/дублями |
|---|---:|---:|
| 1. Кластеры, сети, upgrade, MetalLB, HA | 4:51 | 7–9 ч |
| 2. Scheduler | 1:19 | 2–3 ч |
| 3. Ресурсы и scaling | 2:23 | 3–4 ч |
| 4. Путь запроса | 2:20 | 3–4 ч |
| **Итого** | **10:53** | **15–20 ч** |

Это четыре записи, а не один непрерывный десятичасовой дубль. Между частями
сохраняется рабочий стенд. Managed-кластер нужен до конца части 3, три k8s VM и
lb1/lb2 — до конца части 4.

## Канонические файлы

| Что | Путь |
|---|---|
| Код в кадре | `/Users/vectoreal/Desktop/VIDEO2_CODE` |
| Доска: gate части 1 | `/Users/vectoreal/Desktop/VIDEO2_CODE/recording/BOARD_PART1_GATE.md` |
| Команды Ч1 | `/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART1_COMMANDS.md` |
| Команды Ч2 | `/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART2_COMMANDS.md` |
| Команды Ч3 | `/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART3_COMMANDS.md` |
| Команды Ч4 | `/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART4_COMMANDS.md` |
| PDF Ч1 | `/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч1.pdf` |
| PDF Ч2 | `/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч2.pdf` |
| PDF Ч3 | `/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч3.pdf` |
| PDF Ч4 | `/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч4.pdf` |
| PDF все части | `/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_СЛИТЫЙ.pdf` |
| Локальные параметры | `/Users/vectoreal/Desktop/VIDEO2_CODE/recording/.recording.env` |

Исходники `teleprompter/source` и сгенерированные Markdown нужны редактору, не
ведущему. В записи читается PDF, команды копируются только из `commands/`.

## T−60 → REC

### T−60…T−30 — освежить знания, ничего не создавать

30 минут, таймером:

1. Terraform: provider/resource/variable/output/state, `init → validate → plan → apply`,
   module, remote backend и drift.
2. Ansible: inventory/group, play/task/role/handler, `become`, идемпотентность.
3. Kubespray: inventory groups, group_vars, `cluster.yml`, kubeadm под капотом,
   отличие public SSH address от private facts.

Не перечитывать весь Rebrain и не открывать новые материалы. Затем пять минут
по диагонали пролистать PDF Ч1: C1.0, C1.3, C1.4-бис, C1.5-А, C1.9-А/Б.

### T−30…T−20 — доска

Открыть текущую Excalidraw-доску и пройти
`recording/BOARD_PART1_GATE.md`. Обязательные исправления: история первого
видео без ложного browser→Pod, текстовая карточка DEVOPS MAY CRY, обе Calico
панели, актуальные MetalLB/HA подписи. Старые тёмные NS-картинки не импортировать.

### T−20…T−12 — локальный репозиторий

Сначала вне capture проверить активный профиль Yandex Cloud. На текущем
workstation этот gate нельзя считать пройденным, пока `yc iam create-token` не
вернул токен. Если CLI отвечает `No token/federation-id/service-account-key`,
остановиться, выполнить интерактивный `yc init`, выбрать нужные cloud/folder и
повторить проверку ниже. Сам токен и идентификаторы в кадр или файл не копировать.

```bash
cd "/Users/vectoreal/Desktop/VIDEO2_CODE"
git status --short
git describe --tags --exact-match HEAD
test "$(find 01_ЧАСТЬ_1_КЛАСТЕР 02_ЧАСТЬ_2_SCHEDULER 03_ЧАСТЬ_3_SCALING 04_ЧАСТЬ_4_TRAFFIC -mindepth 2 -maxdepth 2 -name commands.sh | wc -l | tr -d ' ')" = 45
python3 scripts/build-recording-artifacts.py --check
bash scripts/verify-static.sh
test -f recording/.recording.env || cp recording/recording.env.example recording/.recording.env
test -s "$HOME/.ssh/id_ed25519.pub" || ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ''
test -f infra/self-managed/terraform/terraform.tfvars || \
  cp infra/self-managed/terraform/terraform.tfvars.example \
     infra/self-managed/terraform/terraform.tfvars
test -f infra/managed/terraform/private.auto.tfvars || \
  cp infra/managed/terraform/private.auto.tfvars.example \
     infra/managed/terraform/private.auto.tfvars
VIDEO2_PUBLIC_IP="$(curl -fsS https://api.ipify.org)"
printf 'Current recording egress IP: %s/32\n' "$VIDEO2_PUBLIC_IP"
perl -0pi -e 's/allowed_ssh_cidr\s*=\s*"[^"]+"/allowed_ssh_cidr = "'"$VIDEO2_PUBLIC_IP"'\/32"/' \
  infra/self-managed/terraform/terraform.tfvars
perl -0pi -e 's/allowed_nodeport_cidr\s*=\s*"[^"]+"/allowed_nodeport_cidr = "'"$VIDEO2_PUBLIC_IP"'\/32"/; s/allowed_api_cidr\s*=\s*"[^"]+"/allowed_api_cidr = "'"$VIDEO2_PUBLIC_IP"'\/32"/' \
  infra/managed/terraform/private.auto.tfvars
rg 'allowed_(ssh|nodeport|api)_cidr' \
  infra/self-managed/terraform/terraform.tfvars \
  infra/managed/terraform/private.auto.tfvars
command -v yc >/dev/null
export YC_TOKEN="$(yc iam create-token)"
export YC_CLOUD_ID="$(yc config get cloud-id)"
export YC_FOLDER_ID="$(yc config get folder-id)"
test -n "$YC_TOKEN" && test -n "$YC_CLOUD_ID" && test -n "$YC_FOLDER_ID"
yc compute instance list --folder-id "$YC_FOLDER_ID" >/dev/null
printf 'Yandex CLI/Terraform auth: OK\n'
recording/backstage/kubespray/bootstrap.sh
```

Ожидается чистый Git, release-tag, 45 лабораторных, 94 совпавших command ID и
зелёный static QA. Bootstrap только заранее скачивает pinned upstream Kubespray
и Python dependencies в ignored-каталоги. В REC установка кластера идёт прямой
командой `ansible-playbook`, не helper'ом.

В `.recording.env` до запуска стенда заполнить только путь к ключу, SSH user,
контексты и HA-значения. Пять адресов и MetalLB pool пока оставить пустыми.
Команды выше заранее создают два ignored tfvars, подставляют текущий внешний
адрес ноутбука `/32` и проверяют SSH public key; TEST-NET `203.0.113.42/32` в
REC оставаться не должен. Они также проверяют активный профиль `yc` и получают
короткоживущий IAM-токен только в окружение shell, не в файл. Перед Cluster
Autoscaler в Ч3 command deck обновит этот токен ещё раз. Эти три локальных файла
и значения авторизации никогда не показывать в кадре.

### T−12…T−7 — открыть ровно нужные окна

Основное окно VS Code, попадает в запись:

```bash
code -n "/Users/vectoreal/Desktop/VIDEO2_CODE"
```

Второе окно VS Code, не попадает в запись:

```bash
code -n "/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART1_COMMANDS.md"
```

Браузер:

```bash
open -a "Google Chrome" \
  "https://boostmentor.ru/dashboard/courses/devops-school/lesson/g8-project-cluster-lab1" \
  "https://console.yandex.cloud/" \
  "https://github.com/boost-mentor/kubernetes-production-labs"
```

Плюс оставить текущую вкладку Excalidraw. В основном VS Code Explorer скрывает
служебные Markdown/PDF/recording-папки и показывает код, Terraform, Ansible,
Kubespray contract, manifests и 45 lab-папок.

### T−7…T−4 — PDFOverlay

```bash
defaults write com.local.pdfoverlay PDFOverlay.lastPDFPath \
  "/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч1.pdf"
defaults write com.local.pdfoverlay PDFOverlay.captureHidden -bool true
open "/Users/vectoreal/PDFOverlay/PDFOverlay.app"
```

Хоткеи:

- `⌘⇧X` — следующая страница;
- `⌘⇧Z` — предыдущая;
- `⌘⇧=` / `⌘⇧−` — масштаб;
- `⌘⇧N` — новое окно, `⌘⇧C` — сменить активное окно.

Проверить короткой записью OBS: PDFOverlay виден ведущему, но не попал в capture.

### T−4…T−1 — техника

- питание ноутбука подключено, сна нет;
- свободно не меньше 80 ГиБ;
- микрофон выбран, gain не клипует;
- 20 секунд теста: голос, терминал, браузер, шрифт, курсор;
- уведомления выключены;
- секреты, email, cloud/project IDs и `.recording.env` не видны;
- VPN/Red Shield не выключать, не перезапускать и не перенастраивать.

### T−0 — запись

`OBS REC → 3 секунды тишины → хлопок → C1.0`.

## Часть 1 — маршрут записи

| Сцена | Чистое время | Что происходит |
|---|---:|---|
| C1.0 | 00:00–06:00 | доказанный recap видео №1, DEVOPS MAY CRY |
| C1.1 | 06:00–17:00 | Terraform local: plan/apply/state/drift |
| C1.2 | 17:00–29:00 | Ansible: inventory, playbook, handler, idempotency |
| C1.2-бис | 29:00–39:00 | настоящий upstream Kubespray до запуска |
| C1.3-А | 39:00–55:00 | обычный урок BoostMentor, один 5-VM стенд, Yandex UI |
| C1.3-Б | 55:00–78:00 | эквивалентный 5-VM Terraform root, UI proof, destroy |
| C1.4 | 78:00–93:00 | managed Kubernetes Terraform root |
| C1.4-бис | 93:00–108:00 | прямые inventory, SSH, sudo, private facts |
| C1.5-А | 108:00–131:00 | прямой Kubespray `cluster.yml`; ожидание вне REC |
| C1.5-Б/В | 131:00–154:00 | доказательства кластера; bits → IPv4 → subnet |
| C1.6 | 154:00–171:00 | Calico comparison + veth/IPAM/routes/overlay |
| C1.7 | 171:00–188:00 | два kubeconfig; cordon/drain/PDB |
| C1.8 | 188:00–228:00 | настоящий upgrade; managed vs self-managed |
| C1.9-А | 228:00–251:00 | MetalLB 0.16.1, L2 live, BGP reference |
| C1.9-Б | 251:00–282:00 | HAProxy/keepalived, VIP, failover, restore |
| C1.10 | 282:00–291:00 | итог и мост в Scheduler |

### Запуск пяти VM в C1.3-А

В кадре открыть обычный урок, перейти в практику, назвать ровно тот срок,
который показывает UI, и нажать одну кнопку запуска. Сразу сказать «АНТРАКТ» и
остановить REC. После готовности:

1. скачать ключ;
2. вне capture заполнить `NODE1_SSH_HOST`…`LB2_SSH_HOST` и путь к ключу;
3. убедиться, что до конца таймера не меньше восьми часов;
4. если меньше — разделить Ч1 по checkpoint перед C1.4-бис, а не надеяться на
   продление;
5. прогнать вне REC `recording/backstage/kubespray/prepare-inventory.sh` и
   `recording/backstage/kubespray/preflight.sh`;
6. по Ansible facts узнать private subnet, затем в панели/IPAM площадки подтвердить
   свободный зарезервированный диапазон и только после этого заполнить
   `NODE_SUBNET_CIDR`, `METALLB_POOL_START`, `METALLB_POOL_END`;
7. вернуть REC со словом «РУБЕЖ» и в кадре повторить те же проверки прямыми
   командами из command deck.

### Ожидания и дубли

- хороший законченный дубль: сказать «ИЗУМРУД»;
- длинное ожидание: «АНТРАКТ», после возврата «РУБЕЖ»;
- ошибка: «БРАК-БРАК», остановить REC, восстановить состояние, начать сцену с
  полного переходного предложения;
- если фактический вывод не совпал с «Ожидаю», ничего не придумывать в эфире.

## Части 2–4

Перед каждой следующей частью заменить только PDF и командник. Для Ч2:

```bash
code -n "/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART2_COMMANDS.md"
defaults write com.local.pdfoverlay PDFOverlay.lastPDFPath \
  "/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч2.pdf"
open "/Users/vectoreal/PDFOverlay/PDFOverlay.app"
```

Для Ч3:

```bash
code -n "/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART3_COMMANDS.md"
defaults write com.local.pdfoverlay PDFOverlay.lastPDFPath \
  "/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч3.pdf"
open "/Users/vectoreal/PDFOverlay/PDFOverlay.app"
```

Для Ч4:

```bash
code -n "/Users/vectoreal/Desktop/VIDEO2_CODE/commands/VIDEO2_PART4_COMMANDS.md"
defaults write com.local.pdfoverlay PDFOverlay.lastPDFPath \
  "/Users/vectoreal/Desktop/VIDEO2_CODE/output/pdf/суфлёр_VIDEO2_ч4.pdf"
open "/Users/vectoreal/PDFOverlay/PDFOverlay.app"
```

- Ч2 продолжает тот же DEVOPS MAY CRY/Postgres и заканчивается чистым scheduler-state.
- Ч3 использует self-managed для cgroups/HPA/VPA и существующий managed state
  для Cluster Autoscaler; после доказательства возвращает requests/replicas.
- Ч4 доказывает TCP/DNS/routes/NodePort/Service/EndpointSlice/IPVS и внешний HA.
  Private VIP открывается в браузере через явно названный SSH-туннель лабы;
  production path требует public address и маршрутизацию, туннелем его не называем.

## Что нельзя делать

- не запускать весь `commands.sh` или весь command deck целиком;
- не заменять прямые команды `deploy.sh`, `install-and-demo.sh` или другим
  backstage-helper'ом в кадре;
- не показывать `.recording.env`, state, tfvars, private key или реальный inventory;
- не считать `PLAY RECAP` доказательством готовности без nodes/pods/HTTP;
- не считать `EXTERNAL-IP` доказательством внешней доступности MetalLB;
- не обещать конкретное время failover — читать измеренный probe log;
- не называть C1.7-Б upgrade: это только maintenance drill;
- не менять VPN, routes или DNS ради красивого демо;
- не выполнять cleanup после Ч1, если дальше пишутся Ч2–Ч4.

## Cleanup после последней нужной части

Сначала сохранить запись и proof-логи. Затем выполнить cleanup-блоки из конца
соответствующего command deck по одному и прочитать каждый destroy plan.

- MetalLB удаляется перед внешним HA в части 4 либо финальным cleanup;
- managed Terraform уничтожается только после Cluster Autoscaler в части 3;
- self-managed Terraform-demo уже уничтожен в C1.3-Б;
- рабочий пяти-VM стенд из урока останавливается через платформу после части 4;
- SSH-туннель, temporary namespaces, taints и failed markers удаляются командами
  соответствующих сцен.

После cleanup проверить, что в cloud UI не осталось временных Terraform-ресурсов,
а в платформе нет активного окружения.

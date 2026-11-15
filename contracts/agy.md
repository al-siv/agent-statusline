---
id: agy
title: agy — контракт компонента: статус-лайн Antigravity CLI
kind: contract
status: active
created: 2026-11-15
updated: 2026-11-15
owners: [alsiv]
refs:
  - agy-journal.md
  - ../analysis/2026-11-15-multi-harness-statusline-research.md
---

# agy — контракт компонента

## Map {#map}

- [Purpose](#purpose) — роль контракта и специфика объекта
- [Invariants](#invariants) — INV-1..INV-7: постоянные свойства компонента
- [Specification](#specification) — гомогенизированная текущая спецификация компонента
- [Acceptance gates](#gates) — GATE-1..GATE-3: критерии приёмки
- [Risks](#risks) — RISK-1..RISK-4 с митигациями
- [Q&A](#qa) — QA-1..QA-3: архитектурные и визуальные решения
- Журнал (provenance, нормативной силы не имеет): [agy-journal.md](agy-journal.md)

## Purpose {#purpose}

`agy` — статус-лайн Antigravity CLI (`agy`): скрипт `agy/statusline.sh` (`#!/usr/bin/env bash`), который Antigravity CLI вызывает через хук `statusLine`, передавая JSON состояния сессии (`StatusLineData`) в stdin. Скрипт рендерит одну компактную строку с семантическим цветовым кодированием: градация состояния агента `agent_state` слева, текущая директория, git-ветка (нейтральная на `MAIN_BRANCH`, выделенная на прочих ветках), счётчики незакоммиченных файлов `∆:C+N` и строк `δ:+A/-D`, семейство и сокращённое имя модели с приклеенным цветным уровнем рассуждений `<model>•<eff>` (без дублирования слова `Gemini` и со сжатием `Orchestrator`/`Orchistrator` в `Orch.`), светофор остатка лимитов `5h:X% 7d:Y%` для активного семейства моделей (`gemini` или `3p`) и цветовая градация режима доступа `<mode>` справа (без сегмента объёма контекста).

**Решаемая проблема.** Встроенная палитра статус-лайна Antigravity CLI не отражает одним взглядом различие между активным и простаивающим агентом, домашней и рабочей веткой git, уровнем автономии режима доступа и недельным остатком квоты моделей `Gemini-x` / `Orchestrator`, а префикс `Gemini` и полное слово `Orchestrator` перегружают строку по ширине. Компонент задаёт единую для харнесса цветовую и текстовую раскладку в стиле `claude-code-status-line`, убирая лишний шум (префикс `Gemini`, длинный `Orchestrator`, счётчик использованного контекста) и выделяя операционные состояния.

**Стороны.**

- Пользователь/оператор: считывает состояние сессии в Antigravity CLI; изменяет компонент через контрактный цикл.
- Харнесс Antigravity CLI (`agy`): передаёт `StatusLineData` JSON в stdin настроенного `statusLine` скрипта и отображает первую строку stdout.
- Репозиторий `~/dev/agent-statusline`: источник правды; корневой `AGENTS.md` задаёт политику (`repo-first`, `contract-first`, запрет молчаливого `pull`, conventional commits).
- Рантайм `~/.gemini/antigravity-cli/statusline.sh`: разворачиваемая копия скрипта (привязка в `~/.gemini/antigravity-cli/settings.json` находится за жёсткой системной границей защиты Antigravity и скриптом синхронизации не затрагивается).
- Удалённый репозиторий (`origin`, github.com/al-siv/agent-statusline): точка публикации.

Контракт — единственный нормативный источник компонента: гомогенизированная текущая спецификация. **Принцип восстановимости:** секция Specification несёт полный нормативный состав скрипта, так что `agy/statusline.sh` восстановим из контракта практически как он есть; скрипт — рендер контракта для рантайма. Эпизоды изменений и их замыслы — в журнале [agy-journal.md](agy-journal.md).

## Invariants {#invariants}

INV-1: Компонент — один исполняемый файл `agy/statusline.sh` (`#!/usr/bin/env bash`); внешние зависимости — только `bash`, `jq`, `git`, `awk` и стандартные POSIX/macOS-утилиты (`cat`, `basename`, `sed` с флагом `E`/`I`, `grep`, `tr`, `printf`). Входные данные читаются из stdin (`StatusLineData` / совместимый JSON), переменных окружения (`STATUSLINE_RL_WARN_LEFT`, `STATUSLINE_RL_CRIT_LEFT`, `STATUSLINE_MAIN_BRANCH`, `NO_COLOR`) и рабочего дерева git. Скрипт не делает сетевых запросов, не читает секреты и не обращается к `~/.gemini/antigravity-cli/settings.json`.

INV-2: Репозиторий `~/dev/agent-statusline` — единственный источник правды: рантайм-копия `~/.gemini/antigravity-cli/statusline.sh` обновляется через `./sync.sh push agy`, а намеренные правки рантайма принимаются в репозиторий только после явного подтверждения (`./sync.sh pull --confirmed agy`) и проведения через контрактный цикл.

INV-3: Семантическая раздельность цветовых слоёв: оранжевый (`ORANGE`) и красный (`RED` / `STATE_ERR`) резервируются под количественные пороги квот (плюс ненулевые удаления `-D` в `δ` и критическое состояние `agent_state == error`), не пересекаясь с цветами информационных маркеров (`branch`, `∆:C+N`, `+A`) и нейтральных состояний; `agent_state` кодирует операционный статус (серый `idle` → цветные активные состояния), `•eff` — уровень рассуждений, модель — семейство, `branch` — серый на `MAIN_BRANCH` и жирный ярко-голубой вне её, `<mode>` — режим доступа. При непустом `NO_COLOR` все цветовые переменные и `RESET` обнуляются в `""`.

INV-4: Деградация без падения: отсутствие необязательных полей JSON (`.agent_state`, `.cycle_mode`, `.quota`, `.rate_limits`, `.model`, `.effort`), не-объектные или некорректные значения полей/JSON, отсутствие git-репозитория, пустой JSON `{}` и полностью пустой stdin `""` не приводят к ошибке или шуму в stderr — отсутствующие/некорректные сегменты опускаются, `cwd` при пустом значении падает на `"."`, а скрипт завершается с кодом 0 и непустым выводом.

INV-5: В статус-лайне отсутствует сегмент объёма использованного контекста (`NNNk`) и не читаются поля `.context_window` / переменные `STATUSLINE_CTX_*`.

INV-6: Pre-push hook не обходится: блокировка пуша возвращает к устранению нарушения, а не к отключению проверки.

INV-7: Восстановимость: контракт исчерпывающе описывает все переменные, ANSI-коды палитры, `jq`-выражения, правила нормализации/сокращения модели и `effort`, логику квот `5h`/`7d`, git-счётчики, маппинги цветов `agent_state` и режима доступа, а также разделители строки.

## Specification {#specification}

Состав ниже — полный нормативный состав компонента; реконструкция `agy/statusline.sh` выполняется по этому тексту.

**Чтение входа и конфигурация окружения.**

- Весь stdin считывается в начале работы: `input=$(cat)`.
- Переменные окружения с дефолтами:
  - `RL_WARN_LEFT="${STATUSLINE_RL_WARN_LEFT:-20}"` — порог предупреждения (оранжевый) по остатку квоты в процентах (строго меньше).
  - `RL_CRIT_LEFT="${STATUSLINE_RL_CRIT_LEFT:-5}"` — критический порог (красный) по остатку квоты в процентах (строго меньше).
  - `MAIN_BRANCH="${STATUSLINE_MAIN_BRANCH:-main}"` — имя основной ветки git, отображаемой спокойным серым цветом.

**Палитра ANSI (256 цветов) и `NO_COLOR`.**

- Коды задаются через ANSI-C quoting `$'\033[...m'`:
  - Базовый серый и информационные цвета / светофор: `GRAY=$'\033[38;5;245m'` (`idle`, ветка `MAIN_BRANCH`, ручной режим `ask`/`strict`), `ORANGE=$'\033[38;5;208m'` (предупреждение квоты), `RED=$'\033[38;5;196m'` (критический остаток квоты и ненулевые удаления `-D`), `GREEN=$'\033[38;5;40m'` (новые файлы и добавленные строки), `YELLOW=$'\033[38;5;220m'` (изменённые отслеживаемые файлы), `BRANCH_HI=$'\033[1;38;5;51m'` (ветка, отличная от `MAIN_BRANCH`).
  - Градация состояния агента (`agent_state`): `STATE_INIT=$'\033[38;5;75m'` (`initializing`, `authenticating`), `STATE_WORK=$'\033[1;38;5;81m'` (`thinking`, `working` и прочие не-`idle` значения), `STATE_TOOL=$'\033[1;38;5;214m'` (`tool_use`, `merging`), `STATE_REV=$'\033[1;38;5;201m'` (`reviewing`), `STATE_ERR=$'\033[1;38;5;196m'` (`error`).
  - Градация уровня рассуждений (`•eff`): `EFF_LOW=$'\033[1;38;5;203m'`, `EFF_MED=$'\033[1;38;5;214m'`, `EFF_HIGH=$'\033[1;38;5;118m'`, `EFF_XHIGH=$'\033[1;38;5;201m'` (`xhigh` и `max`).
  - Семейства моделей (обычное начертание): `OPUS=$'\033[38;5;135m'` (Opus / Carbon / Orchestrator), `SONNET=$'\033[38;5;211m'` (Sonnet / Hydrogen), `FABLE=$'\033[38;5;43m'` (Fable / Argon), `HAIKU=$'\033[38;5;75m'` (Haiku / Flash).
  - Градация режима доступа (`<mode>`): `MODE_PLAN=$'\033[38;5;75m'` (`plan` и неизвестные режимы), `MODE_EDIT=$'\033[1;38;5;214m'` (`accept-edits`), `MODE_AUTO=$'\033[1;38;5;118m'` (`auto`), `MODE_BEST=$'\033[38;5;135m'` (`best-of-n`), `MODE_YOLO=$'\033[1;38;5;203m'` (`yolo` / `always-proceed`).
  - Сброс: `RESET=$'\033[0m'`.
- При `[ -n "${NO_COLOR:-}" ]` все 25 переменных (`GRAY`, `ORANGE`, `RED`, `GREEN`, `YELLOW`, `BRANCH_HI`, `STATE_INIT`, `STATE_WORK`, `STATE_TOOL`, `STATE_REV`, `STATE_ERR`, `EFF_LOW`, `EFF_MED`, `EFF_HIGH`, `EFF_XHIGH`, `OPUS`, `SONNET`, `FABLE`, `HAIKU`, `MODE_PLAN`, `MODE_EDIT`, `MODE_AUTO`, `MODE_BEST`, `MODE_YOLO`, `RESET`) обнуляются в `""`.

**Разбор полей входного JSON и нормализация модели / `effort`.**

Каждое поле извлекается через `jq -r ... <<<"$input" 2>/dev/null` с защитой `?` на каждом шаге доступа к свойствам объекта (чтобы не-объектные или некорректные значения не срывали fallback и не писали в stderr):

1. `state`: `.agent_state? // empty`.
2. `mode`: `.cycle_mode? // .mode? // .permission_mode? // empty`.
3. `product`: `.product? // empty`.
4. `cwd`: `.workspace?.current_dir? // .cwd? // "."`. Если `cwd` остался пустым (например, на полностью пустом или некорректном stdin `""`, когда `jq` не получил ни одного JSON-значения), выполняется `[ -z "$cwd" ] && cwd="."`, после чего вычисляется `dir=$(basename "$cwd" 2>/dev/null)`.
5. `raw_model`: `.model?.display_name? // empty` с фильтрацией `sed 's/ context)/)/'`.
6. `model_id`: `.model?.id? // empty`.
7. `eff`: `.effort?.level? // .model?.effort? // empty`. Если `eff` пуст, перебором `for src_eff in "$raw_model" "$model_id"` (с `shopt -s nocasematch` перед циклом и `shopt -u nocasematch` после него) ищется суффикс вида `\((low|medium|high|xhigh|max)\)$` или `-(low|medium|high|xhigh|max)$`; первое совпадение записывается в `eff="${BASH_REMATCH[1]}"`.
8. `model`: `raw_model` преобразуется конвейером `sed -E` (все правила нечувствительны к регистру, флаг `I`):
   1. `s/ \((Low|Medium|High|XHigh|Max)\)$//I` — снимает суффикс `effort` в скобках, уже вынесенный в `•eff`;
   2. `s/Gemini[- ]+//Ig` — удаляет слово `Gemini` с последующим дефисом или пробелом в любой позиции (например, `Gemini 4 Argon` → `4 Argon`);
   3. `s/Pro +(Orch[ei]strator)/\1/Ig` — убирает `Pro ` перед `Orchestrator`/`Orchistrator`;
   4. `s/Orch[ei]strator *\(([^)]+)\)/Orch. \1/Ig` — раскрывает `Orchestrator (Carbon)` / `Orchestrator (Argon)` в `Orch. Carbon` / `Orch. Argon`;
   5. `s/Orch[ei]strator[- ]+/Orch. /Ig` — сокращает `Orchestrator-X` / `Orchistrator X` в `Orch. X`;
   6. `s/Orch[ei]strator$/Orch./I` — сокращает голое слово `Orchestrator`/`Orchistrator` на конце строки в `Orch.`.

**Извлечение квот `5h` и `7d` (`quota_parsed` → `five`, `week`).**

- Единый вызов `jq -r --arg mid "$model_id" --arg mname "$raw_model" ... <<<"$input" 2>/dev/null` печатает две строки (`$five` и `$week`), которые считываются в `five` и `week` (изначально обнулены в `""`) через two-line `IFS= read -r` (heredoc) только при `[ -n "$quota_parsed" ]`.
- Вспомогательные функции `jq`:
  - `slugify`: `ascii_downcase | gsub("[^a-z0-9.]+"; "-") | sub("^-+"; "") | sub("-+$"; "")`.
  - `model_family`: по объединённой строке `($mid + " " + $mname)` в нижнем регистре (`ascii_downcase`) возвращает `"gemini"` при совпадении с `"gemini|argon|carbon|hydrogen|flash|orch[ei]strator"`, `"3p"` при совпадении с `"claude|opus|sonnet|haiku|fable|gpt|3p"`, иначе `""`.
  - `bucket_family`: по ключу бакета в `.quota` (приводится к нижнему регистру через `ascii_downcase`) возвращает `"gemini"` при совпадении с `"gemini|argon|carbon|hydrogen|flash|orch[ei]strator"`, `"3p"` при совпадении с `"^3p|claude|opus|sonnet|haiku|fable|gpt"`, иначе `""`.
  - `bucket_win($k; $b)`: по ключу `$k` в нижнем регистре (`ascii_downcase`) возвращает `"7d"` при совпадении с `"weekly|7d|week"`, `"5h"` при совпадении с `"5h|five"`, иначе `"7d"` при `($b.reset_in_seconds? // 0) > 86400`, иначе `"5h"`.
  - `used_pct($b)`: `(100 - ($b.remaining_fraction * 100)) | tostring`.
- Вычисляемые привязки и отбор бакетов из `.quota`:
  - `(($mid + " " + $mname) | model_family) as $fam` — активное семейство модели;
  - `($mid | slugify) as $mslug` и `($mname | slugify) as $nslug` — слаги идентификатора и исходного display-имени модели для точного сопоставления персональных бакетов;
  - `$all`: все записи `.quota? // {}` (если объект), чьи значения — объекты с числовым `remaining_fraction?`;
  - `$fam_entries`: если `$fam != ""`, все элементы `$all`, у которых `(.key | bucket_family) == $fam or .key == $mid or .key == $mslug or .key == $nslug` (иначе `[]`);
  - `$picked`: если `($fam_entries | length) > 0`, используется `$fam_entries`, иначе `$all`.
- Значение `$five`: если `((.rate_limits?.five_hour?.used_percentage? // null) | type) == "number"`, берётся `(.rate_limits.five_hour.used_percentage | tostring)`; иначе первый элемент из `$picked` с `bucket_win(.key; .value) == "5h"`, преобразованный через `used_pct(.value)` (или `""`).
- Значение `$week`: если `((.rate_limits?.seven_day?.used_percentage? // null) | type) == "number"`, берётся `(.rate_limits.seven_day.used_percentage | tostring)`; иначе первый элемент из `$picked` с `bucket_win(.key; .value) == "7d"`, преобразованный через `used_pct(.value)` (или `""`).

**Сборка выходной строки.**

1. **Левый сегмент `agent_state` и `dir`:**
   - При непустом `state` его цвет `scol` выбирается по `$(tr '[:upper:]' '[:lower:]' <<<"$state")`:
     - `idle` → `GRAY`;
     - `initializing` | `authenticating` → `STATE_INIT`;
     - `thinking` | `working` → `STATE_WORK`;
     - `tool_use` | `merging` → `STATE_TOOL`;
     - `reviewing` → `STATE_REV`;
     - `error` → `STATE_ERR`;
     - `*` (любое прочее не-`idle` состояние) → `STATE_WORK`.
   - Начальное значение `out`: `${scol}${state}${RESET}  ${dir}` (если `scol` непуст) или `${state}  ${dir}`; при пустом `state` — `out="$dir"`.

2. **Git-сегменты (`branch`, `∆:C+N`, `δ:+A/-D`):**
   - Ветка определяется командой `branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)`, и если результат пуст — fallback из JSON: `[ -z "$branch" ] && branch=$(jq -r '.vcs?.branch? // empty' <<<"$input" 2>/dev/null)`.
   - Все три git-сегмента выводятся при `[ -n "$branch" ]`:
     - **Ветка:** если `branch = "$MAIN_BRANCH"`, к `out` дописывается `  ${GRAY}${branch}${RESET}`, иначе `  ${BRANCH_HI}${branch}${RESET}`.
     - **Счётчик файлов `∆:C+N`:** всегда показывается (включая `∆:0+0`). По `porc=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)` при непустом `porc`: `n=$(grep -c '^??' <<<"$porc")`, `c=$(grep -vc '^??' <<<"$porc")`; иначе `n=0; c=0`. Дописывается `  ∆:$(col_n "$c" "$YELLOW")+$(col_n "$n" "$GREEN")`, где функция `col_n(number, color)` при `[ "$1" -gt 0 ] 2>/dev/null` печатает `printf '%s%s%s' "$2" "$1" "$RESET"`, а иначе (включая `0`) — нейтральное `printf '%s' "$1"`.
     - **Построчный дифф `δ:+A/-D`:** по `diffstat=$(git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null)` числовые колонки суммируются через `la=$(awk '$1 ~ /^[0-9]+$/ {a+=$1} END{print a+0}' <<<"$diffstat")` и `lr=$(awk '$2 ~ /^[0-9]+$/ {d+=$2} END{print d+0}' <<<"$diffstat")` (бинарные строки с `-` отфильтровываются регулярным выражением `^[0-9]+$`, `+0` гарантирует `0` на пустом выводе). При `[ "$la" -gt 0 ] 2>/dev/null` часть `ap` равна `${GREEN}+${la}${RESET}`, иначе `+${la}`; при `[ "$lr" -gt 0 ] 2>/dev/null` часть `dp` равна `${RED}-${lr}${RESET}`, иначе `-${lr}`. Дописывается `  δ:${ap}/${dp}`.

3. **Сегмент модели (`model`) и уровня рассуждений (`•eff`):**
   - При `[ -n "$model" ]` перебираются `for src in "$raw_model" "$model_id"` (в нижнем регистре, до первого совпадения): `*sonnet*|*hydrogen*` → `SONNET`, `*fable*|*argon*` → `FABLE`, `*haiku*|*flash*` → `HAIKU`, `*opus*|*carbon*|*orchestrator*|*orchistrator*` → `OPUS`. Дописывается `  ${mcol}${model}${RESET}` (или `  $model`).
   - При `[ -n "$eff" ]` нижний регистр `eff_lc` отображается в метку и цвет: `low` → `L` (`EFF_LOW`), `medium` → `M` (`EFF_MED`), `high` → `H` (`EFF_HIGH`), `xhigh` → `XH` (`EFF_XHIGH`), `max` → `X` (`EFF_XHIGH`), прочее → `$eff` без цвета. Разделитель `sep` равен `•` при непустом `model`, иначе `  `. Дописывается `$sep${ecol}${ef}${RESET}` (или `$sep$ef`).

4. **Сегмент квот (`5h:X% 7d:Y%`, слой Traffic Light):**
   - Вспомогательная функция `rl_seg(label, used_pct)`: при пустом `$2` возвращается без вывода; локале-независимый расчёт через `p=$(LC_ALL=C awk -v u="$2" 'BEGIN { if (u !~ /^[+-]?([0-9]+([.][0-9]+)?|[.][0-9]+)([eE][+-]?[0-9]+)?$/) exit 1; p = 100 - sprintf("%.0f", u); if (p <= 0) p = 0; print p + 0 }') || return 0` отбрасывает нечисловой ввод без ошибки и округления к `100%`; если `p < RL_CRIT_LEFT` → `RED`, иначе если `p < RL_WARN_LEFT` → `ORANGE`; печатает `${col}${label}:${p}%${RESET}` (или `${label}:${p}%`).
   - Вызывается по очереди для `5h` (`$five`) и `7d` (`$week`), объединяя непустые части одним пробелом в `rl`. При непустом `rl` дописывается `  $rl`.

5. **Правый сегмент режима доступа (`<mode>`):**
   - Если `mode` пуст, но задан `state` или `product = "antigravity"`, подставляется `mode="ask"` (в `StatusLineData` пустой `cycle_mode` означает ручной режим с подтверждением).
   - При непустом `mode` по значению в нижнем регистре выбираются метка `m_label` и цвет `m_col`:
     - `ask` | `manual` | `default` | `normal` | `request-review` → `ask` (`GRAY`);
     - `strict` → `strict` (`GRAY`);
     - `plan` → `plan` (`MODE_PLAN`);
     - `accept-edits` | `edits` | `proceed-in-sandbox` → `accept-edits` (`MODE_EDIT`);
     - `auto` → `auto` (`MODE_AUTO`);
     - `bestn` | `best-of-n` → `best-of-n` (`MODE_BEST`);
     - `always-proceed` | `bypasspermissions` | `yolo` → `yolo` (`MODE_YOLO`);
     - `*` (прочие значения) → исходный `$mode` (`MODE_PLAN`).
   - Дописывается `  ${m_col}${m_label}${RESET}` (или `  $m_label`).

6. Завершение вывода: `printf '%s\n' "$out"`.

Out of scope (сознательно не в компоненте):

- Вывод и подсчёт использованного контекста (`NNNk`, `.context_window`): намеренно исключён, чтобы не перегружать статус-лайн (`INV-5`).
- Модификация `~/.gemini/antigravity-cli/settings.json`: закрыта системной границей защиты Antigravity CLI; пользовательские конфиги в этом файле правятся только самим пользователем вручную.
- Repo-механика (`sync.sh`, `.hooks/pre-push`, `.harness-pin`): принадлежит уровню репозитория (`AGENTS.md`, `README.md`), а не спецификации скрипта.

## Acceptance gates {#gates}

GATE-1 — полнота спецификации и соответствие рендеру: каждая семантическая точка `agy/statusline.sh` (3 переменные окружения, 24 цветовых кода палитры + `RESET` и `NO_COLOR`, разбор полей `StatusLineData` и fallback `cwd="."`, 6 правил `sed -E` для сокращения модели, извлечение `effort`, парсер `.quota`/`.rate_limits` для `5h` и `7d`, градации `agent_state` и `<mode>`, цвета ветки `MAIN_BRANCH` и офф-`main`, `∆`/`δ` с красным `-D` при `> 0`, отсутствие `NNNk`) покрыта Specification и совпадает с рендером. Verify: построчная сверка `agy/statusline.sh` против `Specification` и тестовые прогоны JSON-пейлоадов (`Gemini 4 Argon`, `Orchestrator (Carbon)`, `Orchestrator (Argon)`, разные `agent_state`/`cycle_mode`, не-`main` ветка, пустой ввод `""` и `{}`).

GATE-2 — синхронизация и гейты харнесса проходят: `./sync.sh status` чист по всем компонентам включая `agy`, `.hooks/pre-push` завершается с кодом 0, `bash -n agy/statusline.sh` чист, деградация на `""` и `{}` вне git-репозитория возвращает код 0 и непустую строку. Verify: вывод `./sync.sh status`, `.hooks/pre-push </dev/null`, `bash -n agy/statusline.sh`, а также явный запуск вне git-репозитория: `(cd /tmp && printf '' | bash "$REPO_DIR/agy/statusline.sh")` и `(cd /tmp && printf '{}' | bash "$REPO_DIR/agy/statusline.sh")` (код 0, непустой вывод).

GATE-3 — независимые аудиты по `RULE-audit-pass` (`audit-prompts` + `audit-causal-structure` для контракта и независимый аудит кода для скрипта) завершены с нулём неустранённых объективных дефектов (либо с зафиксированным решением пользователя). Verify: запись и диспозиция находок в `contracts/agy-journal.md`.

## Risks {#risks}

RISK-1 — Дрейф между рантайм-файлом `~/.gemini/antigravity-cli/statusline.sh` и репозиторием при правках в живой сессии или сбросе привязки в `settings.json`: поскольку `~/.gemini/antigravity-cli/settings.json` закрыт системной границей защиты Antigravity, `./sync.sh` контролирует только сам скрипт `~/.gemini/antigravity-cli/statusline.sh`, но не может автоматически проверить или восстановить секцию `.statusLine` внутри `settings.json`. Mitigation: `./sync.sh push agy` атомарно обновляет рантайм-скрипт без изменения `settings.json`, а при потере привязки оператор однократно восстанавливает путь `~/.gemini/antigravity-cli/statusline.sh` в `settings.json` вручную; правки скрипта в живой сессии возвращаются в репо строго через `./sync.sh pull --confirmed agy` с прохождением контрактного цикла.

RISK-2 — Скрытое изменение JSON-схемы `StatusLineData` или имён квот/моделей в новых релизах `agy`: переименование бакетов (`gemini-5h`, `gemini-weekly`, `3p-*`), полей `.cycle_mode`, `.agent_state` или названий моделей (`Orchestrator (...)`) может нарушить подбор квоты, сокращение имени или цвет. Mitigation: `jq`-парсер распознаёт бакеты как по имени (`5h`/`five`, `weekly`/`7d`/`week`), так и по `reset_in_seconds > 86400`, имеет fallback на `.rate_limits` и `$all`, а `case`-блоки модели/состояний/режимов имеют ветку `*)` с осмысленным цветом/текстом по умолчанию; изменение схемы в новом релизе `agy` закрывается отдельным контрактным эпизодом.

RISK-3 — Зависимость от диалекта `sed -E` с флагом `I`: на старых версиях BSD `sed` (до macOS 14) регистронезависимый флаг `I` в `s/...//I` не поддерживается. Mitigation: компонент нацелен на актуальное рабочее окружение macOS (`/usr/bin/sed` поддерживает флаг `I`), что проверено напрямую на целевой системе; при переносе на среду со старым BSD `sed` оформляется отдельный эпизод по переводу нормализации имени модели на POSIX `awk` (`tolower()`).

RISK-4 — Гонка чтения `bash` при перезаписи `~/.gemini/antigravity-cli/statusline.sh` на месте (in-place write) во время активных сессий `agy`: если редактировать рантайм-файл напрямую, параллельный процесс `bash`, уже читающий этот inode частями, может получить синтаксическую ошибку (`unexpected EOF`). Mitigation: рантайм всегда обновляется через `./sync.sh push agy` (`mktemp` + `mv`, атомарная замена inode), поэтому уже запущенные процессы дочитывают старый inode без сбоя.

## Q&A {#qa}

QA-1 — Как сокращать длинные названия моделей вроде `Orchestrator (Carbon)` / `Orchestrator (Argon)` / `Orchistrator-Gemini 4 Carbon`, чтобы экономить ширину статус-лайна. Decision: удалять `Gemini` (и `Pro` перед `Orchestrator`) в любой позиции названия и сжимать `Orchestrator (X)` / `Orchestrator-X` / `Orchistrator-X` в `Orch. X` (например, `Orch. Carbon`, `Orch. Argon`). Сохраняет мгновенную различимость оркестратора и конкретной модели-исполнителя без лишних скобок и повторения `Gemini`; альтернатива с однобуквенным `Orch(C)` отвергнута ради читаемости названия модели в цвете её семейства.

QA-2 — Какое дефолтное состояние и цвет показывать для режима доступа (`<mode>`), когда Antigravity CLI не передаёт поле `cycle_mode` в `StatusLineData`. Decision: если в payload есть признаки сессии Antigravity (`agent_state != ""` или `product == "antigravity"`), пустое поле интерпретируется как `ask` в спокойном сером цвете (`GRAY`); в самом бинарнике `agy` строка `StatusLineData.cycle_mode` имеет тег `omitempty` и опускается именно в базовом ручном режиме с подтверждением. Альтернатива скрывать `<mode>` при пустом `cycle_mode` отвергнута, чтобы правый сегмент не пропадал и контраст с активными режимами (`plan`, `accept-edits`, `auto`) оставался явным.

QA-3 — Почему `~/.gemini/antigravity-cli/settings.json` не синхронизируется скриптом `sync.sh` в отличие от `qoder` и `claude`. Decision: `~/.gemini/antigravity-cli/settings.json` защищён жёсткой системной границей Antigravity и не должен читаться или изменяться инструментами агента. Поэтому `sync.sh` синхронизирует для `agy` только сам исполняемый скрипт `agy/statusline.sh` ↔ `~/.gemini/antigravity-cli/statusline.sh`, а привязка `statusLine` в `settings.json` считается преднастроенной пользователем.

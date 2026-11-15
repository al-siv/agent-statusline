---
id: claude
title: claude — контракт компонента: статус-лайн Claude Code
kind: contract
status: active
created: 2026-11-15
updated: 2026-11-15
owners: [alsiv]
refs:
  - claude-journal.md
  - ../analysis/2026-11-15-multi-harness-statusline-research.md
---

# claude — контракт компонента

## Map {#map}

- [Purpose](#purpose) — роль контракта и специфика объекта
- [Invariants](#invariants) — INV-1..INV-6: постоянные свойства компонента
- [Specification](#specification) — гомогенизированная текущая спецификация компонента
- [Acceptance gates](#gates) — GATE-1..GATE-3: критерии приёмки
- [Risks](#risks) — RISK-1..RISK-5 с митигациями
- [Q&A](#qa) — QA-1: размещение компонента в едином репозитории agent-statusline (resolved); QA-2: передача пользовательского набора безопасных effort-уровней (resolved)
- Журнал (provenance, нормативной силы не имеет): [claude-journal.md](claude-journal.md)

## Purpose {#purpose}

`claude` — статус-лайн Claude Code: скрипт `claude/statusline.sh` (`#!/usr/bin/env bash`), который Claude Code вызывает на событиях сессии, передавая JSON состояния в stdin. Скрипт рендерит одну строку с семантическим четырёхслойным цветовым кодированием (текущая директория, git-ветка, счётчики изменённых и новых файлов `∆:C+N`, построчный дифф отслеживаемых файлов `δ:+A/-D`, семейство модели с приклеенным уровнем рассуждений `<model>•<eff>`, объём входного контекста `NNNk` относительно окна авто-компактизации, остаток лимитов `5h:X% 7d:Y%`). Визуальный пример рендера — в [`../docs/claude-example.svg`](../docs/claude-example.svg).

**Решаемая проблема.** Оператору Claude Code нужна мгновенно считываемая сводка сессии, в которой каждый цвет имеет ровно одно значение: оранжевый и красный сигнализируют только о приближении к жёсткому потолку (окно авто-компактизации контекста и 5-часовой/7-дневный rate limit), жирный пурпурный — об отклонении `effort` от безопасного набора, цвета семейств моделей (Opus/Sonnet/Fable/Haiku) идентифицируют активную модель без пересечения со светофором, а информационные цвета выделяют git-ветку и изменения рабочего дерева.

**Стороны.**

- Пользователь/оператор: видит строку в Claude Code; правит компонент через контрактный цикл.
- Харнесс Claude Code: вызывает скрипт, передаёт status JSON в stdin, печатает stdout.
- Репозиторий `~/dev/agent-statusline`: источник правды; его `AGENTS.md` задаёт политику (repo-first, contract-first, запрет blanket pull, conventional commits).
- Рантайм `~/.claude/statusline.sh` и привязка `.statusLine` в `~/.claude/settings.json` (`STATUSLINE_SAFE_EFFORT="medium high xhigh" bash ~/.claude/statusline.sh`): разворачиваемая копия и настройка подключения; синхронизация — `sync.sh` (`status` / `push` / `pull [--confirmed claude]`).
- Удалённый репозиторий (`origin`, github.com/al-siv/agent-statusline): точка публикации.

Контракт — источник истины о компоненте: гомогенизированная текущая спецификация, единственный нормативный источник. **Принцип восстановимости:** секция Specification несёт полный нормативный состав скрипта, так что `claude/statusline.sh` восстановим из контракта практически как он есть; скрипт — рендер контракта для рантайма. Эпизоды изменений и их замыслы — в журнале [claude-journal.md](claude-journal.md).

## Invariants {#invariants}

INV-1: Компонент — один исполняемый файл `claude/statusline.sh` (`#!/usr/bin/env bash`); внешние зависимости — только `bash`, `jq`, `git` и `awk` (плюс стандартные POSIX-утилиты `cat`, `basename`, `sed`, `grep`, `tr`, `uname`). Входные данные приходят из stdin харнесса, переменных окружения (`STATUSLINE_*`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, `CLAUDE_CONFIG_DIR`, `NO_COLOR`), рабочего дерева репозитория и локальных файлов настроек Claude Code (только ключи `autoCompactWindow` и `modelSettings` для расчёта порога авто-компактизации). Сетевых запросов скрипт не делает и учётные данные не читает.

INV-2: Репозиторий — единственный источник правды; рантайм `~/.claude/statusline.sh` и привязка `.statusLine` в `~/.claude/settings.json` получают обновления через `./sync.sh push`, а рантайм-правки скрипта входят только через контролируемый adopt (`./sync.sh pull --confirmed claude`).

INV-3: Семантическая раздельность цветовых слоёв: один цвет несёт ровно один тип сигнала — светофор потолков (`ORANGE`, `RED`), внимание к небезопасному `effort` (`MAGENTA_B`), идентичность семейства модели (`OPUS`, `SONNET`, `FABLE`, `HAIKU`), информационные маркеры git (`CYAN`, `YELLOW`, `GREEN`); слои не делят оттенки между собой. При непустом `NO_COLOR` любое цветовое оформление отключается.

INV-4: Деградация без падения: отсутствие необязательных полей JSON, git-репозитория или файлов настроек скрывает соответствующие сегменты либо переводит расчёт на предусмотренный fallback, а скрипт завершается с кодом 0 (особенность поведения на полностью пустом потоке `""` вне git-репозитория отражена в RISK-4).

INV-5: Pre-push hook не обходится: блокировка пуша возвращает к устранению нарушения, а не к отключению проверки.

INV-6: Восстановимость: контракт исчерпывающе описывает поведение скрипта (переменные окружения, палитру, разбор JSON, git-счётчики, сопоставление семейств моделей, алгоритм определения окна авто-компактизации, пороги светофора и сборку строки), так что реконструкция по контракту не требует чтения старой реализации.

## Specification {#specification}

Состав ниже — полный нормативный состав компонента; реконструкция `claude/statusline.sh` выполняется по этому тексту.

**Чтение входа и конфигурация окружения.**

- Весь stdin считывается в начале работы: `input=$(cat)`.
- Переменные окружения с дефолтами:
  - `CTX_WINDOW="${STATUSLINE_CTX_WINDOW:-}"` — явное переопределение окна авто-компактизации в токенах (пусто = автоопределение).
  - `CTX_WARN_PCT="${STATUSLINE_CTX_WARN_PCT:-60}"` — порог предупреждения (оранжевый) в процентах от окна авто-компактизации.
  - `CTX_CRIT_PCT="${STATUSLINE_CTX_CRIT_PCT:-80}"` — критический порог (красный) в процентах от окна авто-компактизации.
  - `RL_WARN_LEFT="${STATUSLINE_RL_WARN_LEFT:-20}"` — порог предупреждения (оранжевый) по остатку rate limit в процентах (строго меньше).
  - `RL_CRIT_LEFT="${STATUSLINE_RL_CRIT_LEFT:-5}"` — критический порог (красный) по остатку rate limit в процентах (строго меньше).
  - `SAFE_EFFORT="${STATUSLINE_SAFE_EFFORT:-high xhigh}"` — список безопасных уровней `effort` через пробел (полные имена), не подсвечиваемых флагом внимания.
  - `MAIN_BRANCH="${STATUSLINE_MAIN_BRANCH:-main}"` — имя основной ветки, отображаемой без цветовой подсветки.

**Палитра ANSI (256 цветов) и `NO_COLOR`.**

- Коды задаются через ANSI-C quoting `$'\033[...m'`:
  - Слой Traffic Light (количественное приближение к потолку): `ORANGE=$'\033[38;5;208m'`, `RED=$'\033[38;5;196m'`.
  - Слой Information (данные git): `GREEN=$'\033[38;5;40m'` (добавления: новые файлы и добавленные строки), `YELLOW=$'\033[38;5;220m'` (изменённые отслеживаемые файлы), `CYAN=$'\033[38;5;45m'` (ветка, отличная от `MAIN_BRANCH`).
  - Слой Attention (отклонение конфигурации запуска): `MAGENTA_B=$'\033[1;38;5;201m'` (жирный пурпурный).
  - Слой Identity (семейство модели, обычное начертание): `OPUS=$'\033[38;5;135m'` (фиолетовый), `SONNET=$'\033[38;5;211m'` (розовый), `FABLE=$'\033[38;5;43m'` (бирюзовый), `HAIKU=$'\033[38;5;75m'` (голубой).
  - Сброс: `RESET=$'\033[0m'`.
- При `[ -n "${NO_COLOR:-}" ]` все одиннадцать переменных (`ORANGE`, `RED`, `GREEN`, `YELLOW`, `CYAN`, `MAGENTA_B`, `OPUS`, `SONNET`, `FABLE`, `HAIKU`, `RESET`) обнуляются в пустую строку `""`.

**Разбор полей входного JSON.**

Каждое поле извлекается через `jq -r ... <<<"$input"`:

1. `cwd`: `.workspace.current_dir // .cwd // "."`.
2. `proj`: `.workspace.project_dir // empty`.
3. `dir`: `basename "$cwd" 2>/dev/null`. Начальное значение выходного буфера: `out="$dir"`.
4. `model`: `.model.display_name // empty` с фильтрацией `sed 's/ context)/)/'` (убирает суффикс ` context)` в скобках размера контекста).
5. `model_id`: `.model.id // empty`.
6. `eff`: `.effort.level // empty`.
7. `ctx`: точное число токенов входного контекста из `.context_window.current_usage`:
   `if . == null then empty else (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) end`.
8. `used`: `.context_window.used_percentage // empty`.
9. `size`: `.context_window.context_window_size // empty`.
10. `five`: `.rate_limits.five_hour.used_percentage // empty`.
11. `week`: `.rate_limits.seven_day.used_percentage // empty`.

Вспомогательная функция `col_n(number, color)`: если `[ "$1" -gt 0 ] 2>/dev/null`, выводит `printf '%s%s%s' "$2" "$1" "$RESET"`, иначе `printf '%s' "$1"` (нулевые значения остаются в цвете по умолчанию).

**Git-сегменты (`branch`, `∆:C+N`, `δ:+A/-D`).**

- Ветка определяется командой `branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)`. Все три git-сегмента выводятся тогда и только тогда, когда `[ -n "$branch" ]`:
  1. **Ветка:** если `branch = "$MAIN_BRANCH"`, к `out` дописывается `  $branch`, иначе `  ${CYAN}${branch}${RESET}`.
  2. **Счётчик файлов `∆:C+N`:** всегда показывается внутри git-репозитория (включая `∆:0+0` на чистом дереве для стабильности раскладки). Из `porc=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)` при непустом `porc` вычисляются `n=$(grep -c '^??' <<<"$porc")` (новые неотслеживаемые файлы) и `c=$(grep -vc '^??' <<<"$porc")` (изменённые/удалённые/индексированные отслеживаемые файлы); при пустом `porc` оба равны `0`. К `out` дописывается `  ∆:$(col_n "$c" "$YELLOW")+$(col_n "$n" "$GREEN")`.
  3. **Построчный дифф отслеживаемых файлов `δ:+A/-D`:** всегда показывается внутри git-репозитория (строки в неотслеживаемых файлах в `δ` не входят). Из `diffstat=$(git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null)` вычисляются `la=$(awk '$1 ~ /^[0-9]+$/ {a+=$1} END{print a+0}' <<<"$diffstat")` и `lr=$(awk '$2 ~ /^[0-9]+$/ {d+=$2} END{print d+0}' <<<"$diffstat")` (бинарные строки с `-` в `numstat` отфильтровываются регулярным выражением `^[0-9]+$`). При `[ "$la" -gt 0 ] 2>/dev/null` часть `ap` равна `${GREEN}+${la}${RESET}`, иначе `+${la}`; удалённые строки `-${lr}` всегда нейтральны. К `out` дописывается `  δ:${ap}/-${lr}`.

**Сегмент модели (`model`).**

- Показывается при `[ -n "$model" ]`.
- Семейство определяется перебором `for src in "$model" "$model_id"`: строка переводится в нижний регистр `tr '[:upper:]' '[:lower:]' <<<"$src"` и сопоставляется в `case`: `*opus*` → `OPUS`, `*sonnet*` → `SONNET`, `*fable*` → `FABLE`, `*haiku*` → `HAIKU`. Поиск прекращается на первом совпадении (`[ -n "$mcol" ] && break`), поэтому `display_name` имеет приоритет над `model.id`.
- При найденном цвете к `out` дописывается `  ${mcol}${model}${RESET}`, при нераспознанном семействе — `  $model` без окраски.

**Сегмент уровня рассуждений (`•eff`).**

- Показывается при `[ -n "$eff" ]`.
- Сокращение `ef`: `low` → `L`, `medium` → `M`, `high` → `H`, `xhigh` → `XH`, `max` → `X`, прочие значения — как есть (`$eff`).
- Разделитель `sep`: если `[ -n "$model" ]`, то буллит `•` (вплотную к имени модели), иначе два пробела `  `.
- Проверка безопасности по полному имени `$eff` в `" $SAFE_EFFORT "`: при совпадении `*" $eff "*` дописывается `$sep$ef` без цвета, иначе — `$sep${MAGENTA_B}${ef}${RESET}`.

**Определение окна авто-компактизации (`acw_settings` и `ctx_window`).**

- Функция `acw_settings` читает `autoCompactWindow` из файлов настроек Claude Code в порядке возрастания приоритета:
  1. `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` (пользовательский),
  2. `${proj:-$cwd}/.claude/settings.json` (проектный),
  3. `${proj:-$cwd}/.claude/settings.local.json` (локальный проектный),
  4. managed-файл: `/Library/Application Support/ClaudeCode/managed-settings.json` при `uname -s = Darwin`, иначе `/etc/claude-code/managed-settings.json`.
- Из каждого существующего файла выбирается `jq -c '{autoCompactWindow, modelSettings}' "$f" 2>/dev/null`, после чего поток агрегируется `jq -rs --arg id "$model_id"`:
  - Канонизация идентификатора модели `canon`: `ascii_downcase | sub("\\[1m\\]$"; "") | sub("^([a-z]+\\.)?anthropic\\."; "") | sub("-v[0-9]+(:[0-9]+)?$"; "") | sub("[-@][0-9]{8}$"; "")` (снимает суффикс `[1m]`, префикс/суффикс Bedrock и суффикс даты).
  - Внутри одного файла `per_model` собирает записи `.modelSettings // {}`, где `.value` — объект с `autoCompactWindow != null`, под ключом `$e.key | canon`; если в одном файле встретились каноническая и неканоническая запись одной модели, побеждает точное совпадение `$e.key == $k`, иначе первая встреченная.
  - Свертка по файлам снизу вверх с начальным состоянием `{default: null, by_model: {}}`: если в файле `$s.autoCompactWindow == null`, его карта моделей накладывается поверх накопленной (`.by_model += $m`); если же в файле задан верхнеуровневый ключ `autoCompactWindow` (включая `"auto"`), он сбрасывает `by_model` нижележащих файлов (`{default: $s.autoCompactWindow, by_model: $m}`).
  - Итоговое значение: если в итоговом `.by_model` есть ключ `($id | canon)`, берётся он, иначе `.default`; результат фильтруется `select(type == "number") | floor` (строка `"auto"` или `null` отбрасываются).
- Функция `ctx_window` определяет окно `w`:
  1. Если задан `CTX_WINDOW` (`STATUSLINE_CTX_WINDOW`), то `w="$CTX_WINDOW"`.
  2. Иначе если задан `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, из него через `awk` берётся ведущее целое число `^[0-9]+` и зажимается в диапазон `100000..1000000`.
  3. Если `w` всё ещё пусто, вызывается `w=$(acw_settings)`.
  4. Защита значения: нечисловое `w` (`''|*[!0-9]*`) и `0` обнуляются в `""`.
  5. Потолок модели: если `size` (`context_window_size`) непуст и `CTX_WINDOW` не задан, то при пустом `w` или `[ "$w" -gt "$size" ]` устанавливается `w="$size"`.

**Сегмент токенов контекста (`NNNk`, слой Traffic Light).**

- Если `ctx` пуст (до первого ответа API `current_usage == null`), но непусты `used` и `size`, `ctx` вычисляется по fallback-формуле `awk -v u="$used" -v s="$size" 'BEGIN{printf "%.0f", u/100*s}'`.
- При непустом `ctx`:
  - Число тысяч: `tk=$(awk -v t="$ctx" 'BEGIN{printf "%.0f", t/1000}')`.
  - При непустом `win=$(ctx_window)` в `awk` вычисляется процент заполнения окна `p = t * 100 / w`: при `p >= CTX_CRIT_PCT` цвет `col="$RED"`, иначе при `p >= CTX_WARN_PCT` цвет `col="$ORANGE"`, иначе без цвета.
  - К `out` дописывается `  ${col}${tk}k${RESET}` (или `  ${tk}k` без цвета).

**Сегменты rate limit (`5h:X%`, `7d:Y%`, слой Traffic Light).**

- Вспомогательная функция `rl_seg(label, used_pct)`:
  - При пустом `$2` ничего не выводит (`return`).
  - Остаток в процентах: `p=$(( 100 - $(printf '%.0f' "$2") ))`; при `[ "$p" -lt 0 ]` зажимается в `0`.
  - Пороги: если `[ "$p" -lt "$RL_CRIT_LEFT" ]` → `col="$RED"`; иначе если `[ "$p" -lt "$RL_WARN_LEFT" ]` → `col="$ORANGE"`; иначе без цвета.
  - Формат: `${col}${label}:${p}%${RESET}` или `${label}:${p}%`.
- Вызывается по очереди для `5h` (`$five`) и `7d` (`$week`); если оба непусты, между ними ставится один пробел (`5h:X% 7d:Y%`), а вся группа `rl` отделяется от предыдущего сегмента двумя пробелами (`out="$out  $rl"`).

**Разделители и вывод.**

- Между основными сегментами (`dir`, `branch`, `∆:C+N`, `δ:+A/-D`, `model•eff`, `NNNk`, группа `5h/7d`) всегда ставятся два пробела `  `; внутри пары `model•eff` ставится `•` (если модель непуста), а между `5h` и `7d` — один пробел.
- Вывод завершается переводом строки: `printf '%s\n' "$out"`.

Out of scope (сознательно не в компоненте):

- Сетевые запросы к API Anthropic и чтение OAuth/API-ключей.
- Repo-механика (`sync.sh`, `.hooks/pre-push`, `.harness-pin`): принадлежит уровню репозитория (`AGENTS.md`, `README.md`), а не спецификации скрипта.

## Acceptance gates {#gates}

GATE-1 — полнота спецификации: каждая семантическая точка `claude/statusline.sh` (переменные окружения и дефолты, 10 цветовых кодов 256-палитры + `RESET` и `NO_COLOR`, 11 полей JSON, git-сегменты с `--no-optional-locks`, сопоставление 4 семейств моделей, сокращение и флаг `effort`, канонизация и иерархия 4 файлов настроек в `acw_settings`/`ctx_window`, расчёт `NNNk` и `5h`/`7d`, форматирование и разделители) покрыта Specification; скрипт восстановим из контракта практически как он есть. Verify: построчная сверка `claude/statusline.sh` против контракта при создании и при каждой правке состава сегментов.

GATE-2 — синхронизация и гейты харнесса проходят: `./sync.sh status` чист (как по файлу `~/.claude/statusline.sh`, так и по `.statusLine` в `~/.claude/settings.json`), `.hooks/pre-push` завершается с кодом 0, `bash -n claude/statusline.sh` чист. Verify: вывод команд при проверке релиза.

GATE-3 — независимый аудит по `RULE-audit-pass` (`audit-prompts` + `audit-causal-structure` для контракта и независимый аудит кода для скрипта). Verify: запись в журнале `contracts/claude-journal.md`.

## Risks {#risks}

RISK-1 — Дрейф рантайма и слетание привязки в `~/.claude/settings.json`: обновление Claude Code или ручная правка конфига может перезаписать `.statusLine` или рассинхронизировать `~/.claude/statusline.sh`. Mitigation: `./sync.sh status` проверяет и сам файл `~/.claude/statusline.sh`, и поле `.statusLine` в `~/.claude/settings.json`, а `./sync.sh push` восстанавливает оба.

RISK-2 — Дрейф контракт↔скрипт: правка скрипта мимо контракта. Mitigation: `RULE-contract-first`, `RULE-reconstructability` и гейт 2 в `.hooks/pre-push`.

RISK-3 — Невидимые скрипту источники окна авто-компактизации: флаг запуска `--autocompact` и серверные дефолты Claude Code не отражаются в status JSON и в файлах `settings.json`. Mitigation: переменная окружения `STATUSLINE_CTX_WINDOW` явно переопределяет автоопределение, а в остальных случаях `ctx_window` повторяет клиентскую иерархию (`CLAUDE_CODE_AUTO_COMPACT_WINDOW` → 4 файла `settings.json` → `context_window_size`).

RISK-4 — Поведение на полностью пустом stdin (`""`) против пустого JSON-объекта (`{}`): поскольку `jq` вызывается без флага `-n`, на пустом потоке `jq -r '.workspace.current_dir // .cwd // "."' <<<""` выдаёт пустую строку (0 входных JSON-значений), тогда как на `{}` возвращает `"."`. В результате на пустом stdin `cwd=""` и `dir=""`: внутри git-репозитория с коммитами `git -C ""` трактуется git как текущий каталог и выводит ветку и счётчики, а вне git-репозитория (или на unborn `HEAD`) строка оказывается пустой (только `\n`). Mitigation: допустимое поведение текущей реализации, так как в рантайме Claude Code всегда передаёт JSON-объект сессии; при необходимости выровнять пустой stdin с `{}` правка оформляется отдельным контрактным эпизодом.

RISK-5 — Предположения о типах и локали в арифметике `rl_seg` и `awk`: `printf '%.0f' "$2"` в `rl_seg` предполагает числовое значение `rate_limits.*.used_percentage` и точку как десятичный разделитель локали, а серия отдельных вызовов `jq` не оборачивает верхнеуровневый вход проверкой `type == "object"`. Mitigation: известное ограничение текущей реализации; при появлении нетипичных payload'ов закрывается отдельным контрактным эпизодом.

## Q&A {#qa}

QA-1 — Где должен жить скрипт статус-лайна Claude Code: в отдельном репозитории `~/dev/claude-code-status-line` или внутри единого репозитория `~/dev/agent-statusline`. Status: resolved (2026-11-15). Decision: скрипт входит в единый репозиторий `~/dev/agent-statusline` как компонент `claude` (`claude/statusline.sh`, превью `docs/claude-example.svg`, контракт `contracts/claude.md`), а рантайм-копия `~/.claude/statusline.sh` и привязка `.statusLine` в `~/.claude/settings.json` управляются через `./sync.sh` (см. [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)), чтобы статус-лайны всех CLI-харнессов макбука синхронизировались и восстанавливались единым механизмом.

QA-2 — Почему пользовательский список `STATUSLINE_SAFE_EFFORT="medium high xhigh"` задаётся в команде `.statusLine.command` файла `~/.claude/settings.json`, а дефолт внутри `claude/statusline.sh` оставлен `high xhigh`. Status: resolved (2026-11-15). Decision: сохранён дефолт скрипта (`high xhigh` на случай автономного запуска) и одновременно закреплена пользовательская конфигурация окружения `STATUSLINE_SAFE_EFFORT="medium high xhigh"` в привязке `.statusLine.command`, которую контролирует и прописывает `./sync.sh`. Это позволяет менять пороги и безопасный список через штатный интерфейс переменных окружения.

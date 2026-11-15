# Расширение agent-statusline на все рабочие CLI-харнессы макбука (2026-11-15)

## Контекст и задача

После переименования репозитория в `~/dev/agent-statusline` (`github.com/al-siv/agent-statusline`) поставлена задача собрать в него статус-лайны всех рабочих CLI-харнессов на макбуке — Qoder CLI (`qoderclicn`), Claude Code (`claude`), Codex CLI (`codex`) и Antigravity CLI (`agy`), — чтобы при обновлении, переустановке или сбросе настроек любого из харнессов статус-лайн и его привязка в конфиге восстанавливались одной командой (`./sync.sh push`).

## 1. Инвентаризация CLI-харнессов макбука

| Харнесс | Способ задания статус-лайна | Артефакт в `agent-statusline` | Рантайм-скрипт | Привязка в рантайм-конфиге |
| --- | --- | --- | --- | --- |
| **Qoder CLI** (`qoderclicn`) | Внешний скрипт (`statusLine.type = "command"`, JSON сессии в stdin) | `qoder/statusline-command.sh` (`#!/bin/sh`) | `~/.qoder-cn/statusline-command.sh` (симлинк `~/.qoder`) | `~/.qoder-cn/settings.json` → `.statusLine = {"type": "command", "command": "~/.qoder-cn/statusline-command.sh"}` |
| **Claude Code** (`claude`) | Внешний скрипт (`statusLine.type = "command"`, JSON сессии в stdin) | `claude/statusline.sh` (`#!/usr/bin/env bash`) + `docs/claude-example.svg` | `~/.claude/statusline.sh` | `~/.claude/settings.json` → `.statusLine = {"type": "command", "command": "STATUSLINE_SAFE_EFFORT=\"medium high xhigh\" bash ~/.claude/statusline.sh"}` |
| **Codex CLI** (`codex`) | Декларативный список встроенных TUI-виджетов в `[tui]` файла `config.toml` | `codex/statusline.toml` | — (внешний скрипт не поддерживается) | `~/.codex/config.toml` → секция `[tui]`: ключи `status_line` и `status_line_use_colors` |
| **Antigravity CLI** (`agy`) | Внешний скрипт (`statusLine` через `~/.gemini/antigravity-cli/settings.json`; `StatusLineData` JSON в stdin) | `agy/statusline.sh` (`#!/usr/bin/env bash`) | `~/.gemini/antigravity-cli/statusline.sh` | Только скрипт (`~/.gemini/antigravity-cli/settings.json` закрыт системной границей защиты Antigravity и `sync.sh` не затрагивается) |

### 1.1. Qoder CLI (`qoder`)

- Скрипт уже находился под управлением этого репозитория (`statusline-command.sh`, контракт `contracts/statusline.md`, журнал `contracts/statusline-journal.md`, `EP-1..EP-6`).
- При переходе к мультикомпонентной структуре файл переносится в `qoder/statusline-command.sh` без изменения содержимого и байтового вывода, а пара контракта и журнала переименовывается в `contracts/qoder.md` и `contracts/qoder-journal.md` (эпизод `EP-7`).
- Дополнительно `sync.sh` берёт под контроль секцию `.statusLine` в `~/.qoder-cn/settings.json`, чтобы при сбросе настроек CLI привязка скрипта проверялась в `sync.sh status` и восстанавливалась в `sync.sh push`.

### 1.2. Claude Code (`claude`)

- Скрипт `statusline.sh` (253 строки, `#!/usr/bin/env bash`) и иллюстрация `docs/example.svg` ранее разрабатывались в отдельном репозитории `~/dev/claude-code-status-line` (`github.com/al-siv/claude-code-status-line`, HEAD `e93beda440c56836641f11f60814b91107318409`).
- В живом конфиге `~/.claude/settings.json` стояла прямая ссылка на рабочий каталог:
  ```json
  "statusLine": {
    "type": "command",
    "command": "STATUSLINE_SAFE_EFFORT=\"medium high xhigh\" bash /Users/alsiv/dev/claude-code-status-line/statusline.sh"
  }
  ```
  При этом копия `~/.claude/statusline.sh` отсутствовала, а `STATUSLINE_SAFE_EFFORT="medium high xhigh"` задавал пользовательское расширение безопасного набора уровней `effort` (в самом скрипте по умолчанию `high xhigh`).
- Решение:
  1. Импортировать `statusline.sh` в `claude/statusline.sh` (байт-в-байт со снимком `e93beda`) и `docs/example.svg` в `docs/claude-example.svg`.
  2. Оформить backfill-контракт `contracts/claude.md` и журнал `contracts/claude-journal.md` (`EP-1`, снимок текущего состояния без изменения поведения скрипта).
  3. Разворачивать рантайм-копию в `~/.claude/statusline.sh` через `./sync.sh push` и прописывать в `~/.claude/settings.json` команду `STATUSLINE_SAFE_EFFORT="medium high xhigh" bash ~/.claude/statusline.sh`, сохраняя пользовательскую настройку `STATUSLINE_SAFE_EFFORT` и переводя запуск на рантайм-файл `~/.claude/statusline.sh`.
  4. По завершении миграции удалить локальный каталог `~/dev/claude-code-status-line` и заархивировать/удалить отдельный репозиторий `al-siv/claude-code-status-line`.

### 1.3. Codex CLI (`codex`)

- Codex CLI не запускает внешний shell-скрипт для рендера статус-лайна. Его TUI-строка состояния настраивается декларативно в `~/.codex/config.toml` внутри таблицы `[tui]`:
  ```toml
  [tui]
  status_line = ["run-state", "model-with-reasoning", "current-dir", "git-branch", "context-used", "weekly-limit", "fast-mode"]
  screen_reader_detection_done = true
  status_line_use_colors = true
  ```
- Сам файл `~/.codex/config.toml` целиком не версионируется (политика `~/dev/agent-instructions`: в `config.toml` хранятся токены MCP-серверов, такие как `[mcp_servers.fal-ai.env]`, и локальные таблицы доверия `[projects."..."]`).
- Решение:
  1. Выделить декларативный срез настроек статус-лайна в компонент `codex/statusline.toml` (таблица `[tui]` с ключами `status_line` и `status_line_use_colors`).
  2. Оформить backfill-контракт `contracts/codex.md` и журнал `contracts/codex-journal.md` (`EP-1`).
  3. В `sync.sh` проверять (`status`), точечно обновлять (`push`) и принимать по подтверждению (`pull --confirmed codex`) только эти два ключа в секции `[tui]` файла `~/.codex/config.toml`, не затрагивая остальные ключи `[tui]` (`screen_reader_detection_done`), соседние секции и комментарии.

### 1.4. Antigravity CLI (`agy`)

- Более глубокая инспекция рантайма и бинарника `agy` (`/Users/alsiv/.local/bin/agy`, `types.StatusLineData`, `store.BuildStatusLineData`, `model.StatusLineModel.renderModeLabel`, `agy -p /usage --output-format json`) показала, что `agy` поддерживает внешний `statusLine`-скрипт (`~/.gemini/antigravity-cli/statusline.sh`), получающий JSON-структуру `StatusLineData` на stdin (поля `cwd`, `product`, `model.{id,display_name,effort}`, `agent_state`, `cycle_mode`, `vcs.branch`, `quota` с бакетами `gemini-5h`/`gemini-weekly` и `3p-5h`/`3p-weekly`, и др.).
- Файл `~/.gemini/antigravity-cli/settings.json` остаётся закрытым жёсткой системной границей защиты Antigravity, поэтому агентские инструменты не читают и не изменяют привязку в `settings.json`, а синхронизируют только сам исполняемый скрипт `~/.gemini/antigravity-cli/statusline.sh`.
- Решение:
  1. Принять статус-лайн `agy` в единый репозиторий как 4-й компонент `agy/statusline.sh` с контрактом [`contracts/agy.md`](../contracts/agy.md) и журналом [`contracts/agy-journal.md`](../contracts/agy-journal.md) (`EP-1`).
  2. Добавить в скрипт: отображение недельного остатка квоты `7d:XX%` правее `5h:XX%` (ранее отбрасывавшегося при взятии `[0]`), удаление слова `Gemini` и `Pro` перед `Orchestrator`/`Orchistrator` с сокращением до `Orch. X`, цветовую градацию левого сегмента `agent_state` (`idle` — серый, активные состояния — цветные), правый сегмент режима доступа `<mode>` (`cycle_mode`, дефолт `ask`) с цветовой градацией, серую ветку `main` и выделенные прочие ветки, а также убрать сегмент объёма использованного контекста (`NNNk`).

## 2. Адаптация механики харнесса к четырём компонентам

1. **Структура каталогов и `OBJECTS` в `.hooks/pre-push`:**
   ```text
   qoder/statusline-command.sh:qoder
   claude/statusline.sh:claude
   codex/statusline.toml:codex
   agy/statusline.sh:agy
   ```
   Гейты 2, 2b и 2c в `.hooks/pre-push` уже написаны в цикле по `OBJECTS`, поэтому автоматически проверяют наличие артефакта, контракта `contracts/<name>.md`, журнала `contracts/<name>-journal.md`, семи обязательных секций и взаимно-однозначного индекса `IDX-1..IDX-4` в `contracts/AGENTS.md` (плюс проверка отсутствия дублирующихся номеров `IDX-N`).
2. **Гейт 4 (`render`) в `.hooks/pre-push`:**
   - Для shell-скриптов (`*.sh`) проверяемый интерпретатор выбирается по shebang:
     - `#!/bin/sh` / `#!/usr/bin/env sh` (`qoder/statusline-command.sh`) → синтаксический разбор `dash -n` (fallback `sh -n`) и прогон деградации на пустом stdin (`printf ''`) и пустом JSON (`printf '{}'`).
     - `#!/usr/bin/env bash` / `#!/bin/bash` (`claude/statusline.sh`, `agy/statusline.sh`) → синтаксический разбор `bash -n` и прогон деградации на пустом stdin (`printf ''`) и пустом JSON (`printf '{}'`).
   - Для декларативного среза TOML (`codex/statusline.toml`) проверяется, что файл содержит только секцию `[tui]` и ровно два валидных ключа: `status_line` (непустой массив непустых строк) и `status_line_use_colors` (булево `true` или `false`), без синтаксических ошибок и посторонних секций/ключей.
3. **`sync.sh` (`status` / `push` / `pull [--confirmed <object...>]`):**
   - Поддерживает работу как по всем компонентам сразу (`./sync.sh status`, `./sync.sh push`), так и по выбранному подмножеству (`./sync.sh status agy`, `./sync.sh push claude`, `./sync.sh push codex`, `./sync.sh pull --confirmed qoder`).
   - Для `qoder` и `claude` синхронизирует и исполняемый скрипт в рантайме, и объект `.statusLine` в соответствующем `settings.json` (при совпадении `.statusLine` не перезаписывает `settings.json`, при расхождении атомарно обновляет `.statusLine` через `jq` во временный файл в том же каталоге).
   - Для `agy` синхронизирует только исполняемый скрипт `agy/statusline.sh` ↔ `~/.gemini/antigravity-cli/statusline.sh` через общие функции `check_script_component` и `push_script_component` с опциональным `settings_file`, не обращаясь к защищённому `~/.gemini/antigravity-cli/settings.json`.
   - Для `codex` сверяет и при расхождении точечно обновляет ключи `status_line` и `status_line_use_colors` внутри секции `[tui]` файла `~/.codex/config.toml` (сохраняя остальные ключи и секции без изменений).
   - Переменные окружения `QODER_RUNTIME_FILE`, `QODER_SETTINGS_FILE`, `CLAUDE_RUNTIME_FILE`, `CLAUDE_SETTINGS_FILE`, `CODEX_CONFIG_FILE`, `AGY_RUNTIME_FILE` позволяют изолированно тестировать все ветки `sync.sh` и `.hooks/pre-push` во временном каталоге.

## 3. Сверка с родителем после обновления `publish-statusline` (`EP-10`, коммит `b6cc755`)

- В родительском репозитории `~/dev/agent-skills` в коммите `b6cc755` (`feat(publish-statusline): support multi-harness qoder, claude, and codex components`) из числа пинуемых файлов изменился только `contracts/AGENTS.md` (`2b9f690..b6cc755`): строка `IDX-4` (`publish-statusline.md`) обновлена под мульти-компонентную публикацию `qoder`, `claude` и `codex` из `~/dev/agent-statusline`.
- Решение по процедуре адаптации (`AGENTS.md`): изменение касается исключительно индекса скиллов родителя (`IDX-4` для `publish-statusline`) и отражает уже выполненную консолидацию трёх компонентов в этом репозитории; локальные контракты и правила `contracts/AGENTS.md` здесь уже содержат `IDX-1..IDX-3` (`qoder`, `claude`, `codex`) и дополнительных правок не требуют; пин `.harness-pin` обновляется (`./harness-check.sh pin`) на базу `b6cc755`.

## 4. Сверка с родителем по дельте `b6cc755..cd9a0f8` (2026-11-15)

Изменения в `~/dev/agent-skills` от базы пина `b6cc755` до `cd9a0f8` затронули два пинуемых файла (`AGENTS.md` не менялся):

1. **`.hooks/pre-push` (коммит `ce9c981`):**
   - **Перенесено:** в гейте 3 (проверка ссылок markdown) узкий список URI-схем (`http:*|https:*|ftp:*|mailto:*|data:*`) заменён на общий RFC 3986 фильтр `[A-Za-z][A-Za-z0-9+.-]*:*` (в том числе чтобы корректно пропускать `file://` и прочие схемы). Проверка `"$repo_phys"|"$repo_phys"/*` в этом репозитории уже присутствовала.
   - **Отклонено как неприменимое:** валидация реестра `EXTERNAL` и страж `# none` (в `agent-statusline` нет импортируемых внешних скиллов и файла `EXTERNAL`), а также флаг `-m` функции `check_external_commits` (той же области `EXTERNAL`).
2. **`contracts/AGENTS.md` (коммит `ce9c981` и индексные правки до `cd9a0f8`):**
   - **Перенесено:**
     - `RULE-audit-pass` — уточнено, что при наличии машинного чекера он прогоняется по покрытым свойствам наряду с код-ревью непокрытых утверждений;
     - `RULE-gate` — последовательная нумерация без повторного использования/перенумерации, удаление устаревших `GATE-N` только при санкции пользователя с записью причины в журнал, и явное требование `Verify:`;
     - `RULE-invariant-supersession` — эволюционирующие `INV-N` обновляются на месте, а отменяемые по решению пользователя удаляются без повторного использования номера;
     - `RULE-provenance` — запрет на даты вытесненных редакций прямо в теле контракта;
     - `RULE-references-resolve` — приведение списка URI-схем в описании к фильтру `[A-Za-z][A-Za-z0-9+.-]*:` из гейта 3;
     - `Naming conventions` (`Item IDs` и `Q&A entries`) — правила вывода из обращения `QA-N`/`RISK-N`/`INV-N`/`GATE-N` без перенумерации и отказ от избыточного `Status: resolved` на актуальных позициях (убирается при следующей правке записи; существующие нетронутые контракты правки не требуют).
   - **Отклонено как неприменимое:** правки индексных строк `IDX-*` родителя (`IDX-22`, `IDX-23`, `IDX-25`, `IDX-26`), `RULE-description-fits-listing` (специфика листинга скиллов, `BACKLOG`/`EXTERNAL`/`SKILL.md`), ссылка на `release-skills GATE-6` и политику скиллов `skills/rules/`.
3. **Пин:** после адаптации локальных правил выполняется `./harness-check.sh pin` на базу `cd9a0f8`.

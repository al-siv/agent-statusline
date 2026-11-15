# Расширение agent-statusline на все рабочие CLI-харнессы макбука (2026-11-15)

## Контекст и задача

После переименования репозитория в `~/dev/agent-statusline` (`github.com/al-siv/agent-statusline`) поставлена задача собрать в него статус-лайны всех рабочих CLI-харнессов на макбуке — Qoder CLI (`qoderclicn`), Claude Code (`claude`), Codex CLI (`codex`) и Antigravity CLI (`agy`), — чтобы при обновлении, переустановке или сбросе настроек любого из харнессов статус-лайн и его привязка в конфиге восстанавливались одной командой (`./sync.sh push`).

## 1. Инвентаризация CLI-харнессов макбука

| Харнесс | Способ задания статус-лайна | Артефакт в `agent-statusline` | Рантайм-скрипт | Привязка в рантайм-конфиге |
| --- | --- | --- | --- | --- |
| **Qoder CLI** (`qoderclicn`) | Внешний скрипт (`statusLine.type = "command"`, JSON сессии в stdin) | `qoder/statusline-command.sh` (`#!/bin/sh`) | `~/.qoder-cn/statusline-command.sh` (симлинк `~/.qoder`) | `~/.qoder-cn/settings.json` → `.statusLine = {"type": "command", "command": "~/.qoder-cn/statusline-command.sh"}` |
| **Claude Code** (`claude`) | Внешний скрипт (`statusLine.type = "command"`, JSON сессии в stdin) | `claude/statusline.sh` (`#!/usr/bin/env bash`) + `docs/claude-example.svg` | `~/.claude/statusline.sh` | `~/.claude/settings.json` → `.statusLine = {"type": "command", "command": "STATUSLINE_SAFE_EFFORT=\"medium high xhigh\" bash ~/.claude/statusline.sh"}` |
| **Codex CLI** (`codex`) | Декларативный список встроенных TUI-виджетов в `[tui]` файла `config.toml` | `codex/statusline.toml` | — (внешний скрипт не поддерживается) | `~/.codex/config.toml` → секция `[tui]`: ключи `status_line` и `status_line_use_colors` |
| **Antigravity CLI** (`agy`) | Встроенный статус-бар TUI; пользовательского хука `statusLine` или конфигурируемого набора сегментов нет | — (фиксируется в документации репо) | — | `~/.gemini/antigravity-cli/settings.json` (закрыт системной границей защиты Antigravity и не содержит настроек статус-лайна) |

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

- Проверка документации Antigravity CLI (`~/.gemini/antigravity-cli/builtin/skills/antigravity_guide/` и `agy-customizations/`) показала, что статус-бар в TUI Antigravity встроенный и не предоставляет ни пользовательского хука `statusLine` (вызова внешней команды), ни настраиваемого списка сегментов.
- Кроме того, файл `~/.gemini/antigravity-cli/settings.json` закрыт жёстким правилом системной защиты Antigravity (`Matches hardcoded system protection boundary rule`), поэтому агентские инструменты не читают и не модифицируют его.
- В `README.md` и `AGENTS.md` явно фиксируется статус всех четырёх CLI-харнессов макбука: три управляемых компонента (`qoder`, `claude`, `codex`) и причина отсутствия компонента синхронизации у `agy`.

## 2. Адаптация механики харнесса к трём компонентам

1. **Структура каталогов и `OBJECTS` в `.hooks/pre-push`:**
   ```text
   qoder/statusline-command.sh:qoder
   claude/statusline.sh:claude
   codex/statusline.toml:codex
   ```
   Гейты 2, 2b и 2c в `.hooks/pre-push` уже написаны в цикле по `OBJECTS`, поэтому автоматически проверяют наличие артефакта, контракта `contracts/<name>.md`, журнала `contracts/<name>-journal.md`, семи обязательных секций и взаимно-однозначного индекса `IDX-1..IDX-3` в `contracts/AGENTS.md` (плюс добавляется проверка отсутствия дублирующихся номеров `IDX-N`).
2. **Гейт 4 (`render`) в `.hooks/pre-push`:**
   - Для shell-скриптов (`*.sh`) проверяемый интерпретатор выбирается по shebang:
     - `#!/bin/sh` / `#!/usr/bin/env sh` (`qoder/statusline-command.sh`) → синтаксический разбор `dash -n` (fallback `sh -n`) и прогон деградации на пустом stdin (`printf ''`) и пустом JSON (`printf '{}'`).
     - `#!/usr/bin/env bash` / `#!/bin/bash` (`claude/statusline.sh`) → синтаксический разбор `bash -n` и прогон деградации на пустом stdin (`printf ''`) и пустом JSON (`printf '{}'`).
   - Для декларативного среза TOML (`codex/statusline.toml`) проверяется, что файл содержит только секцию `[tui]` и ровно два валидных ключа: `status_line` (непустой массив непустых строк) и `status_line_use_colors` (булево `true` или `false`), без синтаксических ошибок и посторонних секций/ключей.
3. **`sync.sh` (`status` / `push` / `pull [--confirmed <object...>]`):**
   - Поддерживает работу как по всем компонентам сразу (`./sync.sh status`, `./sync.sh push`), так и по выбранному подмножеству (`./sync.sh status claude`, `./sync.sh push codex`, `./sync.sh pull --confirmed qoder`).
   - Для `qoder` и `claude` синхронизирует и исполняемый скрипт в рантайме, и объект `.statusLine` в соответствующем `settings.json` (при совпадении `.statusLine` не перезаписывает `settings.json`, при расхождении атомарно обновляет `.statusLine` через `jq` во временный файл в том же каталоге).
   - Для `codex` сверяет и при расхождении точечно обновляет ключи `status_line` и `status_line_use_colors` внутри секции `[tui]` файла `~/.codex/config.toml` (сохраняя остальные ключи и секции без изменений).
   - Переменные окружения `QODER_RUNTIME_FILE`, `QODER_SETTINGS_FILE`, `CLAUDE_RUNTIME_FILE`, `CLAUDE_SETTINGS_FILE`, `CODEX_CONFIG_FILE` позволяют изолированно тестировать все ветки `sync.sh` и `.hooks/pre-push` во временном каталоге.

## 3. Сверка с родителем после обновления `publish-statusline` (`EP-10`, коммит `b6cc755`)

- В родительском репозитории `~/dev/agent-skills` в коммите `b6cc755` (`feat(publish-statusline): support multi-harness qoder, claude, and codex components`) из числа пинуемых файлов изменился только `contracts/AGENTS.md` (`2b9f690..b6cc755`): строка `IDX-4` (`publish-statusline.md`) обновлена под мульти-компонентную публикацию `qoder`, `claude` и `codex` из `~/dev/agent-statusline`.
- Решение по процедуре адаптации (`AGENTS.md`): изменение касается исключительно индекса скиллов родителя (`IDX-4` для `publish-statusline`) и отражает уже выполненную консолидацию трёх компонентов в этом репозитории; локальные контракты и правила `contracts/AGENTS.md` здесь уже содержат `IDX-1..IDX-3` (`qoder`, `claude`, `codex`) и дополнительных правок не требуют; пин `.harness-pin` обновляется (`./harness-check.sh pin`) на базу `b6cc755`.

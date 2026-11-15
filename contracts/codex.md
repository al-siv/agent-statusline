---
id: codex
title: codex — контракт компонента: конфигурация статус-лайна Codex CLI
kind: contract
status: active
created: 2026-11-15
updated: 2026-11-15
owners: [alsiv]
refs:
  - codex-journal.md
  - ../analysis/2026-11-15-multi-harness-statusline-research.md
---

# codex — контракт компонента

## Map {#map}

- [Purpose](#purpose) — роль контракта и специфика объекта
- [Invariants](#invariants) — INV-1..INV-5: постоянные свойства компонента
- [Specification](#specification) — гомогенизированная текущая спецификация компонента
- [Acceptance gates](#gates) — GATE-1..GATE-3: критерии приёмки
- [Risks](#risks) — RISK-1..RISK-3 с митигациями
- [Q&A](#qa) — QA-1: почему версионируется срез [tui], а не весь config.toml (resolved)
- Журнал (provenance, нормативной силы не имеет): [codex-journal.md](codex-journal.md)

## Purpose {#purpose}

`codex` — декларативная спецификация статус-лайна Codex CLI: файл `codex/statusline.toml`, задающий состав, порядок и цветовую индикацию встроенных виджетов строки состояния TUI в секции `[tui]` конфигурационного файла `~/.codex/config.toml`.

**Решаемая проблема.** Codex CLI не вызывает внешний shell-скрипт для рендера статус-лайна, а формирует строку состояния из встроенных TUI-сегментов по ключам `status_line` и `status_line_use_colors` в таблице `[tui]` файла `~/.codex/config.toml`. При этом сам файл `~/.codex/config.toml` целиком не может храниться в публичном git-репозитории, так как содержит учётные данные MCP-серверов и локальные таблицы доверия проектов. Выделение среза `codex/statusline.toml` под управление `sync.sh` защищает конфигурацию статус-лайна от потери при обновлении или переустановке Codex CLI без утечки секретов из `config.toml`.

**Стороны.**

- Пользователь/оператор: видит статус-лайн в TUI Codex CLI; правит состав сегментов через контрактный цикл.
- Харнесс Codex CLI: читает секцию `[tui]` из `~/.codex/config.toml` и рендерит выбранные виджеты.
- Репозиторий `~/dev/agent-statusline`: источник правды для среза статус-лайна; его `AGENTS.md` задаёт политику (repo-first, contract-first, запрет blanket pull, conventional commits).
- Рантайм-конфиг `~/.codex/config.toml` (ключи `status_line` и `status_line_use_colors` в секции `[tui]`): синхронизируется точечно через `sync.sh` (`status` / `push` / `pull [--confirmed codex]`).
- Удалённый репозиторий (`origin`, github.com/al-siv/agent-statusline): точка публикации.

Контракт — источник истины о компоненте: гомогенизированная текущая спецификация, единственный нормативный источник. **Принцип восстановимости:** секция Specification несёт полный нормативный состав `codex/statusline.toml`, так что артефакт восстановим из контракта дословно. Эпизоды изменений и их замыслы — в журнале [codex-journal.md](codex-journal.md).

## Invariants {#invariants}

INV-1: Компонент — один декларативный TOML-файл `codex/statusline.toml`, содержащий исключительно секцию `[tui]` и два ключа настройки статус-лайна: `status_line` (упорядоченный массив непустых строковых идентификаторов виджетов) и `status_line_use_colors` (булево значение `true` или `false`). Никакие другие секции и ключи `~/.codex/config.toml` (включая `screen_reader_detection_done`, `[mcp_servers.*]`, `[projects.*]`, `[features]`, `[notice]`) в артефакт не входят.

INV-2: Репозиторий — единственный источник правды для ключей `status_line` и `status_line_use_colors` секции `[tui]`; рантайм `~/.codex/config.toml` получает их через `./sync.sh push`, а изменения этих ключей, сделанные интерактивно в TUI Codex CLI, принимаются в репозиторий только через `./sync.sh pull --confirmed codex`.

INV-3: Изоляция секретов и смежных настроек: синхронизация компонента никогда не читает в git и не затирает при `push` остальные ключи секции `[tui]` и другие таблицы `~/.codex/config.toml`.

INV-4: Pre-push hook не обходится: нарушение структуры `codex/statusline.toml` или дрифт со срезом `[tui]` в `~/.codex/config.toml` блокирует пуш до устранения причины.

INV-5: Восстановимость: контракт исчерпывающе фиксирует секцию, ключи, точный порядок элементов массива `status_line` и значение `status_line_use_colors`, позволяя восстановить `codex/statusline.toml` без обращения к старой копии файла.

## Specification {#specification}

Состав ниже — полный нормативный состав компонента; реконструкция `codex/statusline.toml` выполняется по этому тексту.

**Структура и содержимое файла `codex/statusline.toml`.**

- Файл начинается с однострочного англоязычного комментария назначения:
  `# Codex CLI TUI status line slice (synced into ~/.codex/config.toml under [tui]).`
- Далее следует таблица `[tui]` ровно с двумя ключами:
  1. `status_line` — упорядоченный массив из семи встроенных виджетов Codex CLI (слева направо):
     - `"run-state"` — текущее состояние выполнения агента;
     - `"model-with-reasoning"` — активная модель вместе с уровнем рассуждений (reasoning effort);
     - `"current-dir"` — текущая рабочая директория;
     - `"git-branch"` — текущая ветка git;
     - `"context-used"` — доля использованного контекстного окна;
     - `"weekly-limit"` — состояние недельного лимита квоты;
     - `"fast-mode"` — индикатор режима fast-mode.
     Точная запись строки:
     `status_line = ["run-state", "model-with-reasoning", "current-dir", "git-branch", "context-used", "weekly-limit", "fast-mode"]`
  2. `status_line_use_colors` — включение цветовой индикации сегментов статус-лайна:
     `status_line_use_colors = true`

Out of scope (сознательно не в компоненте):

- Остальные ключи таблицы `[tui]` (`screen_reader_detection_done`, подтаблица `[tui.model_availability_nux]`) и остальные секции `~/.codex/config.toml`.
- Repo-механика парсинга и точечной записи в `~/.codex/config.toml` (`sync.sh`, `.hooks/pre-push`): принадлежит уровню репозитория (`AGENTS.md`, `README.md`).

## Acceptance gates {#gates}

GATE-1 — полнота спецификации: таблица `[tui]`, оба ключа (`status_line`, `status_line_use_colors`), состав и порядок всех семи виджетов и заголовочный комментарий полностью описаны в Specification; `codex/statusline.toml` восстановим из контракта дословно. Verify: построчная сверка `codex/statusline.toml` против контракта.

GATE-2 — валидность среза и синхронизация с рантаймом: `./sync.sh status` подтверждает совпадение `codex/statusline.toml` со срезом `[tui]` в `~/.codex/config.toml`, а гейт 4 в `.hooks/pre-push` подтверждает синтаксическую и структурную валидность `codex/statusline.toml` (только секция `[tui]`, массив непустых строк `status_line` и булев `status_line_use_colors`). Verify: вывод `./sync.sh status` и `.hooks/pre-push`.

GATE-3 — независимый аудит по `RULE-audit-pass` (`audit-prompts` + `audit-causal-structure` и проверка механики разбора TOML-среза). Verify: запись в журнале `contracts/codex-journal.md`.

## Risks {#risks}

RISK-1 — Дрейф при интерактивном изменении статус-лайна из TUI Codex CLI или при обновлении CLI: Codex CLI может перезаписать `status_line` или `status_line_use_colors` в `~/.codex/config.toml`. Mitigation: `./sync.sh status` выявляет расхождение среза `[tui]`, `./sync.sh push` восстанавливает эталон из репозитория, а намеренное изменение из TUI принимается через `./sync.sh pull --confirmed codex` и оформляется эпизодом контракта.

RISK-2 — Повреждение смежных ключей или секретов в `~/.codex/config.toml` при синхронизации: полная перезапись файла уничтожила бы MCP-конфигурацию и доверенные проекты. Mitigation: `sync.sh` работает только со срезом двух ключей внутри секции `[tui]`, сохраняя все остальные строки, комментарии и секции `~/.codex/config.toml` без изменений (INV-3).

RISK-3 — Изменение набора поддерживаемых идентификаторов виджетов в будущих версиях Codex CLI. Mitigation: список виджетов зафиксирован в `Specification`; при переименовании или добавлении виджетов в Codex CLI изменение вносится через штатный контрактный эпизод.

## Q&A {#qa}

QA-1 — Почему для Codex CLI версионируется отдельный файл-срез `codex/statusline.toml`, а не весь `~/.codex/config.toml` и не внешний скрипт. Status: resolved (2026-11-15). Decision: Codex CLI не поддерживает вызов внешнего скрипта для рендера статус-лайна и хранит настройку в `[tui]` внутри `~/.codex/config.toml`, а сам `~/.codex/config.toml` содержит секреты MCP-серверов (`[mcp_servers.fal-ai.env]`) и локальные пути проектов (`[projects."..."]`) и по политике `~/dev/agent-instructions` не коммитится целиком (см. [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)). Срез `codex/statusline.toml` решает задачу сохранения и восстановления статус-лайна без нарушения границы секретов.

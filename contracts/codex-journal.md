---
id: codex-journal
title: codex — Contract Journal
kind: journal
contract: codex.md
created: 2026-11-15
updated: 2026-11-15
---

# codex — Journal

## Episodes {#episodes}

### EP-1 (status: implemented) — базовая спецификация компонента Codex CLI (baseline backfill)
touched: INV-1..INV-5, Specification, GATE-1..GATE-3, RISK-1..RISK-3, QA-1

Полный снимок декларативной конфигурации статус-лайна Codex CLI (`codex/statusline.toml`) по текущему рабочему состоянию секции `[tui]` в `~/.codex/config.toml` на 2026-11-15 (research: [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)): семь виджетов `status_line = ["run-state", "model-with-reasoning", "current-dir", "git-branch", "context-used", "weekly-limit", "fast-mode"]` и `status_line_use_colors = true`. Точечная синхронизация этих двух ключей с `~/.codex/config.toml` без затрагивания секретов и соседних секций подключена в `./sync.sh`.

GATE-1: pass (2026-11-15) — построчная сверка `codex/statusline.toml` против `Specification` в `contracts/codex.md`: заголовочный комментарий, секция `[tui]`, массив `status_line` из 7 элементов и `status_line_use_colors = true` совпадают дословно (`(a) = 0`, `(b) = 0`, `(c) = 0`).

GATE-2: pass (2026-11-15) — после `./sync.sh push` команда `./sync.sh status` подтверждает совпадение `codex/statusline.toml` с секцией `[tui]` в `~/.codex/config.toml` (`in sync: qoder claude codex`), а `.hooks/pre-push` (включая структурную валидацию TOML-среза в гейте 4) завершается с кодом 0.

GATE-3: pass (2026-11-15) — независимый аудит backfill-снимка по `RULE-audit-pass` (`audit-prompts` + `audit-causal-structure`, агент `aeae0ef6`, и аудит механики синхронизации TOML-среза, агент `1d4ad14f`): двунаправленная сверка чистая; в `refs` унифицирован относительный путь журнала (F-6, Low — fixed); в парсере и апдейтере `[tui]` в `sync.sh` и `.hooks/pre-push` устранены проглатывание `exit 2` при вызове в тестовом контексте `||` (Defect 1, High — fixed), перезапись кода ошибки в `awk END` (Defect 2, High — fixed) и обработка многострочных массивов соседних ключей, заголовков `[[...]]`, хвостовых запятых и дубликатов `[tui]` (Defect 3, Medium — fixed).

## Chronicle {#chronicle}

CHANGE-2026-11-15-a — EP-1 (implemented): выделение декларативного среза статус-лайна Codex CLI в `codex/statusline.toml`, создание backfill-контракта `contracts/codex.md` и журнала `contracts/codex-journal.md`, добавление `IDX-3` в `contracts/AGENTS.md` и подключение точечной синхронизации секции `[tui]` файла `~/.codex/config.toml` в `./sync.sh` (research: [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)). Все находки независимого аудита (`aeae0ef6` и `1d4ad14f`) устранены и верифицированы.

---
id: claude-journal
title: claude — Contract Journal
kind: journal
contract: claude.md
created: 2026-11-15
updated: 2026-11-15
---

# claude — Journal

## Episodes {#episodes}

### EP-1 (status: implemented) — базовая спецификация компонента Claude Code (baseline backfill)
touched: INV-1..INV-6, Specification, GATE-1..GATE-3, RISK-1..RISK-5, QA-1, QA-2

Полный снимок спецификации компонента `claude` (`claude/statusline.sh` и иллюстрация `docs/claude-example.svg`) при переносе из репозитория `~/dev/claude-code-status-line` (коммит `e93beda440c56836641f11f60814b91107318409`, 2026-11-15) в единый репозиторий `~/dev/agent-statusline` (research: [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)). По правилу backfill (`RULE-contract-first`, `RULE-audit-pass`) скрипт перенесён байт-в-байт без скрытых правок; особенности baseline-реализации (поведение на пустом stdin вне git-репозитория и предположения о типах/локали в `rl_seg`) зафиксированы в `RISK-4` и `RISK-5`. Рантайм-копия развёрнута в `~/.claude/statusline.sh`, а привязка `.statusLine` в `~/.claude/settings.json` переведена на `STATUSLINE_SAFE_EFFORT="medium high xhigh" bash ~/.claude/statusline.sh` под управление `./sync.sh`.

GATE-1: pass (2026-11-15) — построчная сверка `claude/statusline.sh` (253 строки) против `Specification` в `contracts/claude.md`: все переменные окружения, 11 переменных палитры и `NO_COLOR`, 11 полей JSON, git-сегменты (`branch`, `∆:C+N`, `δ:+A/-D`), цвета семейств моделей, форматирование и флаг `•eff`, функции `acw_settings` и `ctx_window`, светофоры `NNNk` и `5h`/`7d` покрыты полностью (`(a) = 0`, `(b) = 0`, `(c) = 0`).

GATE-2: pass (2026-11-15) — после выполнения `./sync.sh push` рантайм-копия `~/.claude/statusline.sh` и привязка `.statusLine` в `~/.claude/settings.json` развёрнуты, `./sync.sh status` чист (`in sync: qoder claude codex`), `bash -n claude/statusline.sh` и `.hooks/pre-push` завершаются с кодом 0.

GATE-3: pass (2026-11-15) — независимый аудит backfill-снимка по `RULE-audit-pass` (`audit-prompts` + `audit-causal-structure`, агент `aeae0ef6`, и независимый аудит кода/механики, агент `1d4ad14f`): двунаправленная сверка `Specification` против `claude/statusline.sh` подтвердила 100% покрытие без расхождений. Текстовые находки по контракту и журналу устранены: порядок фиксации `GATE-2` после реального `./sync.sh push` (F-2, High — fixed), снятие inline-маркеров коммита/эпизода в `RISK-4`/`RISK-5`/`QA-1` по `RULE-provenance` (F-5, Medium — fixed), унификация относительного пути журнала в `refs` (F-6, Low — fixed), добавление `cat` в список стандартных утилит `INV-1` и уточнение зависимости пустого stdin от git-дерева с коммитами в `INV-4`/`RISK-4` (Defects 6 и 7.1, Low — fixed).

## Chronicle {#chronicle}

CHANGE-2026-11-15-a — EP-1 (implemented): импорт `claude/statusline.sh` и `docs/claude-example.svg` из `~/dev/claude-code-status-line` (`e93beda`) в `~/dev/agent-statusline`, создание backfill-контракта `contracts/claude.md` и журнала `contracts/claude-journal.md`, добавление `IDX-2` в `contracts/AGENTS.md`, подключение `~/.claude/statusline.sh` и `.statusLine` в `~/.claude/settings.json` через `./sync.sh` (research: [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)). Все находки независимого аудита (`aeae0ef6` и `1d4ad14f`) устранены и верифицированы.

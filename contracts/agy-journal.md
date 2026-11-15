---
id: agy-journal
title: agy — Contract Journal
kind: journal
contract: agy.md
created: 2026-11-15
updated: 2026-11-15
---

# agy — Journal

## Episodes {#episodes}

### EP-1 (status: implemented) — постановка статус-лайна Antigravity CLI под управление контракта и доработка сегментов
touched: INV-1..INV-7, Specification, GATE-1..GATE-3, RISK-1..RISK-4, QA-1..QA-3

Принятие существующего рантайм-скрипта `~/.gemini/antigravity-cli/statusline.sh` в репозиторий `~/dev/agent-statusline` как компонента `agy` (`agy/statusline.sh`) с интеграцией в `sync.sh` (скрипт-онли, без доступа к `~/.gemini/antigravity-cli/settings.json`), `.hooks/pre-push` (`OBJECTS`) и `contracts/AGENTS.md` (`IDX-4`). Состав доработок по сравнению с исходным рантайм-вариантом: добавление остатка недельной квоты `7d:XX%` (бакеты `gemini-weekly` / `3p-weekly` из `StatusLineData.quota`) правее `5h:XX%`; удаление слова `Gemini` и `Pro` перед `Orchestrator`/`Orchistrator` с сокращением до `Orch. X`; цветовая градация левого сегмента `agent_state` (`idle` — серый, активные состояния — цветные); добавление правого сегмента режима доступа `<mode>` (`cycle_mode`, дефолт `ask` для Antigravity) с цветовой градацией; серый цвет ветки `main` и выделенный жирный ярко-голубой для не-`main` веток; удаление вывода использованного контекста (`NNNk` и `.context_window`); fallback `cwd="."` на полностью пустом stdin (`""`) для соблюдения `INV-4`.

- **Audit (RULE-audit-pass):** независимый аудит (`fcdfc41a-7a58-4d84-a7d7-58be010fe946`) на первичном проходе выявил 6 объективных находок (3 Medium, 3 Low). Все 6 находок устранены правками контракта `agy.md`, скрипта `agy/statusline.sh` (добавлен fallback `cwd="."`, поузловые `?` в путях `jq` с `2>/dev/null` и проверкой числового типа `.used_percentage`, переписан `rl_seg` на `LC_ALL=C awk` с валидацией чисел и защитой от `-0`, уточнены комментарии про `ask`/`strict` и `yolo`) и формулировок `README.md`; повторная точечная верификация подтвердила закрытие всех 6 находок (0 остаточных дефектов в контракте, `agy/statusline.sh`, `sync.sh`, `.hooks/pre-push` и Markdown-ссылках/якорях).
- **GATE-1:** pass (`bash -n` и `shellcheck -s bash` на `agy/statusline.sh`, `sync.sh`, `.hooks/pre-push` — exit 0; прогон payload-тестов: `Gemini 4 Argon`, `Orchestrator (Carbon)`, `Orchestrator (Argon)`, `NO_COLOR=1`, `LC_ALL=fr_FR.UTF-8`, скалярные родительские узлы, нечисловые `.rate_limits`, `"not json"`, скалярный корень `123`, вне-репо `""` и `"{}"` — все exit 0, пустой stderr).
- **GATE-2:** pass (`./sync.sh push` и `./sync.sh status` -> `in sync: qoder claude codex agy`, exit 0; изолированный синтетический тест подтвердил отказ `sync.sh pull` (exit 1) и успешный `sync.sh pull --confirmed agy` (exit 0)).
- **GATE-3:** pass (`./harness-check.sh check` — exit 0 после обновления `.harness-pin` на `cd9a0f8`; `.hooks/pre-push </dev/null` — exit 0; изолированный прогон 13 синтетических нарушений по гейтам 1, 2, 2b, 2c, 3, 4, 5 — 13/13 pass).

## Chronicle {#chronicle}

- CHANGE-2026-11-15-a — EP-1 (implemented): компонент `agy` (`agy/statusline.sh`) взят под управление контракта `contracts/agy.md` и интегрирован в `sync.sh` (скрипт-онли, без доступа к `~/.gemini/antigravity-cli/settings.json`), `.hooks/pre-push` (`OBJECTS`) и `contracts/AGENTS.md` (`IDX-4`); доработаны сегменты статус-лайна, адаптирована дельта родительского харнесса `b6cc755..cd9a0f8` и обновлён `.harness-pin`.

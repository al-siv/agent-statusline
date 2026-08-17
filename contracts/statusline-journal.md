---
id: statusline-journal
title: statusline — Contract Journal
kind: journal
contract: statusline.md
created: 2026-08-17
updated: 2026-08-17
---

# statusline — Journal

## Episodes {#episodes}

### EP-1 (status: implemented) — базовая спецификация компонента (baseline backfill)
touched: INV-1..INV-6, Specification, GATE-1..GATE-3, RISK-1..RISK-3, QA-1

Полный снимок спецификации на момент установки контрактной системы. Зафиксировано по состоянию `statusline-command.sh` на коммит `f29f893` (2026-08-14); скрипт не менялся, контракт создан до первой правки (contract-first, backfill по правилу «контракт до правки»). В исходной дельта-модели снимок был записан как SCOPE-v1; при миграции на snapshot+ledger (CHANGE-2026-08-17-a) он свёрнут в Specification без изменения поведения.

GATE-1: pass — построчная сверка скрипта против снимка при создании контракта (2026-08-14), каждая семантическая точка покрыта.

GATE-2: pass — харнесс активирован: `./sync.sh status` чист, `.hooks/pre-push` завершается 0, `core.hooksPath` указывает на `.hooks` (CHANGE-2026-08-14-a).

GATE-3: pass — аудит полноты baseline: построчная сверка скрипта против контракта (своя + независимая, агент без контекста сессии). High-находок нет; три Medium (точное имя кэш-файла, предусловие читаемости транскрипта для всего AG-блока, нечисловой офсет как основание инвалидации) и Low-детали защитной/байт-точной обвязки внесены в Specification без изменения поведения (CHANGE-2026-08-14-b).

## Chronicle {#chronicle}

CHANGE-2026-08-14-a — Установка харнесса (адаптация `~/dev/qoder-skills`, research: [../analysis/2026-08-14-harness-adaptation-research.md](../analysis/2026-08-14-harness-adaptation-research.md)): backfill-контракт создан по правилу «контракт до правки» — SCOPE-v1 фиксирует текущее состояние `statusline-command.sh` (коммит `f29f893`); созданы `sync.sh`, `.hooks/pre-push` (гейты drift / contract-per-object / IDX-status-sync), `contracts/AGENTS.md`, корневой `AGENTS.md`; GATE-1 и GATE-2 pass. Решение пользователя: repo-first. Зафиксирован конфликт со скиллом publish-statusline (QA-1).

CHANGE-2026-08-14-b — Доработка по замечаниям пользователя (GATE-3, pass): (1) связка с харнессом родителя переведена из декларативной («принципы родителя») в процедурную — пин хэшей `.harness-pin` + `./harness-check.sh {check|pin|show}` + процедура адаптации в `AGENTS.md`; (2) объект контракта переименован скилл/продукт → компонент (RULE-one-contract-per-component и др. в `contracts/AGENTS.md`); (3) независимый аудит SCOPE-v1: High-находок нет, три Medium и Low-детали внесены в SCOPE-v1 без изменения поведения скрипта (уточнение, не новый скоуп — RULE-reconstructability).

CHANGE-2026-08-17-a — Миграция на модель snapshot + ledger и адаптация глубокой доработки харнесса родителя (research: [../analysis/2026-08-17-harness-adaptation-research.md](../analysis/2026-08-17-harness-adaptation-research.md)): SCOPE-v1 свёрнут в Specification (гомогенизированное настоящее), History перенесена в эту хронику дословно, GATE-статусы перенесены в EP-1; поведение скрипта не менялось, `statusline-command.sh` не тронут. В `contracts/AGENTS.md` и корневом `AGENTS.md` — цикл эпизодов с RULE-homogenization и RULE-audit-pass; pre-push гейт 3 (IDX-status-sync) снят (скоупов нет), гейт 2 проверяет контракт + журнал + IDX. Независимая двунаправленная сверка гомогенизации и audit-pass — отдельным агентом: результаты — CHANGE-2026-08-17-b.

CHANGE-2026-08-17-b — Независимый аудит миграции (отдельный агент без контекста сессии, методология audit-prompts). Сверка гомогенизации чистая; один residual класса (b) editorial — перечень трёх Medium-находок GATE-3, внесён в EP-1. Audit-pass: High/Medium-дефектов нет; четыре Low/Trivial, все fixed в той же адаптации: (1) перечень Medium-находок GATE-3 не был перенесён в журнал — fixed (EP-1); (2) амбигвити порядка шагов цикла в `contracts/AGENTS.md` (коммит читался до аудита рендера) — fixed (шаг 6, примечание «one episode = one commit»: коммит — после статуса implemented); (3) смешение нового компонента с backfill в корневом `AGENTS.md` — fixed (переформулировано); (4) неточное обоснование сохранения RULE-contract-first — fixed. Ре-аудит по cap: фиксы подтверждены, новых дефектов нет; проход закрыт с нулём объективных дефектов. Поведение скрипта не менялось.

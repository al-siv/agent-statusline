---
id: agy-journal
title: agy — Contract Journal
kind: journal
contract: agy.md
created: 2026-11-15
updated: 2026-11-22
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

### EP-2 (status: implemented) — объединение git-счётчиков в ∆:C+N/<bal> и добавление времени до сброса 7d в 7d:Y%/X.X{d|h|m}
touched: Map, Purpose, Invariants (INV-3, INV-4, INV-7), Specification, Acceptance gates (GATE-1), Risks (RISK-2), Q&A (QA-4)

Уплотнить правую и git-части статус-лайна Antigravity CLI, объединив связанные счётчики через единый разделитель `/`:

1. **Единый git-сегмент `∆:C+N/<bal>` (вместо раздельных `∆:C+N  δ:+A/-D`):**
   - Сохранить цветные счётчики файлов (`C` изменённых отслеживаемых жёлтым при `> 0`, `N` новых неотслеживаемых зелёным при `> 0`).
   - Вместо отдельных `+A/-D` рассчитывать чистый баланс изменённых строк по `diffstat` (`la` добавлено, `lr` удалено, суммирование через `LC_ALL=C awk ... END{printf "%.0f", ...}` с фильтрацией бинарных строк `^[0-9]+$`):
     - если `la == 0 && lr == 0` (нет изменённых текстовых строк — чистое дерево, только untracked или только бинарные правки) → нейтральный `-`;
     - если есть правки, но `la == lr` (`bal == 0`) → нейтральный `0`;
     - если `bal > 0` → `+B` зелёным (`GREEN`);
     - если `bal < 0` → `-B` красным (`RED`, сохраняя семантику `INV-3` для потерь строк в `agy`).
   - Объединённый формат: `∆:C+N/<bal>` (разделитель `/`).

2. **Объединённый сегмент 7-дневной квоты `7d:Y%/X.X{d|h|m}`:**
   - В едином `jq`-парсере квот (`quota_parsed`) дополнительно извлекать третью строку `week_reset` — остаток секунд до сброса 7-дневного окна:
     - при наличии числового конечного положительного `.rate_limits?.seven_day?.resets_at?` (`type == "number" and isfinite and (isnan | not) and . > 0`) вычислять `max(resets_at - now, 0)`;
     - иначе по отобранному массиву бакетов активного семейства (`$picked`, где `bucket_win(.key; .value) == "7d"`) брать первый непустой результат `reset_sec($b)`: `reset_in_seconds?` (`type == "number" and isfinite and (isnan | not)`, зажато в `>= 0`), иначе `reset_time?` (удаление дробных секунд `sub("\\.[0-9]+"; "")`, нормализация `+00:00` → `Z`, разбор `try fromdateiso8601 catch null` → `max(ts - now, 0)`);
     - дополнительно защитить `bucket_win($k; $b)`, `$all`, `$five`, `$week` и `rl_seg` от нечисловых/неконечных (`NaN`/`Infinity`) и чрезмерных значений для строгого соблюдения `INV-4`;
     - считывать три строки (`five`, `week`, `week_reset`) через `IFS= read -r` (все обнулены в `""`).
   - Вспомогательная функция `fmt_reset` (`local val; val=$(LC_ALL=C awk ...) || return 0` с разделением объявления и присваивания для Bash 3.2):
     - при пустом или нечисловом входе завершается без вывода;
     - отрицательные значения зажимает в `0` (`0.0m`, без `-0.0m`), десятичная точка фиксирована через `LC_ALL=C`;
     - выбирает единицу с повышением разряда при граничном округлении: `>= 86400` → `%.1fd`; `3600 .. < 86400` → при `sprintf("%.1f", r/3600)+0 >= 24` повышается до `%.1fd`, иначе `%.1fh`; `< 3600` → при `sprintf("%.1f", r/60)+0 >= 60` повышается до `%.1fh`, иначе `%.1fm`.
   - Объединение с `7d`:
     - если есть и процент `7d:Y%`, и время сброса `rt` → `${seg}/${rt}` (цвет светофора закрывается до `/`, чтобы `/${rt}` оставался нейтральным по `INV-3`);
     - если процента `7d` нет, а время сброса `rt` есть → `7d:-/${rt}` (нейтральный);
     - если времени сброса нет/некорректно → обычный `7d:Y%` (или пропуск при отсутствии обоих).
   - Правым крайним сегментом строки остаётся режим доступа `<mode>`.

3. **Документация и индекс:** обновить секцию 4 `README.md` (`Antigravity CLI (agy)`) и строку `IDX-4` в `contracts/AGENTS.md`.
- **Audit Stage A (`RULE-homogenization` + `RULE-audit-pass`, `3f1a408f-f6d1-41d9-bc28-8fc353880b1e`):** независимый аудит черновика `contracts/agy.md` выявил 5 объективных находок `(c)` (2 Medium, 3 Low): (1, Medium) отбор `$all` отбрасывал бакеты без валидного `remaining_fraction`, из-за чего терялся `7d:-/X.X{d|h|m}` для `.quota` и протекало чужое семейство, а `used_pct($b)` не проверял `isfinite` после `100 - (. * 100)`; (2, Medium) `fmt_reset` не ограничивал переполнение (`1e308` / `1e999` → 306 символов / `infd`); (3, Low) скалярные поля JSON не фильтровались через `| strings` и `basename` вызывался без `--` и fallback `dir="."`; (4, Low) в `Purpose` ветка `MAIN_BRANCH` была названа «нейтральная» вместо «серая» (`GRAY` по `INV-3`); (5, Low) в `RISK-2` был перевёрнут приоритет `.rate_limits` и `.quota`. Все 5 находок устранены в `contracts/agy.md` (дополнение к исходному замыслу `EP-2` по `INV-4`: включение в `$all` бакетов с непустым `reset_sec`, защита `used_pct` и `fmt_reset`, фильтры `| strings` и `basename --`); повторная точечная верификация тем же аудитором подтвердила закрытие всех 5 находок (`0` остаточных дефектов).
- **Audit Stage B (`RULE-audit-pass`, `3cb0ce29-7a34-45d1-a08c-ccc0f9dd82e4`):** независимый аудит кода и документации подтвердил 100% соответствие `agy/statusline.sh` контракту `contracts/agy.md` (`0` дефектов кода, `bash -n` и `shellcheck -s bash` чисты, `./harness-check.sh check` — exit 0) и выявил 1 находку `Low` в `README.md` (инвертированное описание приоритета `.rate_limits` / `.quota`); формулировка в `README.md` исправлена и подтверждена повторной верификацией (`0` остаточных дефектов).
- **GATE-1:** pass (`bash -n agy/statusline.sh` и `shellcheck -s bash agy/statusline.sh` — exit 0; прогон 48 тестовых сценариев во временных git-репозиториях и в `/tmp`: все 4 ветки `∆:C+N/<bal>` (`-` на чистом/untracked-only/binary-only дереве, `0` на равном балансе, `+B` зелёным, `-B` красным), не-`main` ветка, `reset_in_seconds` / `reset_time` (`Z`, дробные секунды, `+00:00`, прошлое/битое) / `.rate_limits.seven_day.resets_at`, `7d:-/X.X{d|h|m}` для `.quota` и `.rate_limits`, `7d:Y%` без сброса, пороги и промоушен `m`/`h`/`d`, точная ANSI-нейтральность `/X.X{d|h|m}` при красном `7d:3%`, отрицательный зажим, `NaN`/`"NaN"`/`1e999`/`1e308`/`-1e308`/`-1e25`, не-строковые поля и `cwd="-v"`, изоляция семейств `gemini`/`3p`, `Orchestrator`, `LC_ALL=fr_FR.UTF-8`, `NO_COLOR=1`, не-git `""` и `"{}"` — все 48 pass, exit 0, пустой stderr).
- **GATE-2:** pass (`./sync.sh push agy` → `pushed: agy -> /Users/alsiv/.gemini/antigravity-cli/statusline.sh`, `./sync.sh status` → `in sync: qoder claude codex agy`, `.hooks/pre-push </dev/null` — exit 0).
- **GATE-3:** pass (Stage A `3f1a408f-f6d1-41d9-bc28-8fc353880b1e` и Stage B `3cb0ce29-7a34-45d1-a08c-ccc0f9dd82e4` закрыты с нулём остаточных объективных дефектов).

## Chronicle {#chronicle}

- CHANGE-2026-11-15-a — EP-1 (implemented): компонент `agy` (`agy/statusline.sh`) взят под управление контракта `contracts/agy.md` и интегрирован в `sync.sh` (скрипт-онли, без доступа к `~/.gemini/antigravity-cli/settings.json`), `.hooks/pre-push` (`OBJECTS`) и `contracts/AGENTS.md` (`IDX-4`); доработаны сегменты статус-лайна, адаптирована дельта родительского харнесса `b6cc755..cd9a0f8` и обновлён `.harness-pin`.
- CHANGE-2026-11-22-a — EP-2 (implemented): в `agy/statusline.sh` и контракте `contracts/agy.md` git-счётчики объединены в `∆:C+N/<bal>` (`-`/`0`/`+B` зелёным/`-B` красным), добавлен суффикс обратного отсчёта 7-дневной квоты `7d:Y%/X.X{d|h|m}` (`7d:-/X.X{d|h|m}` при отсутствии `%`) из `.rate_limits`/`reset_in_seconds`/`reset_time` с усиленной защитой типов и конечности, обновлены `README.md` (§4) и `contracts/AGENTS.md` (`IDX-4`).

---
id: claude-journal
title: claude — Contract Journal
kind: journal
contract: claude.md
created: 2026-11-15
updated: 2026-11-22
---

# claude — Journal

## Episodes {#episodes}

### EP-1 (status: implemented) — базовая спецификация компонента Claude Code (baseline backfill)
touched: INV-1..INV-6, Specification, GATE-1..GATE-3, RISK-1..RISK-5, QA-1, QA-2

Полный снимок спецификации компонента `claude` (`claude/statusline.sh` и иллюстрация `docs/claude-example.svg`) при переносе из репозитория `~/dev/claude-code-status-line` (коммит `e93beda440c56836641f11f60814b91107318409`, 2026-11-15) в единый репозиторий `~/dev/agent-statusline` (research: [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)). По правилу backfill (`RULE-contract-first`, `RULE-audit-pass`) скрипт перенесён байт-в-байт без скрытых правок; особенности baseline-реализации (поведение на пустом stdin вне git-репозитория и предположения о типах/локали в `rl_seg`) зафиксированы в `RISK-4` и `RISK-5`. Рантайм-копия развёрнута в `~/.claude/statusline.sh`, а привязка `.statusLine` в `~/.claude/settings.json` переведена на `STATUSLINE_SAFE_EFFORT="medium high xhigh" bash ~/.claude/statusline.sh` под управление `./sync.sh`.

GATE-1: pass (2026-11-15) — построчная сверка `claude/statusline.sh` (253 строки) против `Specification` в `contracts/claude.md`: все переменные окружения, 11 переменных палитры и `NO_COLOR`, 11 полей JSON, git-сегменты (`branch`, `∆:C+N`, `δ:+A/-D`), цвета семейств моделей, форматирование и флаг `•eff`, функции `acw_settings` и `ctx_window`, светофоры `NNNk` и `5h`/`7d` покрыты полностью (`(a) = 0`, `(b) = 0`, `(c) = 0`).

GATE-2: pass (2026-11-15) — после выполнения `./sync.sh push` рантайм-копия `~/.claude/statusline.sh` и привязка `.statusLine` в `~/.claude/settings.json` развёрнуты, `./sync.sh status` чист (`in sync: qoder claude codex`), `bash -n claude/statusline.sh` и `.hooks/pre-push` завершаются с кодом 0.

GATE-3: pass (2026-11-15) — независимый аудит backfill-снимка по `RULE-audit-pass` (`audit-prompts` + `audit-causal-structure`, агент `aeae0ef6`, и независимый аудит кода/механики, агент `1d4ad14f`): двунаправленная сверка `Specification` против `claude/statusline.sh` подтвердила 100% покрытие без расхождений. Текстовые находки по контракту и журналу устранены: порядок фиксации `GATE-2` после реального `./sync.sh push` (F-2, High — fixed), снятие inline-маркеров коммита/эпизода в `RISK-4`/`RISK-5`/`QA-1` по `RULE-provenance` (F-5, Medium — fixed), унификация относительного пути журнала в `refs` (F-6, Low — fixed), добавление `cat` в список стандартных утилит `INV-1` и уточнение зависимости пустого stdin от git-дерева с коммитами в `INV-4`/`RISK-4` (Defects 6 и 7.1, Low — fixed).

### EP-2 (status: implemented) — объединение git-счётчиков в ∆:C+N/<bal> и добавление времени до сброса 7d в 7d:Y%/X.X{d|h|m}
touched: Map, Purpose, Invariants (INV-3, INV-4, INV-6), Specification, Acceptance gates (GATE-1), Risks (RISK-5), Q&A (QA-3)

Уплотнить статус-лайн Claude Code, объединив связанные счётчики через единый разделитель `/`:

1. **Единый git-сегмент `∆:C+N/<bal>` (вместо раздельных `∆:C+N  δ:+A/-D`):**
   - Сохранить цветные счётчики файлов (`C` изменённых отслеживаемых жёлтым при `> 0`, `N` новых неотслеживаемых зелёным при `> 0`).
   - Вместо отдельных `+A/-D` рассчитывать чистый баланс изменённых строк по `diffstat` (`la` добавлено, `lr` удалено, суммирование через `LC_ALL=C awk ... END{printf "%.0f", ...}` с фильтрацией бинарных строк `^[0-9]+$`):
     - если `la == 0 && lr == 0` (нет изменённых текстовых строк — чистое дерево, только untracked или только бинарные правки) → нейтральный `-`;
     - если есть правки, но `la == lr` (`bal == 0`) → нейтральный `0`;
     - если `bal > 0` → `+B` зелёным (`GREEN`, информационный слой);
     - если `bal < 0` → `-B` **нейтральным** цветом терминала (чтобы красный `RED` по `INV-3` оставался строго зарезервированным за слоем светофора потолков).
   - Объединённый формат: `∆:C+N/<bal>` (разделитель `/`).

2. **Объединённый сегмент 7-дневного лимита `7d:Y%/X.X{d|h|m}`:**
   - Добавить 12-е поле JSON `week_reset`: извлекается через `jq -r '(.rate_limits?.seven_day?.resets_at? // null) | if type == "number" and isfinite and (isnan | not) and . > 0 then ((. - now) | if . < 0 then 0 else . end) else empty end' <<<"$input" 2>/dev/null`.
   - Добавить вспомогательную функцию `fmt_reset(remaining_seconds)` (`local val; val=$(LC_ALL=C awk -v s="$1" 'BEGIN { ... }') || return 0` с разделением объявления и присваивания для Bash 3.2):
     - при пустом или нечисловом входе завершается без вывода;
     - отрицательные значения зажимает в `0` (`0.0m`, без `-0.0m`), десятичная точка фиксирована через `LC_ALL=C`;
     - выбирает единицу с повышением разряда при граничном округлении: `>= 86400` → `%.1fd`; `3600 .. < 86400` → при `sprintf("%.1f", r/3600)+0 >= 24` повышается до `%.1fd`, иначе `%.1fh`; `< 3600` → при `sprintf("%.1f", r/60)+0 >= 60` повышается до `%.1fh`, иначе `%.1fm`;
     - защищает вывод от переполнения / `inf`: `if (out !~ /^[0-9]+[.][0-9][dhm]$/ || length(out) > 18) exit 1; print out`.
   - Объединение с `7d` в блоке `rl`:
     - если есть и процент `7d:Y%`, и время сброса `rt` → `${seg}/${rt}` (цвет светофора закрывается `${RESET}` до `/`, чтобы `/${rt}` оставался нейтральным по `INV-3`);
     - если процента `7d` нет, а время сброса `rt` есть → `7d:-/${rt}` (нейтральный);
     - если времени сброса нет или поле невалидно (`null`, строка, `NaN`, `Infinity`, `<= 0`, переполнение) → обычный `7d:Y%` (или пропуск при отсутствии обоих).

3. **Документация, превью и индекс:** обновить `docs/claude-example.svg` (под новый макет `∆:2+1/+35` и `7d:3%/2.4d`), секцию 2 `README.md` (`Claude Code (claude)`) и строку `IDX-2` в `contracts/AGENTS.md`.
- **Audit Stage A (`RULE-homogenization` + `RULE-audit-pass`, `f7bdd717-07b0-4ee8-9e43-afcffa768ce4`):** независимый аудит черновика `contracts/claude.md` выявил 4 объективные находки (1 High, 2 Medium, 1 Low): (1, High) в `GATE-1` смешаны отрицательный JSON `resets_at` (отбрасывается фильтром `. > 0`) и прошедший положительный `resets_at` (`0 < resets_at < now`, дающий `0.0m`); (2, Medium) в `GATE-1` прогон `LC_ALL=fr_FR.UTF-8` не был ограничен под `RISK-5` (целочисленным или пустым `used_percentage` в `rl_seg`); (3, Medium) прогон `не-объектного .rate_limits` в `GATE-1` не учитывал stderr полей 10–11 в `RISK-5`; (4, Low) в `QA-3` п. 2 нарушал `RULE-provenance` формулировкой «замена отдельного сегмента δ:+A/-D». Все 4 находки устранены правками `GATE-1`, `RISK-5` и `QA-3` в `contracts/claude.md`; повторная точечная верификация тем же аудитором подтвердила закрытие всех 4 находок (`0` остаточных дефектов).
- **Audit Stage B (`RULE-audit-pass`, `d3a00895-de5d-4c5f-9b6e-234c85a09b83`):** независимый аудит кода, превью `docs/claude-example.svg`, секции 2 `README.md` и `IDX-2` в `contracts/AGENTS.md` подтвердил 100% соответствие `claude/statusline.sh` контракту `contracts/claude.md` (`0` объективных дефектов, `bash -n` и `shellcheck -s bash` чисты, `./harness-check.sh check` — exit 0, `xmllint --noout` на `docs/claude-example.svg` чист, ссылки Gate 3 валидны).
- **GATE-1:** pass (`bash -n claude/statusline.sh` и `shellcheck -s bash claude/statusline.sh` — exit 0, 0 предупреждений; прогон 34 сценариев во временных git-репозиториях и `/tmp`: все 4 ветки `∆:C+N/<bal>` (`-` на чистом/untracked-only/binary-only дереве, `0` на равном балансе, `+B` зелёным, `-B` нейтральным без `RED`), не-`main` ветка, динамические `resets_at` и промоушен `m`/`h`/`d`, прошлое положительное `resets_at` и прямой `fmt_reset -5` → `0.0m`, `7d:-/X.X{d|h|m}` без `used_percentage`, точная ANSI-нейтральность `/2.4d` при красном `7d:3%`, пропуск `null`/`0`/`-10`/`NaN`/`"NaN"`/`1e999`/`1e308`, не-объектный `.rate_limits` (`exit 0`, без суффикса, допустимый `jq`-stderr полей 10–11 по `RISK-5`), `LC_ALL=fr_FR.UTF-8` по `RISK-5`, `NO_COLOR=1`, деградация на `""` и `"{}"` — все 34 pass, exit 0).
- **GATE-2:** pass (`./sync.sh push claude` → `pushed: claude -> /Users/alsiv/.claude/statusline.sh`, `./sync.sh status` → `in sync: qoder claude codex agy`, `.hooks/pre-push </dev/null` — exit 0).
- **GATE-3:** pass (Stage A `f7bdd717-07b0-4ee8-9e43-afcffa768ce4` и Stage B `d3a00895-de5d-4c5f-9b6e-234c85a09b83` закрыты с нулём остаточных объективных дефектов).

## Chronicle {#chronicle}

CHANGE-2026-11-15-a — EP-1 (implemented): импорт `claude/statusline.sh` и `docs/claude-example.svg` из `~/dev/claude-code-status-line` (`e93beda`) в `~/dev/agent-statusline`, создание backfill-контракта `contracts/claude.md` и журнала `contracts/claude-journal.md`, добавление `IDX-2` в `contracts/AGENTS.md`, подключение `~/.claude/statusline.sh` и `.statusLine` в `~/.claude/settings.json` через `./sync.sh` (research: [../analysis/2026-11-15-multi-harness-statusline-research.md](../analysis/2026-11-15-multi-harness-statusline-research.md)). Все находки независимого аудита (`aeae0ef6` и `1d4ad14f`) устранены и верифицированы.

CHANGE-2026-11-22-a — EP-2 (implemented): в `claude/statusline.sh` и контракте `contracts/claude.md` git-счётчики объединены в `∆:C+N/<bal>` (`-`/`0`/`+B` зелёным/`-B` нейтральным без `RED`), добавлен суффикс обратного отсчёта 7-дневного лимита `7d:Y%/X.X{d|h|m}` (`7d:-/X.X{d|h|m}` при отсутствии `%`) из `.rate_limits.seven_day.resets_at` с защитой типов и переполнения, обновлены `docs/claude-example.svg`, `README.md` (§2) и `contracts/AGENTS.md` (`IDX-2`).

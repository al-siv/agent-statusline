---
id: statusline-credits-payload-research
title: research — поле credits в stdin статус-лайна Qoder CLI
kind: research
created: 2026-09-19
component: statusline
cli_version_observed: 1.1.57
---

# research — месяц кредитов: откуда брать число для статус-лайна

## Постановка

Нужен сегмент «процент оставшихся месячных кредитов». Вариант источника — HTTP-запрос к `/api/v2/quota/usage` прямо из скрипта — отклонён: статус-лайн вызывается на каждом обновлении, скрипт был бы зависим от токена (чтение `~/.qoder-cn/.auth/user`, зашифрованный файл) и от сети; это ломает и INV-1 (зависимости — только `jq` и `git`), и границу «скрипт ничего не знает об учётных данных».

Рабочая гипотеза: CLI уже кладёт снимок квоты в JSON, который передаёт в stdin статус-лайна. Проверена разбором бинарника версии, на которой работает рантайм.

## Метод

`strings -n 6 ~/.qoder-cn/bin/qoderclicn/qoderclicn-1.1.57` с точечными выборками по идентификаторам (бинарник — минифицированный JS-бандл, имена функций стабильны внутри модуля). Дата наблюдения: 2026-09-19. Версия: `bin/qoderclicn/version.txt` → 1.1.57.

## Находки

**1. Сборщик stdin статус-лайна включает `credits`.** Функция `WJ(t)` строит объект, который CLI передаёт скрипту: `session_id`, `session_name`, `cwd`, `transcript_path`, `permission_mode`, `model{id,display_name}`, `workspace{current_dir,project_dir,added_dirs}`, `version`, `cost{total_lines_added,total_lines_removed,total_credits}`, далее условно:

```js
if (t.credits) r.credits = t.credits;
if (t.contextWindowSize !== void 0)
  r.context_window = { total_input_tokens, total_output_tokens,
                       context_window_size, used_percentage, remaining_percentage };
```

То есть `credits` — поле того же уровня, что уже используемый `context_window`: появляется при непустом снимке квоты и отсутствует, если снимка нет (graceful-деградация уже заложена в формулировку входа).

**2. Источник значения — хук снимка квоты, активный ровно при настроенном статус-лайне.** В модуле статус-лайна (стрелочная функция, экспортируемая как `StatusLineInput`-adjacent hook): `F = _(R) && !D` — «statusLine командой настроен и хуки не отключены», `q = Gv(F)` — снимок квоты, `fn = Vv(ce.current)` — то, что уходит в `t.credits`, `ee = q ? Ju(q) : void 0`. Следствие: separate-запрос из скрипта не нужен; пока статус-лайн включён, CLI держит снимок.

**3. Форма `credits` (сериализатор `Vv`, snake_case).**

```
total_remaining            // Ju(n) = userQuota.remaining + addOnQuota.remaining + orgResourcePackage.remaining
total_usage_percentage     // по данным сервера
is_quota_exceeded
expires_at                 // epoch ms — конец расчётного периода плана
unit                       // только при непустом unit у user_quota; по умолчанию "credits"
user_quota            { total, used, remaining, percentage }
add_on_quota          { total, used, remaining, percentage, detailUrl? }
org_resource_package  { cap, used, remaining, percentage }
dedicated_resource_packages[] { id, name, total, used, remaining, percentage, unit, expires_at?, available, status, display_labels }
```

**4. Семантика `percentage` — ИСПОЛЬЗОВАНО, не остаток.** Нормализатор пула `fl`:

```js
total = r.total ?? 0; used = r.used ?? 0;
remaining = r.remaining ?? Math.max(total - used, 0);
percentage = r.percentage ?? (total > 0 ? used / total : undefined);
// Xr: значение 0..1 трактуется как доля и умножается на 100, иначе уже проценты
```

Для org-пула (`Oh`) то же с `cap`. Проверка по UI-подписям того же бинарника: `["Plan Credits Used", `${userQuota.used}/${userQuota.total}`]`. Значит «осталось» показывать как `remaining / total`, либо как `100 - percentage`; первое не зависит от трактовки `percentage` и от того, прислал ли сервер `remaining` или вывел его, — выбрано оно.

**5. Свежесть.** `getQuotaUsage` читается через `getCachedAccountResource("quotaUsage", vh, …)`, `vh = 15000` мс; при просрочке — `GET {openapi}/api/v2/quota/usage` с `Authorization: Bearer …` (openapi-эндпоинт из `~/.qoder-cn/.cache/endpoint-cache.json` → `https://openapi.qoder.com.cn`). Следствие для контракта: скрипт сети не делает и показывает то, что в момент рендера лежит в снимке харнесса. 15 с — потолок кэша запроса, а не наблюдаемая периодичность обновления кадра; метки времени в снимке нет, поэтому возраст числа ничем не ограничен, кроме поведения харнесса (в RISK-4 это записано как остаточное). Формулировка периода: встроенная команда CLI описывает источник как «usage statistics for the current billing period»; сброс планового пула — по `expires_at`. «Месячный» характер следует из биллингового периода подписки, а не из отдельного поля ответа.

**6. Отсутствие данных.** Снимка нет (`q` undefined: не аутентифицирован, ошибка API, enterprise-режим `usagePresentation`, у которого снимок квоты инвалидируется) → поля `credits` в stdin нет. `user_quota.total == 0` (например `Math.max(0-0,0)` при пустом пуле) → отношение неопределено. Оба случая — сегмент молча пропадает, как и остальные поля по INV-4.

## Живое подтверждение

Разбор бинарника сам по себе кадра не доказывает, поэтому поле проверено на настоящем stdin. Способ (воспроизводим): в `~/.qoder-cn/settings.json` временно поставить `statusLine.command` на wrapper, который пишет полученный stdin в файл и передаёт его настоящему скрипту; затем запустить второй экземпляр CLI в pty (`pty.fork` + `entry/qoder-cn -w <доверенный каталог>`) и дождаться первого кадра. В недоверенном каталоге процесса до кадра не доходит — CLI останавливается на диалоге Trust folder. После съёмки настройки возвращаются на `~/.qoder-cn/statusline-command.sh`.

Наблюдено 2026-09-19, CLI 1.1.57, кадр через ~5 с после старта. Фрагмент реального stdin (личное вырезано):

```json
{ "model": { "id": "qmodel_38max", "display_name": "Qwen3.8-Max" },
  "context_window": { "context_window_size": 1000000, "used_percentage": 0, ... },
  "credits": {
    "total_remaining": 14890, "total_usage_percentage": 26,
    "is_quota_exceeded": false, "expires_at": 1791043200000, "unit": "credits",
    "user_quota": { "total": 20000, "used": 5110, "remaining": 14890, "percentage": 26 },
    "dedicated_resource_packages": [ { "id": "<вырезано>", "name": "<вырезано>",
        "total": 1000, "used": 1000, "remaining": 0, "percentage": 100,
        "status": "QUOTA_DETAIL_STATUS_EXHAUSTED", "available": false, ... } ]
  } }
```

Сегмент на этих данных: `cr 74%` (14890/20000 = 74.45 → `round` → 74), в строке между `ctx` и `AG`. Тот же кадр, наблюдавшийся в TUI запущенного экземпляра CLI: `❯ Qwen3.8-Max 1M | ctx 0% | cr 74% | NO GIT! | ~/dev`. Первый кадр той же сессии — `❯ Qmodel_38max 1M | ctx 0% | NO GIT! | ~/dev`, без `cr`: снимок квоты ещё не пришёл, и сегмент пропал именно так, как предписывает деградация (п. 6). Подтверждены п. 4 (`percentage` = использованное: 26 против отображаемого остатка 74), п. 3 (состав `credits`) и п. 1–2 (поле приходит, пока настроен статус-лайн). Сценарий enterprise-представления и неаутентифицированный процесс не наблюдались — для них остаётся только вывод п. 6 (поле отсутствует → сегмент скрыт), проверенный на синтетических payload'ах.

Сырой снимок кадра в репозиторий не попадает: в нём `session_id`, пути и идентификаторы пулов; разбор ведётся по вырезанным выше полям.

## Вывод для компонента

Ещё одно поле в том же единственном разборе `jq` (четвёртое в разборе из шести, третье в выводе — сразу после `ctx`): `.credits.user_quota` → `round(remaining / total * 100)` с clamp 0..100 и guard `total > 0`; рендер `cr N%`. Ни нового вызова `jq`, ни новых зависимостей, ни сети, ни файлов кэша.

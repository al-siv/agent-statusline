#!/usr/bin/env bash
# harness-check.sh — периодическая сверка с харнессом родителя
# (~/dev/qoder-skills): пин хэшей вместо прямой зависимости от
# «принципов родителя».
#
# Использование:
#   ./harness-check.sh          сверка текущего состояния с пином:
#                               exit 0 — пин актуален; exit 1 — расхождение
#                               (запустить процедуру адаптации из AGENTS.md);
#                               exit 2 — чекер не вынес вердикта (испорченный
#                               пин, недоступный родитель). Коды различаются,
#                               потому что pre-push трактует их по-разному.
#   ./harness-check.sh pin      переписать пин по текущему состоянию
#                               родителя (только после выполненной
#                               адаптации)
#   ./harness-check.sh show     показать пин
#
# Пин (.harness-pin) хранит sha256 файлов харнесса родителя, дату последней
# адаптации ЭТОГО репо и базу каждого файла — коммит родителя, из которого взят
# его хэш (`dirty(<HEAD>)`, если совпадения с коммитом нет). Базы бывают разными
# для разных файлов: пин — снимок содержимого, а не один срез родителя, и без
# записанной базы это не видно. Git-история родителя дальше не фиксируется: её
# коммиты — преимущественно доработка скиллов. Содержимое файлов не копируется —
# зеркалирование запрещено политикой.
set -euo pipefail

PARENT_DIR="${PARENT_HARNESS:-$HOME/dev/qoder-skills}"
PIN_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.harness-pin"
# Файлы харнесса родителя, к изменениям которых этот репо адаптируется.
# sync.sh родителя не пинуется: это механика синхронизации скиллов,
# к проекту с одним компонентом нерелевантная. Имена без пробелов: список
# разбирается по словам, пробел в имени разошёлся бы с обходом.
PARENT_FILES="AGENTS.md contracts/AGENTS.md .hooks/pre-push"

die() { echo "error: $*" >&2; exit 2; }

[ -d "$PARENT_DIR" ] || die "parent harness not found: $PARENT_DIR (override: PARENT_HARNESS)"
for _f in $PARENT_FILES; do
  case "$_f" in *[[:space:]]*) die "PARENT_FILES: '$_f' содержит пробел — список разбирается по словам" ;; esac
done

current_hashes() { # hash + relative path for each pinned parent file
    local f
    for f in $PARENT_FILES; do
        [ -f "$PARENT_DIR/$f" ] || die "parent file not found: $PARENT_DIR/$f (harness structure changed — review the pinned file list)"
        ( cd "$PARENT_DIR" && shasum -a 256 "$f" )
    done
}

normalized() { # 'hash path' pairs, whitespace-insensitive, sorted by path
    grep -E '^[0-9a-f]{64}[[:space:]]' | awk '{print $1 " " $2}' | sort -k2
}

blob_hash_at() { # hash of <rev>:<path> in the parent, empty if absent
    local rev="$1" f="$2"
    git -C "$PARENT_DIR" show "$rev:$f" 2>/dev/null | shasum -a 256 | cut -d' ' -f1
}

resolve_base() { # commit whose blob matches the pinned content: sha | 'dirty' | 'unknown'
    local f="$1" want="$2" head c
    head="$(git -C "$PARENT_DIR" rev-parse --short HEAD 2>/dev/null)" || { echo unknown; return; }
    # быстрый путь: состояние HEAD (обычный случай — чистое дерево родителя)
    [ "$(blob_hash_at "$head" "$f")" = "$want" ] && { echo "$head"; return; }
    # иначе — ближайшее изменение файла, чей blob совпадает; не совпал ни один
    # коммит (снимок снят с рабочего дерева либо база вне доступной истории) -> dirty/unknown
    while IFS= read -r c; do
        [ "$(blob_hash_at "$c" "$f")" = "$want" ] && { echo "$c"; return; }
    done < <(git -C "$PARENT_DIR" rev-list --max-count=200 HEAD -- "$f" 2>/dev/null)
    if [ "$( cd "$PARENT_DIR" && shasum -a 256 "$f" | cut -d' ' -f1 )" = "$want" ]; then
        echo "dirty($head)"
    else
        echo unknown
    fi
}

pin_base_lines() { # provenance of each pinned file: the commit it was taken from
    local f h
    for f in $PARENT_FILES; do
        [ -f "$PARENT_DIR/$f" ] || die "parent file not found: $PARENT_DIR/$f — пин не переписан (структура харнесса родителя изменилась?)"
        h="$( cd "$PARENT_DIR" && shasum -a 256 "$f" | cut -d' ' -f1 )"
        echo "# база $f: $(resolve_base "$f" "$h")"
    done
}

cmd_pin() {
    # Пин обязан быть воспроизводимым: хэши без состояния родителя, из которого
    # они сняты, дают дельту, которую приходится выбирать на глаз (случай пина
    # 2026-08-17 — три хэша из трёх разных коммитов родителя, восстановленные
    # перебором истории).
    #
    # Запись атомарная: оборванный на середине пин хуже отсутствующего.
    local tmp
    tmp="$(mktemp "${PIN_FILE}.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    {
        echo "# harness-pin: хэши файлов харнесса родителя ($PARENT_DIR)"
        echo "# переписан: $(date +%Y-%m-%d) (дата последней адаптации этого репо)"
        pin_base_lines
        current_hashes
    } > "$tmp"
    mv "$tmp" "$PIN_FILE"
    trap - EXIT
    echo "pin updated: $PIN_FILE"
    grep '^# база ' "$PIN_FILE" | sed 's/^/  /'
}

cmd_show() {
    [ -f "$PIN_FILE" ] || die "pin not found: $PIN_FILE (run: ./harness-check.sh pin)"
    cat "$PIN_FILE"
}

cmd_check() {
    [ -f "$PIN_FILE" ] || die "pin not found: $PIN_FILE (run: ./harness-check.sh pin)"
    local pinned current pin_date delta_hint f base
    # grep без совпадения + pipefail иначе обрывает скрипт кодом 1, который
    # неотличим от вердикта «расхождение»: пустой результат читается явно.
    pinned="$(normalized < "$PIN_FILE" || true)"
    [ -n "$pinned" ] || die "в пине нет ни одной хэш-строки — испорчен $PIN_FILE (перепишите: ./harness-check.sh pin)"
    # два шага, а не один пайп: die внутри current_hashes в пайпе отдаёт свой
    # exit 2 через pipefail не правым звеном, и отказ чекера стал бы «расхождением»
    current_raw="$(current_hashes)"
    current="$(printf '%s\n' "$current_raw" | normalized)"
    pin_date="$(grep -m1 '^# переписан:' "$PIN_FILE" | sed -nE 's/^# переписан: ([0-9-]+).*/\1/p' || true)"
    if [ "$pinned" = "$current" ]; then
        echo "harness-check: пин актуален — харнесс родителя не менялся с адаптации ${pin_date:-'?'}."
        grep '^# база ' "$PIN_FILE" | sed 's/^# база /  база: /' || true
        return 0
    fi
    echo "harness-check: харнесс родителя изменился относительно пина:" >&2
    diff <(echo "$pinned") <(echo "$current") >&2 || true
    # Дельта читается от базы каждого файла; база может отсутствовать (пин до
    # фиксации баз или снимок с грязного дерева) — это говорится вслух.
    delta_hint=""
    for f in $PARENT_FILES; do
        base="$(grep -m1 "^# база $f: " "$PIN_FILE" | sed -E "s|^# база $f: (.*)|\1|" || true)"
        case "$base" in
            ""|unknown|dirty*)
                delta_hint="$delta_hint  git -C $PARENT_DIR log --since=${pin_date:-дату пина} -p -- $f   # база: ${base:-не записана — выбирать по дате}"$'\n'
                ;;
            *)
                delta_hint="$delta_hint  git -C $PARENT_DIR diff $base..HEAD -- $f"$'\n'
                ;;
        esac
    done
    {
        echo "Процедура адаптации (AGENTS.md, секция «Связка с харнессом qoder-skills»):"
        echo "  1. изменения родителя по файлам пина:"
        printf '%s' "$delta_hint" | sed 's/^/     /'
        echo "  2. по каждому изменению решить: переносится ли оно в локальную"
        echo "     адаптацию (конфликт правил — локальная правка обязательна);"
        echo "  3. применить локальные изменения контрактным циклом этого репо;"
        echo "  4. ./harness-check.sh pin — переписать пин."
    } >&2
    exit 1
}

case "${1:-check}" in
    check) cmd_check ;;
    pin)   cmd_pin ;;
    show)  cmd_show ;;
    *)     die "usage: $0 {check|pin|show}" ;;
esac

#!/usr/bin/env bash
# harness-check.sh — периодическая сверка с харнессом родителя
# (~/dev/agent-skills): пин хэшей вместо прямой зависимости от
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

PARENT_DIR="${PARENT_HARNESS:-$HOME/dev/agent-skills}"
PIN_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.harness-pin"
# Файлы харнесса родителя, к изменениям которых этот репо адаптируется.
# rules/skill-authoring.md и rules/verification.md охватывают общие правила
# размещения, формулировок и независимой верификации (включая документы харнесса);
# sync.sh не пинуется, так как относится только к синхронизации каталогов скиллов.
# Имена без пробелов: список разбирается по словам, пробел в имени разошёлся бы с обходом.
PARENT_FILES="AGENTS.md rules/skill-authoring.md rules/verification.md .hooks/pre-push"

die() { echo "error: $*" >&2; exit 2; }

[ -d "$PARENT_DIR" ] || die "parent harness not found: $PARENT_DIR (override: PARENT_HARNESS)"
for _f in $PARENT_FILES; do
  case "$_f" in *[[:space:]]*) die "PARENT_FILES: '$_f' содержит пробел — список разбирается по словам" ;; esac
done

current_hashes() { # хэш и относительный путь для каждого пинуемого файла родителя
    local f
    for f in $PARENT_FILES; do
        [ -f "$PARENT_DIR/$f" ] || die "parent file not found: $PARENT_DIR/$f (harness structure changed — review the pinned file list)"
        [ -r "$PARENT_DIR/$f" ] || die "parent file not readable: $PARENT_DIR/$f"
        ( cd "$PARENT_DIR" && shasum -a 256 "$f" ) || die "failed to hash parent file: $PARENT_DIR/$f"
    done
}

normalized() { # пары 'hash path', нечувствительные к числу пробелов, отсортированные по пути
    grep -E '^[0-9a-f]{64}[[:space:]]+[^[:space:]]+[[:space:]]*$' | awk '{print $1 " " $2}' | sort -k2
}

blob_hash_at() { # хэш объекта <rev>:<path> в родителе; пусто, если объект отсутствует
    local rev="$1" f="$2"
    git -C "$PARENT_DIR" cat-file -e "$rev:$f" 2>/dev/null || return 0
    git -C "$PARENT_DIR" show "$rev:$f" 2>/dev/null | shasum -a 256 | cut -d' ' -f1
}

resolve_base() { # коммит, чей blob совпадает с пинуемым содержимым: sha | 'dirty' | 'unknown'
    local f="$1" want="$2" head c
    head="$(git -C "$PARENT_DIR" rev-parse --short HEAD 2>/dev/null)" || { echo unknown; return; }
    # быстрый путь: состояние HEAD (обычный случай — чистое дерево родителя)
    [ "$(blob_hash_at "$head" "$f")" = "$want" ] && { echo "$head"; return; }
    # иначе — ближайшее изменение файла, чей blob совпадает; не совпал ни один
    # коммит (снимок снят с рабочего дерева либо база вне доступной истории) -> dirty/unknown
    while IFS= read -r c; do
        [ "$(blob_hash_at "$c" "$f")" = "$want" ] && { echo "$c"; return; }
    done < <(git -C "$PARENT_DIR" rev-list --abbrev-commit HEAD -- "$f" 2>/dev/null)
    if [ "$( cd "$PARENT_DIR" && shasum -a 256 "$f" | cut -d' ' -f1 )" = "$want" ]; then
        echo "dirty($head)"
    else
        echo unknown
    fi
}

pin_base_lines() { # происхождение каждого файла пина: коммит родителя, из которого взят хэш
    local f h
    for f in $PARENT_FILES; do
        [ -f "$PARENT_DIR/$f" ] || die "parent file not found: $PARENT_DIR/$f — пин не переписан (структура харнесса родителя изменилась?)"
        [ -r "$PARENT_DIR/$f" ] || die "parent file not readable: $PARENT_DIR/$f — пин не переписан"
        h="$( cd "$PARENT_DIR" && shasum -a 256 "$f" | cut -d' ' -f1 )" || die "failed to hash parent file: $PARENT_DIR/$f"
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
    [ -r "$PIN_FILE" ] || die "pin not readable: $PIN_FILE"
    cat "$PIN_FILE"
}

shell_quote() { # UTF-8-безопасное POSIX-экранирование без искажения многобайтовых символов
    local s="$1" sq="'\''"
    case "$s" in
        "") printf "''" ;;
        *[!A-Za-z0-9_./:@=-]*) printf "'%s'" "${s//"'"/"$sq"}" ;;
        *) printf '%s' "$s" ;;
    esac
}

cmd_check() {
    [ -f "$PIN_FILE" ] || die "pin not found: $PIN_FILE (run: ./harness-check.sh pin)"
    [ -r "$PIN_FILE" ] || die "pin not readable: $PIN_FILE"
    local pinned current pin_date delta_hint f base q_parent q_f q_rev want_hash cur_hash match_rev expected_files pinned_files
    if grep -vE '^[[:space:]]*(#|$)|^[0-9a-f]{64}[[:space:]]+[^[:space:]]+[[:space:]]*$' "$PIN_FILE" >/dev/null 2>&1; then
        die "в пине есть нераспознанные строки — испорчен $PIN_FILE (перепишите: ./harness-check.sh pin)"
    fi
    # grep без совпадения + pipefail иначе обрывает скрипт кодом 1, который
    # неотличим от вердикта «расхождение»: пустой результат читается явно.
    pinned="$(normalized < "$PIN_FILE" || true)"
    [ -n "$pinned" ] || die "в пине нет ни одной хэш-строки — испорчен $PIN_FILE (перепишите: ./harness-check.sh pin)"
    expected_files="$(for f in $PARENT_FILES; do printf '%s\n' "$f"; done | sort)"
    pinned_files="$(printf '%s\n' "$pinned" | awk '{print $2}')"
    if [ "$pinned_files" != "$expected_files" ]; then
        die "состав файлов в $PIN_FILE не совпадает с PARENT_FILES — испорчен или устарел пин (перепишите: ./harness-check.sh pin)"
    fi
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
    q_parent="$(shell_quote "$PARENT_DIR")"
    for f in $PARENT_FILES; do
        want_hash="$(printf '%s\n' "$pinned" | awk -v p="$f" '$2 == p {print $1; exit}')"
        cur_hash="$(printf '%s\n' "$current" | awk -v p="$f" '$2 == p {print $1; exit}')"
        [ "$want_hash" = "$cur_hash" ] && continue
        q_f="$(shell_quote "$f")"
        base="$(grep -m1 "^# база $f: " "$PIN_FILE" | sed -E "s|^# база $f: (.*)|\1|" || true)"
        case "$base" in
            dirty\(*\))
                match_rev=""
                if [ -n "$want_hash" ]; then
                    match_rev="$(resolve_base "$f" "$want_hash" 2>/dev/null || true)"
                fi
                case "$match_rev" in
                    ""|unknown|dirty*)
                        delta_hint="$delta_hint  # база $f: $base — совпавшего commit-blob в истории нет; пересмотреть текущий $PARENT_DIR/$f целиком"$'\n'
                        ;;
                    *)
                        q_rev="$(shell_quote "$match_rev")"
                        delta_hint="$delta_hint  # база $f: $base (blob совпадает с $match_rev)"$'\n'"  git -C $q_parent diff $q_rev -- $q_f"$'\n'
                        ;;
                esac
                ;;
            ""|unknown|dirty*)
                q_rev="$(shell_quote "${pin_date:-дату пина}")"
                delta_hint="$delta_hint  # база $f: ${base:-не записана} — выбирать по дате"$'\n'"  git -C $q_parent log --since=$q_rev -p -- $q_f"$'\n'
                ;;
            *)
                q_rev="$(shell_quote "$base")"
                delta_hint="$delta_hint  git -C $q_parent diff $q_rev -- $q_f"$'\n'
                ;;
        esac
    done
    {
        echo "Процедура адаптации (AGENTS.md, секция «Связка с харнессом agent-skills»):"
        echo "  1. изменения родителя по файлам пина:"
        printf '%s' "$delta_hint" | sed 's/^/     /'
        echo "  2. по каждому изменению решить: переносится ли оно в локальную"
        echo "     адаптацию (конфликт правил — локальная правка обязательна);"
        echo "  3. применить локальные изменения по правилам этого репо (contract-first там, где затронут компонент);"
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

#!/usr/bin/env bash
# harness-check.sh — периодическая сверка с харнессом родителя
# (~/dev/qoder-skills): пин хэшей вместо прямой зависимости от
# «принципов родителя».
#
# Использование:
#   ./harness-check.sh          сверка текущего состояния с пином (exit 1
#                               при расхождении: запустить процедуру
#                               адаптации из AGENTS.md)
#   ./harness-check.sh pin      переписать пин по текущему состоянию
#                               родителя (только после выполненной
#                               адаптации)
#   ./harness-check.sh show     показать пин
#
# Пин (.harness-pin) хранит sha256 файлов харнесса родителя и дату
# последней адаптации ЭТОГО репо. Git-состояние родителя не фиксируется:
# его коммиты — преимущественно доработка скиллов, к этому проекту
# отношения не имеет. Содержимое файлов не копируется — зеркалирование
# запрещено политикой.
set -euo pipefail

PARENT_DIR="${PARENT_HARNESS:-$HOME/dev/qoder-skills}"
PIN_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.harness-pin"
# Файлы харнесса родителя, к изменениям которых этот репо адаптируется.
# sync.sh родителя не пинуется: это механика синхронизации скиллов,
# к проекту с одним компонентом нерелевантная.
PARENT_FILES="AGENTS.md contracts/AGENTS.md .hooks/pre-push"

die() { echo "error: $*" >&2; exit 2; }

[ -d "$PARENT_DIR" ] || die "parent harness not found: $PARENT_DIR (override: PARENT_HARNESS)"

current_hashes() { # hash + relative path for each pinned parent file
    local f
    for f in $PARENT_FILES; do
        [ -f "$PARENT_DIR/$f" ] || die "parent file not found: $PARENT_DIR/$f (harness structure changed — review the pinned file list)"
        ( cd "$PARENT_DIR" && shasum -a 256 "$f" )
    done
}

cmd_pin() {
    {
        echo "# harness-pin: хэши файлов харнесса родителя ($PARENT_DIR)"
        echo "# переписан: $(date +%Y-%m-%d) (дата последней адаптации этого репо)"
        current_hashes
    } > "$PIN_FILE"
    echo "pin updated: $PIN_FILE"
}

cmd_show() {
    [ -f "$PIN_FILE" ] || die "pin not found: $PIN_FILE (run: ./harness-check.sh pin)"
    cat "$PIN_FILE"
}

cmd_check() {
    [ -f "$PIN_FILE" ] || die "pin not found: $PIN_FILE (run: ./harness-check.sh pin)"
    local pinned current pin_date
    pinned="$(grep -E '^[0-9a-f]{64} ' "$PIN_FILE" | sort -k2)"
    current="$(current_hashes | sort -k2)"
    pin_date="$(grep -m1 '^# переписан:' "$PIN_FILE" | sed -nE 's/^# переписан: ([0-9-]+).*/\1/p')"
    if [ "$pinned" = "$current" ]; then
        echo "harness-check: пин актуален — харнесс родителя не менялся с адаптации $pin_date."
        return 0
    fi
    echo "harness-check: харнесс родителя изменился относительно пина:" >&2
    diff <(echo "$pinned") <(echo "$current") >&2 || true
    {
        echo "Процедура адаптации (AGENTS.md, секция «Связка с харнессом qoder-skills»):"
        echo "  1. git -C $PARENT_DIR log --since=$pin_date -p -- <файлы пина> — что изменилось;"
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

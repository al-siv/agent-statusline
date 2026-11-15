#!/usr/bin/env bash
# sync.sh — синхронизация скрипта статус-лайна между этим репозиторием и
# рантайм-файлом Qoder CLI (~/.qoder-cn/statusline-command.sh, доступным
# через симлинк ~/.qoder).
#
# Использование:
#   ./sync.sh status   показать дрифт между репо и рантаймом (exit 0 — чисто,
#                      exit 1 — дрифт, exit 2 — ошибка чтения/сравнения)
#   ./sync.sh push     репо -> рантайм (репо — источник правды)
#   ./sync.sh pull     предупредить и отказать в записи (contract-first:
#                      править в репо, затем push)
#   ./sync.sh pull --confirmed statusline
#                      принять копию из рантайма после явного подтверждения
#                      пользователя (классификация предшествует действию)
#
# Безопасность:
#   - Синхронизируется только файл компонента; файлы харнесса (AGENTS.md,
#     contracts/, analysis/, .hooks/, sync.sh, harness-check.sh) в рантайм
#     не попадают.
#   - Вызов pull без подтверждения никогда не пишет файлы: он классифицирует
#     дрифт и отказывает, как в родительском харнессе ~/dev/agent-skills.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_FILE="$REPO_DIR/statusline-command.sh"
RUNTIME_FILE="${STATUSLINE_RUNTIME:-$HOME/.qoder-cn/statusline-command.sh}"
OBJECT="statusline"

die() { echo "error: $*" >&2; exit 2; }

# Разрешаем симлинки в пути каталога рантайма: ~/.qoder может быть симлинком
# на ~/.qoder-cn даже тогда, когда сам файл статус-лайна ещё не создан.
if [ -d "$(dirname "$RUNTIME_FILE")" ]; then
    runtime_dir="$(cd "$(dirname "$RUNTIME_FILE")" 2>/dev/null && pwd -P)" || die "cannot resolve runtime directory: $(dirname "$RUNTIME_FILE")"
    RUNTIME_FILE="$runtime_dir/$(basename "$RUNTIME_FILE")"
fi

drift_report() { # печать строк дрифта; 0 = in sync, 1 = дрифт, 2 = ошибка чекера
    [ -f "$REPO_FILE" ] && [ -r "$REPO_FILE" ] || die "repo file not readable: $REPO_FILE"
    if [ ! -e "$RUNTIME_FILE" ] && [ ! -L "$RUNTIME_FILE" ]; then
        echo "runtime-missing: $RUNTIME_FILE"
        return 1
    fi
    [ -f "$RUNTIME_FILE" ] && [ -r "$RUNTIME_FILE" ] || die "runtime file not readable: $RUNTIME_FILE"
    local cmp_rc=0
    cmp -s "$REPO_FILE" "$RUNTIME_FILE" || cmp_rc=$?
    if [ "$cmp_rc" -gt 1 ]; then
        die "cmp failed for $REPO_FILE and $RUNTIME_FILE (exit $cmp_rc)"
    fi
    if [ "$cmp_rc" -eq 1 ]; then
        echo "drift:         $OBJECT (repo != runtime)"
        return 1
    fi
    return 0
}

cmd_status() {
    local report rc=0
    report="$(drift_report)" || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "in sync: repo and $RUNTIME_FILE"
        return 0
    fi
    [ -z "$report" ] || echo "$report"
    return "$rc"
}

cmd_push() {
    [ -f "$REPO_FILE" ] && [ -r "$REPO_FILE" ] || die "repo file not found or not readable: $REPO_FILE"
    mkdir -p "$(dirname "$RUNTIME_FILE")"
    cp -p "$REPO_FILE" "$RUNTIME_FILE"
    echo "pushed: $OBJECT -> $RUNTIME_FILE"
}

cmd_pull() {
    local confirmed="${1:-}"
    shift || true
    [ -f "$REPO_FILE" ] && [ -r "$REPO_FILE" ] || die "repo file not found or not readable: $REPO_FILE"
    if [ ! -e "$RUNTIME_FILE" ] && [ ! -L "$RUNTIME_FILE" ]; then
        die "runtime file not found: $RUNTIME_FILE (nothing to pull; use push)"
    fi
    [ -f "$RUNTIME_FILE" ] && [ -r "$RUNTIME_FILE" ] || die "runtime file not readable: $RUNTIME_FILE"
    local cmp_rc=0
    cmp -s "$REPO_FILE" "$RUNTIME_FILE" || cmp_rc=$?
    if [ "$cmp_rc" -gt 1 ]; then
        die "cmp failed for $REPO_FILE and $RUNTIME_FILE (exit $cmp_rc)"
    fi
    if [ "$cmp_rc" -eq 0 ]; then
        echo "nothing to pull: runtime matches repo."
        return 0
    fi
    if [ "$confirmed" != "--confirmed" ]; then
        {
            echo "warning: pull overwrites the repo script with the runtime copy."
            echo "The repo is the source of truth (contract-first): edit in"
            echo "the repo and push. Pull bypasses the contract cycle."
            echo ""
            echo "runtime differs from repo for: $OBJECT"
            echo ""
            echo "Review the drift (./sync.sh status; diff the files). If the"
            echo "runtime edit is intentional and user-approved, re-run with an"
            echo "explicit selection:"
            echo "  ./sync.sh pull --confirmed $OBJECT"
        } >&2
        exit 1
    fi
    if [ $# -eq 0 ]; then
        die "--confirmed needs an explicit selection: '$OBJECT' (bare --confirmed refused)"
    fi
    local selected=0 arg
    for arg in "$@"; do
        if [ "$arg" = "$OBJECT" ]; then
            selected=1
        else
            die "'$arg' is not a known object (pending: $OBJECT)"
        fi
    done
    [ "$selected" -eq 1 ] || die "nothing selected"
    cp -p "$RUNTIME_FILE" "$REPO_FILE"
    echo "pulled: $OBJECT <- $RUNTIME_FILE"
}

case "${1:-}" in
    status) cmd_status ;;
    push)   cmd_push ;;
    pull)   shift; cmd_pull "$@" ;;
    *)      die "usage: $0 {status|push|pull [--confirmed $OBJECT]}" ;;
esac

#!/usr/bin/env bash
# sync.sh — synchronize the status line script between this repo and the
# Qoder CLI runtime file (~/.qoder-cn/statusline-command.sh, reachable
# through the ~/.qoder symlink).
#
# Usage:
#   ./sync.sh status   show drift between repo and runtime (exit 1 if any)
#   ./sync.sh push     repo -> runtime (repo is source of truth)
#   ./sync.sh pull     warn and refuse to write (contract-first: edit repo,
#                      then push)
#   ./sync.sh pull --confirmed statusline
#                      adopt the runtime copy after explicit user approval
#                      of the drift (classification before action)
#
# Safety:
#   - Only the component file is synced; harness files (AGENTS.md, contracts/,
#     analysis/, .hooks/, sync.sh, harness-check.sh) never enter the runtime.
#   - Bare pull never writes: it classifies and refuses, like the parent
#     harness in ~/dev/qoder-skills.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_FILE="$REPO_DIR/statusline-command.sh"
RUNTIME_FILE="${STATUSLINE_RUNTIME:-$HOME/.qoder-cn/statusline-command.sh}"
# Resolve symlinks in the path: ~/.qoder may be a symlink (e.g. to ~/.qoder-cn).
if [ -e "$RUNTIME_FILE" ]; then
    RUNTIME_FILE="$(cd "$(dirname "$RUNTIME_FILE")" && pwd -P)/$(basename "$RUNTIME_FILE")"
fi
OBJECT="statusline"

die() { echo "error: $*" >&2; exit 2; }

drift_report() { # print drift lines; return 0 = in sync, 1 = drift
    if [ ! -f "$RUNTIME_FILE" ]; then
        echo "runtime-missing: $RUNTIME_FILE"
        return 1
    fi
    if ! cmp -s "$REPO_FILE" "$RUNTIME_FILE"; then
        echo "drift:         $OBJECT (repo != runtime)"
        return 1
    fi
    return 0
}

cmd_status() {
    local report
    if report="$(drift_report)"; then
        echo "in sync: repo and $RUNTIME_FILE"
        return 0
    fi
    echo "$report"
    return 1
}

cmd_push() {
    [ -f "$REPO_FILE" ] || die "repo file not found: $REPO_FILE"
    mkdir -p "$(dirname "$RUNTIME_FILE")"
    cp -p "$REPO_FILE" "$RUNTIME_FILE"
    echo "pushed: $OBJECT -> $RUNTIME_FILE"
}

cmd_pull() {
    local confirmed="${1:-}"
    shift || true
    if [ ! -f "$RUNTIME_FILE" ]; then
        die "runtime file not found: $RUNTIME_FILE (nothing to pull; use push)"
    fi
    if cmp -s "$REPO_FILE" "$RUNTIME_FILE"; then
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

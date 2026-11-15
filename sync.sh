#!/usr/bin/env bash
# sync.sh — синхронизация компонентов статус-лайна между этим репозиторием и
# рантайм-окружением CLI-харнессов макбука:
#   - qoder  : qoder/statusline-command.sh <-> ~/.qoder-cn/statusline-command.sh
#              + секция .statusLine в ~/.qoder-cn/settings.json
#   - claude : claude/statusline.sh <-> ~/.claude/statusline.sh
#              + секция .statusLine в ~/.claude/settings.json
#   - codex  : codex/statusline.toml <-> ключи status_line и
#              status_line_use_colors в секции [tui] файла ~/.codex/config.toml
#
# Использование:
#   ./sync.sh status [qoder|claude|codex ...]
#                      показать дрифт между репо и рантаймом (exit 0 — чисто,
#                      exit 1 — дрифт, exit 2 — ошибка чтения/разбора/сравнения)
#   ./sync.sh push [qoder|claude|codex ...]
#                      репо -> рантайм и привязка в конфиге (репо — источник правды)
#   ./sync.sh pull     предупредить и отказать в записи (contract-first:
#                      править в репо, затем push)
#   ./sync.sh pull --confirmed <qoder|claude|codex ...>
#                      принять копию из рантайма после явного подтверждения
#                      пользователя (классификация предшествует действию)
#
# Безопасность:
#   - Синхронизируются только артефакты компонентов и их целевые ключи в
#     конфигах; файлы харнесса (AGENTS.md, contracts/, analysis/, docs/,
#     .hooks/, sync.sh, harness-check.sh) в рантайм не попадают.
#   - Остальные ключи и секции ~/.qoder-cn/settings.json, ~/.claude/settings.json
#     и ~/.codex/config.toml (включая секреты MCP-серверов) не затрагиваются.
#   - Вызов pull без подтверждения никогда не пишет файлы: он классифицирует
#     дрифт и отказывает, как в родительском харнессе ~/dev/agent-skills.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_OBJECTS="qoder claude codex"

QODER_REPO_FILE="$REPO_DIR/qoder/statusline-command.sh"
QODER_RUNTIME_FILE="${QODER_RUNTIME_FILE:-${STATUSLINE_RUNTIME:-$HOME/.qoder-cn/statusline-command.sh}}"
QODER_SETTINGS_FILE="${QODER_SETTINGS_FILE:-$HOME/.qoder-cn/settings.json}"
QODER_EXPECTED_CMD="${QODER_EXPECTED_CMD:-~/.qoder-cn/statusline-command.sh}"

CLAUDE_REPO_FILE="$REPO_DIR/claude/statusline.sh"
CLAUDE_RUNTIME_FILE="${CLAUDE_RUNTIME_FILE:-$HOME/.claude/statusline.sh}"
CLAUDE_SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$HOME/.claude/settings.json}"
CLAUDE_EXPECTED_CMD="${CLAUDE_EXPECTED_CMD:-STATUSLINE_SAFE_EFFORT=\"medium high xhigh\" bash ~/.claude/statusline.sh}"

CODEX_REPO_FILE="$REPO_DIR/codex/statusline.toml"
CODEX_CONFIG_FILE="${CODEX_CONFIG_FILE:-$HOME/.codex/config.toml}"

TMP_FILES=()
cleanup_tmp() {
    local f
    for f in "${TMP_FILES[@]:-}"; do
        [ -n "$f" ] && rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup_tmp EXIT

die() { echo "error: $*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || die "jq is required but not found in PATH"

# Разрешаем симлинки в пути каталога файла (например, ~/.qoder -> ~/.qoder-cn),
# даже когда целевой файл ещё не создан.
resolve_parent_path() {
    local target="$1" parent
    parent="$(dirname "$target")"
    if [ -d "$parent" ]; then
        local phys_dir
        phys_dir="$(cd "$parent" 2>/dev/null && pwd -P)" || die "cannot resolve directory: $parent"
        printf '%s/%s\n' "$phys_dir" "$(basename "$target")"
    else
        printf '%s\n' "$target"
    fi
}

QODER_RUNTIME_FILE="$(resolve_parent_path "$QODER_RUNTIME_FILE")"
QODER_SETTINGS_FILE="$(resolve_parent_path "$QODER_SETTINGS_FILE")"
CLAUDE_RUNTIME_FILE="$(resolve_parent_path "$CLAUDE_RUNTIME_FILE")"
CLAUDE_SETTINGS_FILE="$(resolve_parent_path "$CLAUDE_SETTINGS_FILE")"
CODEX_CONFIG_FILE="$(resolve_parent_path "$CODEX_CONFIG_FILE")"

# Проверяет и нормализует список компонентов (алиас statusline -> qoder сохраняет
# обратную совместимость со старыми вызовами).
validate_objects() {
    if [ $# -eq 0 ]; then
        printf '%s\n' "$ALL_OBJECTS"
        return 0
    fi
    local arg known found out=""
    for arg in "$@"; do
        [ "$arg" = "statusline" ] && arg="qoder"
        found=0
        for known in $ALL_OBJECTS; do
            if [ "$arg" = "$known" ]; then
                found=1
                break
            fi
        done
        [ "$found" -eq 1 ] || die "'$arg' is not a known component (known: $ALL_OBJECTS)"
        case " $out " in
            *" $arg "*) ;;
            *) out="${out:+$out }$arg" ;;
        esac
    done
    printf '%s\n' "$out"
}

# --- Разбор и валидация TOML-среза [tui] для Codex ---------------------------
# Режим strict=1 (для codex/statusline.toml): допускается только секция [tui]
# и ровно два ключа (status_line, status_line_use_colors); любое отклонение -> exit 2.
# Режим strict=0 (для ~/.codex/config.toml): извлекает те же два ключа из [tui],
# игнорируя прочие секции и ключи; отсутствие [tui] или ключей -> exit 1 (drift),
# синтаксическая ошибка значения или дубликат [tui]/ключей -> exit 2.
extract_codex_tui_json() {
    local file="$1" strict="$2"
    [ -f "$file" ] && [ -r "$file" ] || die "file not readable: $file"
    local awk_out awk_rc=0
    awk_out="$(awk -v strict="$strict" '
        function fail(code) { err = code; exit code }
        function strip_comment(s,    i, c, in_str, esc) {
            in_str = 0; esc = 0
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (in_str) {
                    if (esc) { esc = 0 }
                    else if (c == "\\") { esc = 1 }
                    else if (c == "\"") { in_str = 0 }
                } else {
                    if (c == "\"") { in_str = 1 }
                    else if (c == "#") { return substr(s, 1, i - 1) }
                }
            }
            if (in_str) return "__UNTERMINATED_STRING__"
            return s
        }
        function trim(s) {
            sub(/^[ \t\r]+/, "", s)
            sub(/[ \t\r]+$/, "", s)
            return s
        }
        function bracket_delta(s,    i, c, in_str, esc, d) {
            in_str = 0; esc = 0; d = 0
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (in_str) {
                    if (esc) { esc = 0 }
                    else if (c == "\\") { esc = 1 }
                    else if (c == "\"") { in_str = 0 }
                } else {
                    if (c == "\"") { in_str = 1 }
                    else if (c == "[") { d++ }
                    else if (c == "]") { d-- }
                }
            }
            return d
        }
        BEGIN {
            err = 0
            sec = ""
            tui_seen = 0
            sl_seen = 0
            col_seen = 0
            in_array = 0
            in_other_array = 0
            sl_val = ""
            col_val = ""
            depth = 0
            other_depth = 0
        }
        {
            raw = strip_comment($0)
            if (raw == "__UNTERMINATED_STRING__") {
                if (strict || sec == "tui" || in_array || in_other_array) { fail(2) }
                next
            }
            line = trim(raw)
            if (line == "") next

            if (in_array) {
                sl_val = sl_val " " line
                depth += bracket_delta(line)
                if (depth < 0) fail(2)
                if (depth == 0) in_array = 0
                next
            }

            if (in_other_array) {
                other_depth += bracket_delta(line)
                if (other_depth < 0) fail(2)
                if (other_depth == 0) in_other_array = 0
                next
            }

            if (line ~ /^\[/) {
                if (line !~ /^\[[^[\]]+\]$/) {
                    if (strict) fail(2)
                    sec = "other"
                    next
                }
                sec = trim(substr(line, 2, length(line) - 2))
                if (sec == "tui") {
                    tui_seen++
                    if (tui_seen > 1) fail(2)
                } else if (strict) {
                    fail(2)
                }
                next
            }

            if (sec != "tui") {
                if (strict) fail(2)
                eq = index(line, "=")
                if (eq > 0) {
                    v = trim(substr(line, eq + 1))
                    other_depth = bracket_delta(v)
                    if (other_depth > 0) in_other_array = 1
                }
                next
            }

            eq = index(line, "=")
            if (eq == 0) fail(2)
            k = trim(substr(line, 1, eq - 1))
            v = trim(substr(line, eq + 1))
            if (k == "" || v == "") fail(2)

            if (k == "status_line") {
                sl_seen++
                if (sl_seen > 1) fail(2)
                sl_val = v
                depth = bracket_delta(v)
                if (depth < 0) fail(2)
                if (depth > 0) in_array = 1
            } else if (k == "status_line_use_colors") {
                col_seen++
                if (col_seen > 1) fail(2)
                col_val = v
            } else if (strict) {
                fail(2)
            } else {
                other_depth = bracket_delta(v)
                if (other_depth < 0) fail(2)
                if (other_depth > 0) in_other_array = 1
            }
        }
        END {
            if (err != 0) exit err
            if (in_array || in_other_array) exit 2
            if (tui_seen == 0 || sl_seen == 0 || col_seen == 0) {
                exit (strict ? 2 : 1)
            }
            sub(/,[ \t]*\]$/, "]", sl_val)
            print sl_val
            print col_val
        }
    ' "$file")" || awk_rc=$?

    if [ "$awk_rc" -eq 1 ]; then
        return 1
    elif [ "$awk_rc" -ne 0 ]; then
        die "invalid [tui] TOML structure in $file"
    fi

    local raw_sl raw_col
    {
        IFS= read -r raw_sl
        IFS= read -r raw_col
    } <<EOF
$awk_out
EOF

    local parsed_json jq_rc=0
    parsed_json="$(jq -cn --arg sl "$raw_sl" --arg col "$raw_col" '
        ($sl | fromjson) as $s |
        ($col | fromjson) as $c |
        {status_line: $s, status_line_use_colors: $c}
    ' 2>/dev/null)" || jq_rc=$?
    if [ "$jq_rc" -ne 0 ] || [ -z "$parsed_json" ]; then
        die "malformed TOML value for status_line or status_line_use_colors in $file"
    fi

    local valid_rc=0
    jq -e '
        (.status_line | type == "array" and length > 0 and all(.[]; (type == "string") and (length > 0)))
        and (.status_line_use_colors | type == "boolean")
    ' >/dev/null 2>&1 <<<"$parsed_json" || valid_rc=$?
    if [ "$valid_rc" -ne 0 ]; then
        if [ "$strict" -eq 1 ]; then
            die "invalid schema for status_line or status_line_use_colors in $file"
        fi
        return 1
    fi

    printf '%s\n' "$parsed_json"
    return 0
}

# Проверка секции .statusLine в JSON-файле настроек (0 = ок, 1 = дрифт, 2 = ошибка)
check_settings_binding() {
    local obj="$1" settings_file="$2" expected_cmd="$3"
    if [ ! -e "$settings_file" ] && [ ! -L "$settings_file" ]; then
        echo "settings-missing: $obj ($settings_file)"
        return 1
    fi
    [ -f "$settings_file" ] && [ -r "$settings_file" ] || die "settings file not readable: $settings_file"
    jq -e 'type == "object"' "$settings_file" >/dev/null 2>&1 || die "settings file is not a valid JSON object: $settings_file"
    if ! jq -e --arg cmd "$expected_cmd" '.statusLine == {type: "command", command: $cmd}' "$settings_file" >/dev/null 2>&1; then
        echo "settings-drift:  $obj ($settings_file .statusLine)"
        return 1
    fi
    return 0
}

# Атомарное копирование скрипта в рантайм через mktemp + mv
deploy_runtime_script() {
    local src="$1" dst="$2" tmp_file
    mkdir -p "$(dirname "$dst")"
    tmp_file="$(mktemp "${dst}.tmp.XXXXXX")" || die "mktemp failed in $(dirname "$dst")"
    TMP_FILES+=("$tmp_file")
    cp -p "$src" "$tmp_file"
    chmod +x "$tmp_file"
    mv "$tmp_file" "$dst"
}

# Обновление .statusLine в settings.json (пишет только при расхождении)
push_settings_binding() {
    local obj="$1" settings_file="$2" expected_cmd="$3"
    mkdir -p "$(dirname "$settings_file")"
    if [ -e "$settings_file" ] || [ -L "$settings_file" ]; then
        [ -f "$settings_file" ] && [ -r "$settings_file" ] || die "settings file not readable: $settings_file"
        jq -e 'type == "object"' "$settings_file" >/dev/null 2>&1 || die "settings file is not a valid JSON object: $settings_file"
        if jq -e --arg cmd "$expected_cmd" '.statusLine == {type: "command", command: $cmd}' "$settings_file" >/dev/null 2>&1; then
            return 0
        fi
        local tmp_file
        tmp_file="$(mktemp "${settings_file}.tmp.XXXXXX")" || die "mktemp failed in $(dirname "$settings_file")"
        TMP_FILES+=("$tmp_file")
        cp -p "$settings_file" "$tmp_file" 2>/dev/null || true
        if ! jq --arg cmd "$expected_cmd" '.statusLine = {type: "command", command: $cmd}' "$settings_file" > "$tmp_file"; then
            rm -f "$tmp_file"
            die "failed to update .statusLine in $settings_file"
        fi
        mv "$tmp_file" "$settings_file"
    else
        local tmp_file
        tmp_file="$(mktemp "${settings_file}.tmp.XXXXXX")" || die "mktemp failed in $(dirname "$settings_file")"
        TMP_FILES+=("$tmp_file")
        jq -n --arg cmd "$expected_cmd" '{statusLine: {type: "command", command: $cmd}}' > "$tmp_file"
        mv "$tmp_file" "$settings_file"
    fi
    echo "wired:  $obj -> $settings_file (.statusLine)"
}

# Проверка скрипта и его привязки для qoder / claude
check_script_component() {
    local obj="$1" repo_file="$2" runtime_file="$3" settings_file="$4" expected_cmd="$5"
    local drifted=0 s_rc=0
    [ -f "$repo_file" ] && [ -r "$repo_file" ] || die "repo file not readable: $repo_file"
    if [ ! -e "$runtime_file" ] && [ ! -L "$runtime_file" ]; then
        echo "runtime-missing: $obj ($runtime_file)"
        drifted=1
    else
        [ -f "$runtime_file" ] && [ -r "$runtime_file" ] || die "runtime file not readable: $runtime_file"
        local cmp_rc=0
        cmp -s "$repo_file" "$runtime_file" || cmp_rc=$?
        if [ "$cmp_rc" -gt 1 ]; then
            die "cmp failed for $repo_file and $runtime_file (exit $cmp_rc)"
        fi
        if [ "$cmp_rc" -eq 1 ]; then
            echo "drift:           $obj (repo != runtime: $runtime_file)"
            drifted=1
        fi
    fi
    check_settings_binding "$obj" "$settings_file" "$expected_cmd" || s_rc=$?
    if [ "$s_rc" -gt 1 ]; then
        exit "$s_rc"
    elif [ "$s_rc" -eq 1 ]; then
        drifted=1
    fi
    return "$drifted"
}

# Проверка среза [tui] для codex
check_codex_component() {
    local repo_json runtime_json rc=0
    repo_json="$(extract_codex_tui_json "$CODEX_REPO_FILE" 1)" || exit $?
    if [ ! -e "$CODEX_CONFIG_FILE" ] && [ ! -L "$CODEX_CONFIG_FILE" ]; then
        echo "runtime-missing: codex ($CODEX_CONFIG_FILE)"
        return 1
    fi
    runtime_json="$(extract_codex_tui_json "$CODEX_CONFIG_FILE" 0)" || rc=$?
    if [ "$rc" -eq 1 ]; then
        echo "drift:           codex ($CODEX_CONFIG_FILE [tui] status_line slice missing or invalid)"
        return 1
    elif [ "$rc" -ne 0 ]; then
        exit "$rc"
    fi
    if [ "$repo_json" != "$runtime_json" ]; then
        echo "drift:           codex (repo != $CODEX_CONFIG_FILE [tui])"
        return 1
    fi
    return 0
}

drift_report_for() {
    local obj="$1"
    case "$obj" in
        qoder)
            check_script_component "qoder" "$QODER_REPO_FILE" "$QODER_RUNTIME_FILE" "$QODER_SETTINGS_FILE" "$QODER_EXPECTED_CMD"
            ;;
        claude)
            check_script_component "claude" "$CLAUDE_REPO_FILE" "$CLAUDE_RUNTIME_FILE" "$CLAUDE_SETTINGS_FILE" "$CLAUDE_EXPECTED_CMD"
            ;;
        codex)
            check_codex_component
            ;;
    esac
}

cmd_status() {
    local targets obj drifted=0 rc=0 out
    targets="$(validate_objects "$@")" || exit $?
    for obj in $targets; do
        rc=0
        out="$(drift_report_for "$obj")" || rc=$?
        if [ "$rc" -gt 1 ]; then
            [ -z "$out" ] || echo "$out"
            exit "$rc"
        elif [ "$rc" -eq 1 ]; then
            [ -z "$out" ] || echo "$out"
            drifted=1
        fi
    done
    if [ "$drifted" -eq 0 ]; then
        echo "in sync: $targets"
        return 0
    fi
    return 1
}

push_codex_component() {
    local repo_json sl_line col_line
    repo_json="$(extract_codex_tui_json "$CODEX_REPO_FILE" 1)" || exit $?
    sl_line="status_line = $(jq -r '.status_line | "[" + (map(@json) | join(", ")) + "]"' <<<"$repo_json")"
    col_line="status_line_use_colors = $(jq -r '.status_line_use_colors | tostring' <<<"$repo_json")"

    mkdir -p "$(dirname "$CODEX_CONFIG_FILE")"
    if [ ! -e "$CODEX_CONFIG_FILE" ] && [ ! -L "$CODEX_CONFIG_FILE" ]; then
        local tmp_new
        tmp_new="$(mktemp "${CODEX_CONFIG_FILE}.tmp.XXXXXX")" || die "mktemp failed in $(dirname "$CODEX_CONFIG_FILE")"
        TMP_FILES+=("$tmp_new")
        printf '[tui]\n%s\n%s\n' "$sl_line" "$col_line" > "$tmp_new"
        mv "$tmp_new" "$CODEX_CONFIG_FILE"
        echo "pushed: codex -> $CODEX_CONFIG_FILE ([tui])"
        return 0
    fi
    [ -f "$CODEX_CONFIG_FILE" ] && [ -r "$CODEX_CONFIG_FILE" ] || die "config file not readable: $CODEX_CONFIG_FILE"

    local runtime_json="" rc=0
    runtime_json="$(extract_codex_tui_json "$CODEX_CONFIG_FILE" 0)" || rc=$?
    if [ "$rc" -gt 1 ]; then
        exit "$rc"
    fi
    if [ "$rc" -eq 0 ] && [ "$repo_json" = "$runtime_json" ]; then
        echo "pushed: codex -> $CODEX_CONFIG_FILE ([tui] already in sync)"
        return 0
    fi

    local tmp_file
    tmp_file="$(mktemp "${CODEX_CONFIG_FILE}.tmp.XXXXXX")" || die "mktemp failed in $(dirname "$CODEX_CONFIG_FILE")"
    TMP_FILES+=("$tmp_file")
    cp -p "$CODEX_CONFIG_FILE" "$tmp_file" 2>/dev/null || true

    if ! awk -v sl_line="$sl_line" -v col_line="$col_line" '
        function strip_comment(s,    i, c, in_str, esc) {
            in_str = 0; esc = 0
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (in_str) {
                    if (esc) { esc = 0 }
                    else if (c == "\\") { esc = 1 }
                    else if (c == "\"") { in_str = 0 }
                } else {
                    if (c == "\"") { in_str = 1 }
                    else if (c == "#") { return substr(s, 1, i - 1) }
                }
            }
            return s
        }
        function trim(s) {
            sub(/^[ \t\r]+/, "", s)
            sub(/[ \t\r]+$/, "", s)
            return s
        }
        function bracket_delta(s,    i, c, in_str, esc, d) {
            in_str = 0; esc = 0; d = 0
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (in_str) {
                    if (esc) { esc = 0 }
                    else if (c == "\\") { esc = 1 }
                    else if (c == "\"") { in_str = 0 }
                } else {
                    if (c == "\"") { in_str = 1 }
                    else if (c == "[") { d++ }
                    else if (c == "]") { d-- }
                }
            }
            return d
        }
        function flush_missing() {
            if (!sl_done) { print sl_line; sl_done = 1 }
            if (!col_done) { print col_line; col_done = 1 }
        }
        function flush_blanks(    i) {
            for (i = 1; i <= n_blanks; i++) print blanks[i]
            n_blanks = 0
        }
        BEGIN {
            sec = ""; tui_found = 0; sl_done = 0; col_done = 0
            skip_array = 0; skip_other_array = 0; depth = 0; other_depth = 0; n_blanks = 0
        }
        {
            raw = strip_comment($0)
            line = trim(raw)

            if (skip_array) {
                depth += bracket_delta(raw)
                if (depth <= 0) { skip_array = 0; depth = 0 }
                next
            }

            if (skip_other_array) {
                other_depth += bracket_delta(raw)
                if (other_depth <= 0) { skip_other_array = 0; other_depth = 0 }
                print $0
                next
            }

            if (sec == "tui" && line == "") {
                blanks[++n_blanks] = $0
                next
            }

            if (line ~ /^\[/) {
                if (sec == "tui") {
                    flush_missing()
                    flush_blanks()
                }
                s_name = ""
                if (line ~ /^\[[^[\]]+\]$/) {
                    s_name = trim(substr(line, 2, length(line) - 2))
                }
                if (s_name == "tui" && !tui_found) {
                    sec = "tui"
                    tui_found = 1
                } else {
                    sec = "other"
                }
                print $0
                next
            }

            if (sec == "tui") {
                flush_blanks()
                eq = index(line, "=")
                if (eq > 0) {
                    k = trim(substr(line, 1, eq - 1))
                    v = trim(substr(line, eq + 1))
                    if (k == "status_line") {
                        if (!sl_done) { print sl_line; sl_done = 1 }
                        depth = bracket_delta(v)
                        if (depth > 0) skip_array = 1
                        next
                    }
                    if (k == "status_line_use_colors") {
                        if (!col_done) { print col_line; col_done = 1 }
                        next
                    }
                    other_depth = bracket_delta(v)
                    if (other_depth > 0) skip_other_array = 1
                }
            } else {
                eq = index(line, "=")
                if (eq > 0) {
                    v = trim(substr(line, eq + 1))
                    other_depth = bracket_delta(v)
                    if (other_depth > 0) skip_other_array = 1
                }
            }
            print $0
        }
        END {
            if (sec == "tui") {
                flush_missing()
                flush_blanks()
            } else if (!tui_found) {
                if (NR > 0) print ""
                print "[tui]"
                print sl_line
                print col_line
            }
        }
    ' "$CODEX_CONFIG_FILE" > "$tmp_file"; then
        rm -f "$tmp_file"
        die "failed to update [tui] slice in $CODEX_CONFIG_FILE"
    fi

    mv "$tmp_file" "$CODEX_CONFIG_FILE"
    echo "pushed: codex -> $CODEX_CONFIG_FILE ([tui])"
}

cmd_push() {
    local targets obj
    targets="$(validate_objects "$@")" || exit $?
    for obj in $targets; do
        case "$obj" in
            qoder)
                [ -f "$QODER_REPO_FILE" ] && [ -r "$QODER_REPO_FILE" ] || die "repo file not found or not readable: $QODER_REPO_FILE"
                deploy_runtime_script "$QODER_REPO_FILE" "$QODER_RUNTIME_FILE"
                echo "pushed: qoder -> $QODER_RUNTIME_FILE"
                push_settings_binding "qoder" "$QODER_SETTINGS_FILE" "$QODER_EXPECTED_CMD"
                ;;
            claude)
                [ -f "$CLAUDE_REPO_FILE" ] && [ -r "$CLAUDE_REPO_FILE" ] || die "repo file not found or not readable: $CLAUDE_REPO_FILE"
                deploy_runtime_script "$CLAUDE_REPO_FILE" "$CLAUDE_RUNTIME_FILE"
                echo "pushed: claude -> $CLAUDE_RUNTIME_FILE"
                push_settings_binding "claude" "$CLAUDE_SETTINGS_FILE" "$CLAUDE_EXPECTED_CMD"
                ;;
            codex)
                push_codex_component
                ;;
        esac
    done
}

# Проверяет состояние компонента для pull:
#   0 = рантайм и привязка совпадают с репо
#   1 = рантайм-артефакт отличается от репо и может быть принят через pull
#   3 = скрипт совпадает с репо, отличается только привязка .statusLine в settings.json (-> push)
#   4 = рантайм-артефакт (или срез [tui]) отсутствует (-> push для инициализации)
pull_candidate_state() {
    local obj="$1" repo_file runtime_file settings_file expected_cmd
    case "$obj" in
        qoder|claude)
            if [ "$obj" = "qoder" ]; then
                repo_file="$QODER_REPO_FILE"
                runtime_file="$QODER_RUNTIME_FILE"
                settings_file="$QODER_SETTINGS_FILE"
                expected_cmd="$QODER_EXPECTED_CMD"
            else
                repo_file="$CLAUDE_REPO_FILE"
                runtime_file="$CLAUDE_RUNTIME_FILE"
                settings_file="$CLAUDE_SETTINGS_FILE"
                expected_cmd="$CLAUDE_EXPECTED_CMD"
            fi
            [ -f "$repo_file" ] && [ -r "$repo_file" ] || die "repo file not found or not readable: $repo_file"
            if [ ! -e "$runtime_file" ] && [ ! -L "$runtime_file" ]; then
                return 4
            fi
            [ -f "$runtime_file" ] && [ -r "$runtime_file" ] || die "runtime file not readable: $runtime_file"
            local cmp_rc=0
            cmp -s "$repo_file" "$runtime_file" || cmp_rc=$?
            if [ "$cmp_rc" -gt 1 ]; then
                die "cmp failed for $repo_file and $runtime_file (exit $cmp_rc)"
            fi
            if [ "$cmp_rc" -eq 1 ]; then
                return 1
            fi
            local s_rc=0
            check_settings_binding "$obj" "$settings_file" "$expected_cmd" >/dev/null || s_rc=$?
            if [ "$s_rc" -gt 1 ]; then
                exit "$s_rc"
            elif [ "$s_rc" -eq 1 ]; then
                return 3
            fi
            return 0
            ;;
        codex)
            local repo_json runtime_json rc=0
            repo_json="$(extract_codex_tui_json "$CODEX_REPO_FILE" 1)" || exit $?
            if [ ! -e "$CODEX_CONFIG_FILE" ] && [ ! -L "$CODEX_CONFIG_FILE" ]; then
                return 4
            fi
            runtime_json="$(extract_codex_tui_json "$CODEX_CONFIG_FILE" 0)" || rc=$?
            if [ "$rc" -eq 1 ]; then
                return 4
            elif [ "$rc" -ne 0 ]; then
                exit "$rc"
            fi
            if [ "$repo_json" != "$runtime_json" ]; then
                return 1
            fi
            return 0
            ;;
    esac
}

cmd_pull() {
    local confirmed="${1:-}" selected=""
    if [ "$confirmed" = "--confirmed" ]; then
        shift || true
        if [ $# -eq 0 ]; then
            die "--confirmed needs an explicit component selection ($ALL_OBJECTS); bare --confirmed refused"
        fi
        selected="$(validate_objects "$@")" || exit $?
    elif [ -n "$confirmed" ]; then
        validate_objects "$@" >/dev/null || exit $?
    fi

    # Классифицируем состояние всех компонентов
    local obj state pending_pull="" settings_only="" missing_runtime=""
    for obj in $ALL_OBJECTS; do
        state=0
        pull_candidate_state "$obj" || state=$?
        if [ "$state" -eq 1 ]; then
            pending_pull="${pending_pull:+$pending_pull }$obj"
        elif [ "$state" -eq 3 ]; then
            settings_only="${settings_only:+$settings_only }$obj"
        elif [ "$state" -eq 4 ]; then
            missing_runtime="${missing_runtime:+$missing_runtime }$obj"
        elif [ "$state" -ne 0 ]; then
            exit "$state"
        fi
    done

    if [ "$confirmed" = "--confirmed" ]; then
        for obj in $selected; do
            case " $pending_pull " in
                *" $obj "*) ;;
                *)
                    case " $missing_runtime " in
                        *" $obj "*)
                            die "runtime artifact not found for '$obj' (nothing to pull; use './sync.sh push $obj')"
                            ;;
                    esac
                    case " $settings_only " in
                        *" $obj "*)
                            die "'$obj' script matches repo; only settings.json binding drifted (use './sync.sh push $obj')"
                            ;;
                    esac
                    die "'$obj' has no runtime drift to pull${pending_pull:+ (pending: $pending_pull)}"
                    ;;
            esac
        done
    else
        if [ -n "$pending_pull" ]; then
            {
                echo "warning: pull overwrites repo artifacts with runtime copies."
                echo "The repo is the source of truth (contract-first): edit in"
                echo "the repo and push. Pull bypasses the contract cycle."
                echo ""
                echo "runtime differs from repo for: $pending_pull"
                echo ""
                echo "Review the drift (./sync.sh status; diff the files). If the"
                echo "runtime edit is intentional and user-approved, re-run with an"
                echo "explicit selection:"
                echo "  ./sync.sh pull --confirmed $pending_pull"
            } >&2
            exit 1
        fi
        if [ -n "$missing_runtime" ] || [ -n "$settings_only" ]; then
            [ -z "$missing_runtime" ] || echo "error: runtime artifact missing for: $missing_runtime (run './sync.sh push $missing_runtime' to initialize)" >&2
            [ -z "$settings_only" ] || echo "error: runtime scripts match repo, but settings.json binding drifted for: $settings_only (run './sync.sh push $settings_only' to restore binding)" >&2
            exit 1
        fi
        echo "nothing to pull: runtime matches repo."
        return 0
    fi

    for obj in $selected; do
        case "$obj" in
            qoder)
                cp -p "$QODER_RUNTIME_FILE" "$QODER_REPO_FILE"
                echo "pulled: qoder <- $QODER_RUNTIME_FILE"
                ;;
            claude)
                cp -p "$CLAUDE_RUNTIME_FILE" "$CLAUDE_REPO_FILE"
                echo "pulled: claude <- $CLAUDE_RUNTIME_FILE"
                ;;
            codex)
                local runtime_json sl_line col_line
                runtime_json="$(extract_codex_tui_json "$CODEX_CONFIG_FILE" 0)" || die "failed to read [tui] slice from $CODEX_CONFIG_FILE"
                sl_line="status_line = $(jq -r '.status_line | "[" + (map(@json) | join(", ")) + "]"' <<<"$runtime_json")"
                col_line="status_line_use_colors = $(jq -r '.status_line_use_colors | tostring' <<<"$runtime_json")"
                {
                    echo "# Codex CLI TUI status line slice (synced into ~/.codex/config.toml under [tui])."
                    echo "[tui]"
                    echo "$sl_line"
                    echo "$col_line"
                } > "$CODEX_REPO_FILE"
                echo "pulled: codex <- $CODEX_CONFIG_FILE ([tui])"
                ;;
        esac
    done
}

case "${1:-}" in
    status) shift; cmd_status "$@" ;;
    push)   shift; cmd_push "$@" ;;
    pull)   shift; cmd_pull "$@" ;;
    *)      die "usage: $0 {status [component...]|push [component...]|pull [--confirmed component...]}" ;;
esac

#!/bin/sh
# Qoder CLI status line.
# Renders one compact line:  ❯ model 400k | ctx 11% | AG 2 | +12/-3 | branch | ~/dev/tgwizard
# AG = number of live subagents (only shown while > 0): the max of two
# sources — Agent tool_use calls without a tool_result yet in the session
# transcript, and non-terminal subagents/task-*.json registry entries (the
# transcript misses background agents, whose tool_result is written at launch).
# Window size (compact 4k/400k/1M) follows the model name; ctx shows USED
# percentage (fills up as context is consumed).
# Diff segment = git working-tree stats (tracked + untracked), not session counters.
# Branch is bright-magenta when not main; commit-less repos show a yellow
# "no commits"; outside any repo shouts NO GIT! in bold red.
# Reads session JSON from stdin.

input=$(cat)

# Parse all fields in one jq invocation; newline-joined so empty fields
# survive (tab-splitting would collapse empty values).
parsed=$(printf '%s' "$input" | jq -r '
  [
    (.model.display_name // .model.id // ""),
    (if (.context_window.context_window_size? // null) != null
       then (if .context_window.context_window_size >= 1000000
             then "\((.context_window.context_window_size / 1000000 * 10 | round) / 10 | tostring | sub("\\.0$"; ""))M"
             else "\(.context_window.context_window_size / 1000 | round)k" end)
     else "" end),
    (if (.context_window.used_percentage? // null) != null
       then (.context_window.used_percentage | round | tostring)
     elif (.context_window.remaining_percentage? // null) != null
       then ((100 - .context_window.remaining_percentage) | round | tostring)
     else "" end),
    (.workspace.current_dir // ""),
    (.transcript_path // "")
  ] | join("\n")
' 2>/dev/null)

model=""; window=""; ctx=""; dir=""; transcript=""
if [ -n "$parsed" ]; then
  {
    IFS= read -r model
    IFS= read -r window
    IFS= read -r ctx
    IFS= read -r dir
    IFS= read -r transcript
  } <<EOF
$parsed
EOF
fi
[ -z "$dir" ] && dir=$(pwd)

added=0; removed=0; branch=""; nogit=""; nocommits=""
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_added=$(
    {
      git -C "$dir" diff HEAD --numstat 2>/dev/null
      # Untracked files: diff them against /dev/null as pure additions,
      # batched into as few git invocations as ARG_MAX allows
      git -C "$dir" ls-files --others --exclude-standard -z 2>/dev/null |
        xargs -0 git -C "$dir" diff --no-index --numstat -- /dev/null 2>/dev/null
    } | awk '{ a += $1; r += $2 } END { printf "%d %d", a + 0, r + 0 }'
  )
  added=${git_added%% *}
  removed=${git_added##* }
  # Commit-less repos: HEAD does not resolve, so diff/branch output above
  # came back empty; flag it instead of silently dropping the segment
  if ! git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1; then
    nocommits=1
  fi
else
  nogit=1
fi

# Shorten $HOME prefix to ~
case "$dir" in
  "$HOME") dir="~" ;;
  "$HOME"/*) dir="~${dir#"$HOME"}" ;;
esac

# Active subagents = Agent tool_use entries without a matching tool_result.
# Stateful per-transcript cache: byte offset already parsed + currently open
# tool_use ids. Each refresh parses only newly appended complete lines, so the
# count is exact for any transcript size and the cost is proportional to the
# new tail. The first refresh parses the whole file. A line without a trailing
# newline may still be written, so it is left for the next pass; fromjson?
# skips any malformed line. Cache invalidates on file truncation/rotation.
agents=0
if [ -n "$transcript" ] && [ -r "$transcript" ]; then
  cache_dir="${TMPDIR:-/tmp}/qoder-statusline-ag"
  mkdir -p "$cache_dir" 2>/dev/null && chmod 700 "$cache_dir" 2>/dev/null
  cache="$cache_dir/$(printf '%s' "$transcript" | cksum | awk '{print $1}').cache"
  size=$(wc -c < "$transcript" 2>/dev/null | tr -d ' ')
  case "$size" in ''|*[!0-9]*) size=0 ;; esac

  offset=0; open_ids=""
  if [ -s "$cache" ]; then
    cached_offset=$(head -n 1 "$cache" 2>/dev/null)
    case "$cached_offset" in ''|*[!0-9]*) cached_offset="" ;; esac
    if [ -n "$cached_offset" ] && [ "$cached_offset" -le "$size" ] 2>/dev/null; then
      offset=$cached_offset
      open_ids=$(tail -n +2 "$cache" 2>/dev/null)
    fi
  fi

  chunk="$cache_dir/chunk.$$"; res_f="$cache_dir/res.$$"; open_f="$cache_dir/open.$$"
  if [ "$offset" -eq 0 ]; then
    cat "$transcript" > "$chunk" 2>/dev/null
  else
    tail -c +$((offset + 1)) "$transcript" > "$chunk" 2>/dev/null
  fi
  chunk_size=$(wc -c < "$chunk" 2>/dev/null | tr -d ' ')
  case "$chunk_size" in ''|*[!0-9]*) chunk_size=0 ;; esac
  complete=$chunk_size
  if [ -n "$(tail -c 1 "$chunk" 2>/dev/null)" ]; then
    partial=$(tail -n 1 "$chunk" 2>/dev/null | wc -c | tr -d ' ')
    case "$partial" in ''|*[!0-9]*) partial=0 ;; esac
    complete=$((chunk_size - partial))
  fi

  events=$(head -c "$complete" "$chunk" 2>/dev/null |
    jq -R 'fromjson?' 2>/dev/null |
    jq -r '
      if .type == "assistant" then
        (.message.content[]? | select(.type=="tool_use" and .name=="Agent")
         | "U " + (.id // ""))
      elif .type == "user" then
        (.message.content[]? | select(.type=="tool_result")
         | "R " + (.tool_use_id // ""))
      else empty end
    ' 2>/dev/null)

  printf '%s\n' "$events" | awk '$1=="R" && $2!="" {print $2}' | sort -u > "$res_f"
  { printf '%s\n' "$open_ids"
    printf '%s\n' "$events" | awk '$1=="U" && $2!="" {print $2}'
  } | awk 'NF' | sort -u | comm -23 - "$res_f" > "$open_f"

  agents=$(wc -l < "$open_f" 2>/dev/null | tr -d ' ')
  case "$agents" in ''|*[!0-9]*) agents=0 ;; esac

  { printf '%s\n' "$((offset + complete))"; cat "$open_f" 2>/dev/null; } > "$cache" 2>/dev/null
  rm -f "$chunk" "$res_f" "$open_f" 2>/dev/null

  # Second source: subagents/task-*.json registry files carry a live status
  # for every agent, including background ones (whose tool_result arrives at
  # launch, invisible to the pair count above). Combine with max, not sum:
  # a foreground agent is visible to both sources at once.
  session_dir="${transcript%.jsonl}"
  if [ -d "$session_dir/subagents" ]; then
    # Per-file slurp: one corrupt or mid-write registry file must not hide
    # the remaining agents (a batched parse aborts the whole batch)
    reg=$(find "$session_dir/subagents" -name 'task-*.json' -exec jq -Rs '
      fromjson?
      | select(type == "object")
      | select(.status as $s
               | (["completed","cancelled","canceled","failed","stopped"]
                  | index($s)) | not)
      | .taskId // .agentId // "x"
    ' {} \; 2>/dev/null | wc -l | tr -d ' ')
    case "$reg" in ''|*[!0-9]*) reg=0 ;; esac
    [ "$reg" -gt "$agents" ] 2>/dev/null && agents=$reg
  fi
fi

# Colors are stored as real ESC bytes (not \033 literals) so the final
# printf '%s' is byte-exact and can never reinterpret segment content
C_MODEL=$(printf '\033[36m')   # cyan
C_DIR=$(printf '\033[34m')     # blue
C_ADD=$(printf '\033[32m')     # green
C_REM=$(printf '\033[31m')     # red
C_BRANCH=$(printf '\033[95m')  # bright magenta: non-main branch alert
C_NOGIT=$(printf '\033[1;31m') # bold red: not a git repo
C_WARN=$(printf '\033[33m')    # yellow: commit-less repo
C_SEP=$(printf '\033[90m')     # gray separator
C_AGENTS=$(printf '\033[33m')  # yellow: live subagents
C_RST=$(printf '\033[0m')
if [ -n "$ctx" ]; then
  # ctx = used percentage: green while low, yellow past 50%, red near full
  if [ "$ctx" -le 50 ] 2>/dev/null; then C_CTX=$(printf '\033[32m')
  elif [ "$ctx" -le 80 ] 2>/dev/null; then C_CTX=$(printf '\033[33m')
  else C_CTX=$(printf '\033[31m'); fi
else
  C_CTX=""
fi

sep="${C_SEP} | ${C_RST}"

seg_model=""
seg_ctx=""
seg_agents=""
seg_diff=""
seg_branch=""
seg_dir="${C_DIR}${dir}${C_RST}"
if [ -n "$model" ]; then
  seg_model="${C_MODEL}${model}${C_RST}"
  [ -n "$window" ] && seg_model="$seg_model ${window}${C_RST}"
fi
[ -n "$ctx" ] && seg_ctx="${C_CTX}ctx ${ctx}%${C_RST}"
# Show live subagent count only while some are actually running
if [ "$agents" -gt 0 ] 2>/dev/null; then
  seg_agents="${C_AGENTS}AG ${agents}${C_RST}"
fi
# Hide diff stats when the working tree is clean
if [ "$added" != "0" ] || [ "$removed" != "0" ]; then
  seg_diff="${C_ADD}+${added}${C_SEP}/${C_RST}${C_REM}-${removed}${C_RST}"
fi
if [ -n "$nocommits" ]; then
  # Takes precedence: on unborn branches rev-parse --abbrev-ref HEAD prints
  # the literal string HEAD, which must not masquerade as a branch name
  seg_branch="${C_WARN}no commits${C_RST}"
elif [ -n "$branch" ]; then
  if [ "$branch" = "main" ]; then
    seg_branch="${C_MODEL}${branch}${C_RST}"
  else
    seg_branch="${C_BRANCH}${branch}${C_RST}"
  fi
elif [ -n "$nogit" ]; then
  seg_branch="${C_NOGIT}NO GIT!${C_RST}"
fi

# '❯' (chevron) keeps the model name off the terminal's left edge; the first
# segment follows after a plain space, segments are joined by the gray separator
out="${C_SEP}❯${C_RST}"
glue=" "
for seg in "$seg_model" "$seg_ctx" "$seg_agents" "$seg_diff" "$seg_branch" "$seg_dir"; do
  [ -z "$seg" ] && continue
  out="$out$glue$seg"
  glue="$sep"
done

printf '%s' "$out"

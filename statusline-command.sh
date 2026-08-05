#!/bin/sh
# Qoder CLI status line.
# Renders one compact line:  model 400k | ctx 11% | +12/-3 | branch | ~/dev/tgwizard
# Window size (compact 4k/400k/1M) follows the model name; ctx shows USED
# percentage (fills up as context is consumed).
# Diff segment = git working-tree stats (tracked + untracked), not session counters.
# Branch is bright-magenta when not main; outside any repo shouts NO GIT! in bold red.
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
    (.workspace.current_dir // "")
  ] | join("\n")
' 2>/dev/null)

model=""; window=""; ctx=""; dir=""
if [ -n "$parsed" ]; then
  {
    IFS= read -r model
    IFS= read -r window
    IFS= read -r ctx
    IFS= read -r dir
  } <<EOF
$parsed
EOF
fi
[ -z "$dir" ] && dir=$(pwd)

added=0; removed=0; branch=""; nogit=""
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_added=$(
    {
      git -C "$dir" diff HEAD --numstat 2>/dev/null
      # Untracked files: diff them against /dev/null as pure additions
      git -C "$dir" ls-files --others --exclude-standard -z 2>/dev/null |
        xargs -0 -I{} git -C "$dir" diff --no-index --numstat -- /dev/null "{}" 2>/dev/null
    } | awk '{ a += $1; r += $2 } END { printf "%d %d", a + 0, r + 0 }'
  )
  added=${git_added%% *}
  removed=${git_added##* }
else
  nogit=1
fi

# Shorten $HOME prefix to ~
case "$dir" in
  "$HOME") dir="~" ;;
  "$HOME"/*) dir="~${dir#"$HOME"}" ;;
esac

# Colors (terminal renders the status line dimmed anyway)
C_MODEL='\033[36m'  # cyan
C_DIR='\033[34m'    # blue
C_ADD='\033[32m'    # green
C_REM='\033[31m'    # red
C_BRANCH='\033[95m' # bright magenta: non-main branch alert
C_NOGIT='\033[1;31m' # bold red: not a git repo
C_SEP='\033[90m'    # gray separator
C_RST='\033[0m'
if [ -n "$ctx" ]; then
  # ctx = used percentage: green while low, yellow past 50%, red near full
  if [ "$ctx" -le 50 ] 2>/dev/null; then C_CTX='\033[32m'
  elif [ "$ctx" -le 80 ] 2>/dev/null; then C_CTX='\033[33m'
  else C_CTX='\033[31m'; fi
else
  C_CTX=""
fi

sep="${C_SEP} | ${C_RST}"

seg_model=""
seg_ctx=""
seg_diff=""
seg_branch=""
seg_dir="${C_DIR}${dir}${C_RST}"
if [ -n "$model" ]; then
  seg_model="${C_MODEL}${model}${C_RST}"
  [ -n "$window" ] && seg_model="$seg_model ${window}${C_RST}"
fi
[ -n "$ctx" ] && seg_ctx="${C_CTX}ctx ${ctx}%${C_RST}"
# Hide diff stats when the working tree is clean
if [ "$added" != "0" ] || [ "$removed" != "0" ]; then
  seg_diff="${C_ADD}+${added}${C_SEP}/${C_RST}${C_REM}-${removed}${C_RST}"
fi
if [ -n "$branch" ]; then
  if [ "$branch" = "main" ]; then
    seg_branch="${C_MODEL}${branch}${C_RST}"
  else
    seg_branch="${C_BRANCH}${branch}${C_RST}"
  fi
elif [ -n "$nogit" ]; then
  seg_branch="${C_NOGIT}NO GIT!${C_RST}"
fi

out=""
for seg in "$seg_model" "$seg_ctx" "$seg_diff" "$seg_branch" "$seg_dir"; do
  [ -z "$seg" ] && continue
  if [ -z "$out" ]; then out="$seg"; else out="$out$sep$seg"; fi
done

printf '%b' "$out"

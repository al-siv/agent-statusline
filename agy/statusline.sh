#!/usr/bin/env bash
#
# Semantic, color-coded status line for Antigravity CLI (matching claude-code-status-line).
#
# Segments:
#   <agent_state>  dir  <branch>  ∆:C+N/<bal>  <model>•<eff>  5h:X% 7d:Y%/X.X{d|h|m}  <mode>
#
# Color layers:
#
#   TRAFFIC LIGHT (approaching a hard ceiling, a quantitative gradient):
#     - quota left 5h / 7d  : orange < RL_WARN_LEFT% left, red < RL_CRIT_LEFT% left
#                             (7d reset suffix /X.X{d|h|m} stays neutral)
#
#   AGENT STATE GRADATION (leftmost segment):
#     - idle                         : ===  muted gray (38;5;245)
#     - initializing, authenticating : ...  sky blue (38;5;75)
#     - thinking, working            : >>>  bold bright cyan (1;38;5;81)
#     - tool_use, merging            : ***  bold amber-gold (1;38;5;214)
#     - reviewing                    : ???  bold electric magenta (1;38;5;201)
#     - error                        : !!!  bold red (1;38;5;196)
#     - other (unknown)              : raw <state>  bold bright cyan (1;38;5;81)
#
#   EFFORT GRADATION (distinct color per reasoning effort level):
#     - L  (low)       : bold coral-red (1;38;5;203)
#     - M  (medium)    : bold amber-gold (1;38;5;214)
#     - H  (high)      : bold lime-green (1;38;5;118)
#     - XH / X (xhigh/max) : bold electric magenta (1;38;5;201)
#
#   IDENTITY (which model is running, a categorical label; regular weight):
#     - model : one hue per family -- Opus/Carbon/Orchestrator purple,
#               Sonnet/Hydrogen pink, Fable/Argon turquoise, Haiku/Flash sky blue.
#
#   INFORMATION (git state):
#     - branch      : muted gray (38;5;245) on MAIN_BRANCH, bold bright cyan (1;38;5;51) off main
#     - ∆:C+N/<bal> : C changed tracked files (yellow), N new/untracked files (green),
#                     <bal> net tracked line diff (+B green, -B red, 0 neutral, - neutral when none)
#
#   ACCESS MODE GRADATION (rightmost segment):
#     - ask / strict         : muted gray (38;5;245)
#     - plan                 : sky blue (38;5;75)
#     - accept-edits         : bold amber-gold (1;38;5;214)
#     - auto                 : bold lime-green (1;38;5;118)
#     - best-of-n            : purple (38;5;135)
#     - yolo                 : bold coral-red (1;38;5;203)

input=$(cat)

# ---- Configuration (override via environment) ------------------------------
RL_WARN_LEFT="${STATUSLINE_RL_WARN_LEFT:-20}"             # rate-limit % left -> orange
RL_CRIT_LEFT="${STATUSLINE_RL_CRIT_LEFT:-5}"              # rate-limit % left -> red
MAIN_BRANCH="${STATUSLINE_MAIN_BRANCH:-main}"             # branch treated as "home"

# ---- ANSI palette (256-color) ----------------------------------------------
GRAY=$'\033[38;5;245m'         # calm baseline: idle state, main branch, manual ask mode
ORANGE=$'\033[38;5;208m'       # traffic light: warn
RED=$'\033[38;5;196m'          # traffic light: critical / negative line balance
GREEN=$'\033[38;5;40m'         # information: addition (new files, positive line balance)
YELLOW=$'\033[38;5;220m'       # information: modified tracked files
BRANCH_HI=$'\033[1;38;5;51m'   # information: off-main branch (bold bright cyan)

STATE_INIT=$'\033[38;5;75m'    # agent_state: initializing / authenticating (sky blue)
STATE_WORK=$'\033[1;38;5;81m'  # agent_state: thinking / working (bold bright cyan)
STATE_TOOL=$'\033[1;38;5;214m' # agent_state: tool_use / merging (bold amber-gold)
STATE_REV=$'\033[1;38;5;201m'  # agent_state: reviewing (bold electric magenta)
STATE_ERR=$'\033[1;38;5;196m'  # agent_state: error (bold red)

EFF_LOW=$'\033[1;38;5;203m'    # effort: Low (bold coral-red)
EFF_MED=$'\033[1;38;5;214m'    # effort: Medium (bold amber-gold)
EFF_HIGH=$'\033[1;38;5;118m'   # effort: High (bold lime-green)
EFF_XHIGH=$'\033[1;38;5;201m'  # effort: XHigh / Max (bold electric magenta)

OPUS=$'\033[38;5;135m'         # identity: Opus / Carbon     (purple)
SONNET=$'\033[38;5;211m'       # identity: Sonnet / Hydrogen (pink)
FABLE=$'\033[38;5;43m'         # identity: Fable / Argon     (turquoise)
HAIKU=$'\033[38;5;75m'         # identity: Haiku / Flash     (sky blue)

MODE_PLAN=$'\033[38;5;75m'     # access mode: plan (sky blue)
MODE_EDIT=$'\033[1;38;5;214m'  # access mode: accept-edits (bold amber-gold)
MODE_AUTO=$'\033[1;38;5;118m'  # access mode: auto (bold lime-green)
MODE_BEST=$'\033[38;5;135m'    # access mode: best-of-n (purple)
MODE_YOLO=$'\033[1;38;5;203m'  # access mode: unrestricted / always-proceed (bold coral-red)

RESET=$'\033[0m'
if [ -n "${NO_COLOR:-}" ]; then
  GRAY=""; ORANGE=""; RED=""; GREEN=""; YELLOW=""; BRANCH_HI=""
  STATE_INIT=""; STATE_WORK=""; STATE_TOOL=""; STATE_REV=""; STATE_ERR=""
  EFF_LOW=""; EFF_MED=""; EFF_HIGH=""; EFF_XHIGH=""
  OPUS=""; SONNET=""; FABLE=""; HAIKU=""
  MODE_PLAN=""; MODE_EDIT=""; MODE_AUTO=""; MODE_BEST=""; MODE_YOLO=""
  RESET=""
fi

# ---- Fields from the status JSON -------------------------------------------
state=$(jq -r '(.agent_state? | strings) // empty' <<<"$input" 2>/dev/null)
mode=$(jq -r '(.cycle_mode? | strings) // (.mode? | strings) // (.permission_mode? | strings) // empty' <<<"$input" 2>/dev/null)
product=$(jq -r '(.product? | strings) // empty' <<<"$input" 2>/dev/null)
cwd=$(jq -r '(.workspace?.current_dir? | strings | select(length > 0)) // (.cwd? | strings | select(length > 0)) // "."' <<<"$input" 2>/dev/null)
[ -z "$cwd" ] && cwd="."
dir=$(basename -- "$cwd" 2>/dev/null); [ -z "$dir" ] && dir="."
raw_model=$(jq -r '(.model?.display_name? | strings) // empty' <<<"$input" 2>/dev/null | sed 's/ context)/)/')
model_id=$(jq -r '(.model?.id? | strings) // empty' <<<"$input" 2>/dev/null)
eff=$(jq -r '(.effort?.level? | strings) // (.model?.effort? | strings) // empty' <<<"$input" 2>/dev/null)

# In Antigravity, display_name/id often embeds effort, e.g. "Gemini 4 Argon (Medium)" or "gemini-4-argon-medium".
# Extract effort if not set separately, strip the parenthesized effort suffix,
# remove "Gemini " anywhere, and shorten "Orchestrator" / "Orchistrator" to "Orch.".
if [ -z "$eff" ]; then
  shopt -s nocasematch
  for src_eff in "$raw_model" "$model_id"; do
    if [[ "$src_eff" =~ \((low|medium|high|xhigh|max)\)$ ]] || [[ "$src_eff" =~ -(low|medium|high|xhigh|max)$ ]]; then
      eff="${BASH_REMATCH[1]}"
      break
    fi
  done
  shopt -u nocasematch
fi
model=$(sed -E '
  s/ \((Low|Medium|High|XHigh|Max)\)$//I
  s/Gemini[- ]+//Ig
  s/Pro +(Orch[ei]strator)/\1/Ig
  s/Orch[ei]strator *\(([^)]+)\)/Orch. \1/Ig
  s/Orch[ei]strator[- ]+/Orch. /Ig
  s/Orch[ei]strator$/Orch./I
' <<<"$raw_model")

# Extract 5h/7d rate-limit used percentages and 7d reset seconds from .rate_limits or Antigravity's .quota buckets.
# In Antigravity, Gemini models share "gemini-5h" + "gemini-weekly", and Claude/GPT share "3p-5h" + "3p-weekly".
quota_parsed=$(jq -r --arg mid "$model_id" --arg mname "$raw_model" '
  def slugify: ascii_downcase | gsub("[^a-z0-9.]+"; "-") | sub("^-+"; "") | sub("-+$"; "");
  def model_family:
    ascii_downcase
    | if test("gemini|argon|carbon|hydrogen|flash|orch[ei]strator") then "gemini"
      elif test("claude|opus|sonnet|haiku|fable|gpt|3p") then "3p"
      else "" end;
  def bucket_family:
    ascii_downcase
    | if test("gemini|argon|carbon|hydrogen|flash|orch[ei]strator") then "gemini"
      elif test("^3p|claude|opus|sonnet|haiku|fable|gpt") then "3p"
      else "" end;
  def bucket_win($k; $b):
    ($k | ascii_downcase) as $kl
    | if ($kl | test("weekly|7d|week")) then "7d"
      elif ($kl | test("5h|five")) then "5h"
      elif (($b.reset_in_seconds? // 0) | type == "number" and isfinite and (isnan | not) and . > 86400) then "7d"
      else "5h" end;
  def used_pct($b):
    if ((($b.remaining_fraction? // null) | (type == "number" and isfinite and (isnan | not) and ((100 - (. * 100)) | isfinite)))) then
      ((100 - ($b.remaining_fraction * 100)) | tostring)
    else empty end;
  def reset_sec($b):
    if (($b.reset_in_seconds? // null) | type == "number" and isfinite and (isnan | not)) then
      ((if $b.reset_in_seconds < 0 then 0 else $b.reset_in_seconds end) | tostring)
    elif (($b.reset_time? // null) | type == "string") then
      (($b.reset_time | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch null)) as $ts
      | if $ts != null then ((($ts - now) | if . < 0 then 0 else . end) | tostring) else "" end
    else "" end;

  (($mid + " " + $mname) | model_family) as $fam |
  ($mid | slugify) as $mslug |
  ($mname | slugify) as $nslug |
  ((.quota? // {}) | if type == "object" then
    [ to_entries[]
      | select((.value | type) == "object" and (((.value.remaining_fraction? // null) | (type == "number" and isfinite and (isnan | not) and ((100 - (. * 100)) | isfinite))) or (reset_sec(.value) != "")))
    ]
  else [] end) as $all |
  (if $fam != "" then
    [ $all[] | select((.key | bucket_family) == $fam or .key == $mid or .key == $mslug or .key == $nslug) ]
  else [] end) as $fam_entries |
  (if ($fam_entries | length) > 0 then $fam_entries else $all end) as $picked |
  (
    if ((.rate_limits?.five_hour?.used_percentage? // null) | type == "number" and isfinite and (isnan | not)) then
      (.rate_limits.five_hour.used_percentage | tostring)
    else
      ([ $picked[] | select(bucket_win(.key; .value) == "5h") | used_pct(.value) ][0] // "")
    end
  ) as $five |
  (
    if ((.rate_limits?.seven_day?.used_percentage? // null) | type == "number" and isfinite and (isnan | not)) then
      (.rate_limits.seven_day.used_percentage | tostring)
    else
      ([ $picked[] | select(bucket_win(.key; .value) == "7d") | used_pct(.value) ][0] // "")
    end
  ) as $week |
  (
    if ((.rate_limits?.seven_day?.resets_at? // null) | type == "number" and isfinite and (isnan | not) and . > 0) then
      (((.rate_limits.seven_day.resets_at - now) | if . < 0 then 0 else . end) | tostring)
    else
      ([ $picked[] | select(bucket_win(.key; .value) == "7d") | reset_sec(.value) | select(. != "") ][0] // "")
    end
  ) as $week_reset |
  "\($five)\n\($week)\n\($week_reset)"
' <<<"$input" 2>/dev/null)

five=""; week=""; week_reset=""
if [ -n "$quota_parsed" ]; then
  {
    IFS= read -r five
    IFS= read -r week
    IFS= read -r week_reset
  } <<EOF
$quota_parsed
EOF
fi

branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$branch" ] && branch=$(jq -r '(.vcs?.branch? | strings) // empty' <<<"$input" 2>/dev/null)

# ---- agent_state (3-char ASCII glyph + semantic color; raw state on unknown)
if [ -n "$state" ]; then
  s_label="$state"
  scol=""
  case "$(tr '[:upper:]' '[:lower:]' <<<"$state")" in
    idle)                           s_label="==="; scol="$GRAY";;
    initializing|authenticating)    s_label="..."; scol="$STATE_INIT";;
    thinking|working)               s_label=">>>"; scol="$STATE_WORK";;
    tool_use|merging)               s_label="***"; scol="$STATE_TOOL";;
    reviewing)                      s_label="???"; scol="$STATE_REV";;
    error)                          s_label="!!!"; scol="$STATE_ERR";;
    *)                              scol="$STATE_WORK";;
  esac
  if [ -n "$scol" ]; then
    out="${scol}${s_label}${RESET}  ${dir}"
  else
    out="${s_label}  ${dir}"
  fi
else
  out="$dir"
fi

# Colors a number only when it is greater than 0; otherwise leaves it neutral.
col_n() {  # $1=number  $2=color
  if [ "$1" -gt 0 ] 2>/dev/null; then printf '%s%s%s' "$2" "$1" "$RESET"
  else printf '%s' "$1"; fi
}

# ---- git: branch + uncommitted counters ------------------------------------
if [ -n "$branch" ]; then
  if [ "$branch" = "$MAIN_BRANCH" ]; then
    out="$out  ${GRAY}${branch}${RESET}"
  else
    out="$out  ${BRANCH_HI}${branch}${RESET}"
  fi

  # ∆:C+N/<bal>  (always shown; C changed = yellow, N new = green, <bal> net line balance)
  porc=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  if [ -n "$porc" ]; then
    n=$(grep -c '^??' <<<"$porc")     # new (untracked)
    c=$(grep -vc '^??' <<<"$porc")    # changed/deleted/staged (tracked)
  else n=0; c=0; fi
  diffstat=$(git -C "$cwd" --no-optional-locks diff HEAD --numstat 2>/dev/null)
  la=$(LC_ALL=C awk '$1 ~ /^[0-9]+$/ {a+=$1} END{printf "%.0f", a+0}' <<<"$diffstat")
  lr=$(LC_ALL=C awk '$2 ~ /^[0-9]+$/ {d+=$2} END{printf "%.0f", d+0}' <<<"$diffstat")
  if [ "$la" -eq 0 ] && [ "$lr" -eq 0 ]; then
    bal_s="-"
  else
    bal=$(( la - lr ))
    if [ "$bal" -gt 0 ]; then
      bal_s="${GREEN}+${bal}${RESET}"
    elif [ "$bal" -lt 0 ]; then
      bal_s="${RED}${bal}${RESET}"
    else
      bal_s="0"
    fi
  fi
  out="$out  ∆:$(col_n "$c" "$YELLOW")+$(col_n "$n" "$GREEN")/${bal_s}"
fi

# ---- model (one color per family; display name first, then model id) -------
if [ -n "$model" ]; then
  mcol=""
  for src in "$raw_model" "$model_id"; do
    case "$(tr '[:upper:]' '[:lower:]' <<<"$src")" in
      *sonnet*|*hydrogen*) mcol="$SONNET";;
      *fable*|*argon*)     mcol="$FABLE";;
      *haiku*|*flash*)     mcol="$HAIKU";;
      *opus*|*carbon*|*orchestrator*|*orchistrator*) mcol="$OPUS";;
    esac
    [ -n "$mcol" ] && break
  done
  if [ -n "$mcol" ]; then out="$out  ${mcol}${model}${RESET}"
  else out="$out  $model"; fi
fi

# ---- effort •eff, glued to the model (dedicated color per effort level) ----
# Displayed compactly: low=L medium=M high=H xhigh=XH max=X
if [ -n "$eff" ]; then
  eff_lc=$(tr '[:upper:]' '[:lower:]' <<<"$eff")
  ecol=""
  case "$eff_lc" in
    low)    ef="L";  ecol="$EFF_LOW";;
    medium) ef="M";  ecol="$EFF_MED";;
    high)   ef="H";  ecol="$EFF_HIGH";;
    xhigh)  ef="XH"; ecol="$EFF_XHIGH";;
    max)    ef="X";  ecol="$EFF_XHIGH";;
    *)      ef="$eff";;
  esac
  if [ -n "$model" ]; then sep="•"; else sep="  "; fi
  if [ -n "$ecol" ]; then
    out="$out$sep${ecol}${ef}${RESET}"
  else
    out="$out$sep$ef"
  fi
fi

# ---- TRAFFIC LIGHT: rate limits / quota (5h and 7d), as the share left -----
rl_seg() {  # $1=label  $2=used percent
  [ -z "$2" ] && return
  local p col=""
  p=$(LC_ALL=C awk -v u="$2" 'BEGIN {
    if (u !~ /^[+-]?([0-9]+([.][0-9]+)?|[.][0-9]+)([eE][+-]?[0-9]+)?$/) exit 1
    p = 100 - sprintf("%.0f", u)
    if (p <= 0) p = 0
    s = sprintf("%.0f", p)
    if (s !~ /^[0-9]+$/ || length(s) > 18) exit 1
    print s
  }') || return 0
  if   [ "$p" -lt "$RL_CRIT_LEFT" ]; then col="$RED"
  elif [ "$p" -lt "$RL_WARN_LEFT" ]; then col="$ORANGE"
  fi
  if [ -n "$col" ]; then printf '%s%s:%s%%%s' "$col" "$1" "$p" "$RESET"
  else printf '%s:%s%%' "$1" "$p"; fi
}
fmt_reset() {  # $1=remaining seconds -> X.X{d|h|m}
  [ -z "$1" ] && return
  local val
  val=$(LC_ALL=C awk -v s="$1" 'BEGIN {
    if (s !~ /^[+-]?([0-9]+([.][0-9]+)?|[.][0-9]+)([eE][+-]?[0-9]+)?$/) exit 1
    r = s + 0
    if (r <= 0) r = 0
    if (r >= 86400) {
      out = sprintf("%.1fd", r / 86400)
    } else if (r >= 3600) {
      h = sprintf("%.1f", r / 3600) + 0
      if (h >= 24) out = sprintf("%.1fd", r / 86400)
      else out = sprintf("%.1fh", h)
    } else {
      m = sprintf("%.1f", r / 60) + 0
      if (m >= 60) out = sprintf("%.1fh", r / 3600)
      else out = sprintf("%.1fm", m)
    }
    if (out !~ /^[0-9]+[.][0-9][dhm]$/ || length(out) > 18) exit 1
    print out
  }') || return 0
  printf '%s' "$val"
}
rl=""
seg=$(rl_seg 5h "$five"); [ -n "$seg" ] && rl="$seg"
seg=$(rl_seg 7d "$week")
rt=$(fmt_reset "$week_reset")
if [ -n "$seg" ] && [ -n "$rt" ]; then
  seg="${seg}/${rt}"
elif [ -z "$seg" ] && [ -n "$rt" ]; then
  seg="7d:-/${rt}"
fi
[ -n "$seg" ] && rl="$rl${rl:+ }$seg"
[ -n "$rl" ] && out="$out  $rl"

# ---- ACCESS MODE (rightmost segment, color-graded) -------------------------
# When cycle_mode is omitted in an Antigravity session, the CLI is in default manual "ask" mode.
if [ -z "$mode" ] && { [ -n "$state" ] || [ "$product" = "antigravity" ]; }; then
  mode="ask"
fi
if [ -n "$mode" ]; then
  mode_lc=$(tr '[:upper:]' '[:lower:]' <<<"$mode")
  m_label="$mode"
  m_col=""
  case "$mode_lc" in
    ask|manual|default|normal|request-review)
      m_label="ask"; m_col="$GRAY";;
    strict)
      m_label="strict"; m_col="$GRAY";;
    plan)
      m_label="plan"; m_col="$MODE_PLAN";;
    accept-edits|edits|proceed-in-sandbox)
      m_label="accept-edits"; m_col="$MODE_EDIT";;
    auto)
      m_label="auto"; m_col="$MODE_AUTO";;
    bestn|best-of-n)
      m_label="best-of-n"; m_col="$MODE_BEST";;
    always-proceed|bypasspermissions|yolo)
      m_label="yolo"; m_col="$MODE_YOLO";;
    *)
      m_col="$MODE_PLAN";;
  esac
  if [ -n "$m_col" ]; then
    out="$out  ${m_col}${m_label}${RESET}"
  else
    out="$out  $m_label"
  fi
fi

printf '%s\n' "$out"

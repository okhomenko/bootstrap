#!/usr/bin/env bash
# Claude Code status line
#   Line 1: model · effort │ folder │ branch +staged ~modified │ PR
#   Line 2: context bar │ session cost │ elapsed │ lines ± │ 5h / 7d usage
# Requires: jq, git (optional)

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "statusline: install jq (brew install jq / apt install jq)"; exit 0
fi

# ---- Parse everything with a single jq call (fast) ----------------------
SEP=$'\x1f'
IFS="$SEP" read -r MODEL EFFORT DIR SESSION PCT COST DUR ADDED REMOVED FIVE_H WEEK PR_NUM PR_STATE <<< "$(
  jq -r '
    def pct: if . == null then "" else (floor | tostring) end;
    [
      (.model.display_name // "Claude"),
      (.effort.level // ""),
      (.workspace.current_dir // .cwd // ""),
      (.session_id // "default"),
      (.context_window.used_percentage // 0 | floor | tostring),
      (.cost.total_cost_usd // 0 | tostring),
      (.cost.total_duration_ms // 0 | tostring),
      (.cost.total_lines_added // 0 | tostring),
      (.cost.total_lines_removed // 0 | tostring),
      (.rate_limits.five_hour.used_percentage | pct),
      (.rate_limits.seven_day.used_percentage | pct),
      (.pr.number // "" | tostring),
      (.pr.review_state // "")
    ] | join("\u001f")' <<< "$input"
)"
PCT=${PCT:-0}; COST=${COST:-0}; DUR=${DUR:-0}; ADDED=${ADDED:-0}; REMOVED=${REMOVED:-0}
[ -z "$DIR" ] && DIR=$PWD

# ---- Colors --------------------------------------------------------------
R=$'\033[0m'; DIM=$'\033[2m'; BOLD=$'\033[1m'
RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'
BLU=$'\033[34m'; MAG=$'\033[35m'; CYN=$'\033[36m'
SEPR="${DIM} │ ${R}"

color_for() {  # green < 70 ≤ yellow < 90 ≤ red
  if   [ "$1" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$YEL"
  else                       printf '%s' "$GRN"; fi
}

# ---- Git info (cached 5s per session so big repos stay snappy) -----------
CACHE="/tmp/claude-statusline-git-${SESSION}"
now=$(date +%s)
mtime=$(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)
if [ $((now - mtime)) -gt 5 ]; then
  if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
    b=$(git -C "$DIR" branch --show-current 2>/dev/null)
    [ -z "$b" ] && b="@$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"
    s=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    m=$(git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    printf '%s|%s|%s' "$b" "$s" "$m" > "$CACHE"
  else
    printf '||' > "$CACHE"
  fi
fi
IFS='|' read -r BRANCH STAGED MODIFIED < "$CACHE"

# ---- Line 1 --------------------------------------------------------------
L1="${BOLD}${CYN}${MODEL}${R}"
[ -n "$EFFORT" ] && L1+="${DIM} · ${EFFORT}${R}"
L1+="${SEPR}${BLU}📁 ${DIR##*/}${R}"

if [ -n "$BRANCH" ]; then
  L1+="${SEPR}${MAG}🌿 ${BRANCH}${R}"
  [ "${STAGED:-0}" -gt 0 ]   && L1+=" ${GRN}+${STAGED}${R}"
  [ "${MODIFIED:-0}" -gt 0 ] && L1+=" ${YEL}~${MODIFIED}${R}"
fi

if [ -n "$PR_NUM" ]; then
  case "$PR_STATE" in
    approved)          pc="$GRN" ;;
    changes_requested) pc="$RED" ;;
    draft)             pc="$DIM" ;;
    *)                 pc="$YEL" ;;
  esac
  L1+="${SEPR}${pc}PR #${PR_NUM}${PR_STATE:+ ${PR_STATE//_/ }}${R}"
fi

# ---- Line 2 --------------------------------------------------------------
PCT=${PCT:-0}
filled=$((PCT / 10)); [ "$filled" -gt 10 ] && filled=10
empty=$((10 - filled))
printf -v F "%${filled}s"; printf -v E "%${empty}s"
BAR="${F// /█}${DIM}${E// /░}${R}"
L2="$(color_for "$PCT")${BAR}$(color_for "$PCT") ${PCT}%${R} ctx"

L2+="${SEPR}${YEL}$(printf '$%.2f' "$COST")${R}"

secs=$((DUR / 1000))
if [ "$secs" -ge 3600 ]; then T="$((secs / 3600))h $(((secs % 3600) / 60))m"
else                          T="$((secs / 60))m $((secs % 60))s"; fi
L2+="${SEPR}⏱ ${T}"

if [ "$ADDED" -gt 0 ] || [ "$REMOVED" -gt 0 ]; then
  L2+="${SEPR}${GRN}+${ADDED}${R} ${RED}-${REMOVED}${R}"
fi

LIMITS=""
[ -n "$FIVE_H" ] && LIMITS+="$(color_for "$FIVE_H")5h ${FIVE_H}%${R}"
[ -n "$WEEK" ]   && LIMITS+="${LIMITS:+ }$(color_for "$WEEK")7d ${WEEK}%${R}"
[ -n "$LIMITS" ] && L2+="${SEPR}${LIMITS}"

printf '%s\n%s\n' "$L1" "$L2"

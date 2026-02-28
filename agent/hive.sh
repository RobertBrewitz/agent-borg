#!/bin/bash
# Hive - Continuously dispatch agents for plans in todo/
# Usage: ./hive.sh [OPTIONS]
#
# Continuously polls plans/todo/ for new plans, dispatches agents (up to
# max-concurrent at a time), and reports completion status. Recovers stale
# plans left in in-progress/ by crashed agents. Runs until interrupted
# with Ctrl-C.

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
MAX_CONCURRENT=3      # max parallel agents
POLL_INTERVAL=10      # seconds between polls for new plans
STALE_TIMEOUT=1800    # seconds before an in-progress plan with no active agent is recovered (30 min)
MAX_RETRIES=3         # max times to re-dispatch a failed plan before moving to blocked/
RETRY_BLOCKED=false   # when true, move all blocked/ plans back to todo/ on startup

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-concurrent) MAX_CONCURRENT="$2"; shift 2 ;;
    --poll-interval) POLL_INTERVAL="$2"; shift 2 ;;
    --stale-timeout) STALE_TIMEOUT="$2"; shift 2 ;;
    --max-retries) MAX_RETRIES="$2"; shift 2 ;;
    --retry-blocked) RETRY_BLOCKED=true; shift ;;
    -h|--help)
      echo "Usage: ./hive.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --max-concurrent N  Max parallel agents (default: 3)"
      echo "  --poll-interval S   Seconds between todo/ polls (default: 10)"
      echo "  --stale-timeout S   Seconds before recovering stale in-progress plans (default: 1800)"
      echo "  --max-retries N     Max re-dispatches before moving to blocked/ (default: 3)"
      echo "  --retry-blocked     Move all blocked/ plans back to todo/ on startup"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Resolve paths ─────────────────────────────────────────────────────────────
GIT_COMMON="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
if [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
  PROJECT_ROOT="$GIT_COMMON"
else
  PROJECT_ROOT="$(dirname "$GIT_COMMON")"
fi
PLANS_DIR="$PROJECT_ROOT/plans"
CODER_SH="$PROJECT_ROOT/coder.sh"

mkdir -p "$PLANS_DIR/todo" "$PLANS_DIR/in-progress" "$PLANS_DIR/done" "$PLANS_DIR/blocked" "$PLANS_DIR/progress"

if [ ! -x "$CODER_SH" ]; then
  echo "Error: coder.sh not found or not executable at $CODER_SH"
  exit 1
fi

# ── Signal handling ───────────────────────────────────────────────────────────
declare -A ACTIVE_PIDS  # pid -> plan-name

cleanup() {
  echo ""
  echo "Shutting down hive..."
  trap - INT TERM

  for pid in "${!ACTIVE_PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      echo "  Stopping agent for '${ACTIVE_PIDS[$pid]}' (pid $pid)"
      kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    fi
  done

  wait 2>/dev/null
  echo "All agents stopped."
  exit 0
}
trap cleanup INT TERM

# ── Helpers ───────────────────────────────────────────────────────────────────

plan_to_name() {
  local name="$1"
  name="${name%.md}"
  name="${name%/}"
  echo "$name"
}

read_plan_branch() {
  local plan_path="$1"
  local plan_name="$2"
  local file

  if [ -d "$plan_path" ]; then
    file="$(ls "$plan_path"/*.md 2>/dev/null | sort | head -n1)"
    [ -z "$file" ] && { echo "$plan_name"; return; }
  else
    file="$plan_path"
  fi

  local branch
  branch="$(head -20 "$file" | sed -n 's/^\*\*Branch:\*\* *//p' | tr -d '[:space:]`')"

  if [ -n "$branch" ]; then
    echo "$branch"
  else
    echo "$plan_name"
  fi
}

# Find a plan's path in a given status directory (returns file or folder path, empty if not found)
find_plan_in() {
  local dir="$1" name="$2"
  if [ -f "$dir/${name}.md" ]; then
    echo "$dir/${name}.md"
  elif [ -d "$dir/${name}" ]; then
    echo "$dir/${name}"
  fi
}

# ── Continuous poll and dispatch ──────────────────────────────────────────────
declare -A DISPATCHED       # plan-name -> 1 (tracks already-dispatched plans)
declare -A DISPATCH_RETRIES # plan-name -> number of times re-dispatched after failure
active_count=0

# Recover orphaned plans left in in-progress/ with no active agent
recover_orphans() {
  # Collect names of plans with active agents
  local -A active_names
  for pid in "${!ACTIVE_PIDS[@]}"; do
    active_names["${ACTIVE_PIDS[$pid]}"]=1
  done

  for plan_path in "$PLANS_DIR/in-progress/"*.md "$PLANS_DIR/in-progress/"*/; do
    [ -e "$plan_path" ] || continue
    local plan_name
    plan_name="$(basename "$plan_path")"
    plan_name="$(plan_to_name "$plan_name")"

    # Skip if an agent is actively working on it
    [ -n "${active_names[$plan_name]+x}" ] && continue

    # Check staleness via progress file mtime (fall back to plan path)
    local check_file="$plan_path"
    [ -f "$PLANS_DIR/progress/${plan_name}.md" ] && check_file="$PLANS_DIR/progress/${plan_name}.md"

    local mtime now age
    mtime="$(stat -c %Y "$check_file" 2>/dev/null || echo 0)"
    now="$(date +%s)"
    age=$((now - mtime))

    if [ "$age" -gt "$STALE_TIMEOUT" ]; then
      local retries="${DISPATCH_RETRIES[$plan_name]:-0}"
      retries=$((retries + 1))
      DISPATCH_RETRIES[$plan_name]=$retries
      if [ "$retries" -ge "$MAX_RETRIES" ]; then
        echo "[$(date '+%H:%M:%S')] Stale plan '$plan_name' (${age}s) -> blocked/ after $retries failed attempts"
        mv "$plan_path" "$PLANS_DIR/blocked/"
      else
        echo "[$(date '+%H:%M:%S')] Recovering stale plan '$plan_name' (${age}s) -> todo/ (attempt $retries/$MAX_RETRIES)"
        mv "$plan_path" "$PLANS_DIR/todo/"
        unset "DISPATCHED[$plan_name]"
      fi
    fi
  done
}

# Move all blocked/ plans back to todo/
retry_blocked_plans() {
  for plan_path in "$PLANS_DIR/blocked/"*.md "$PLANS_DIR/blocked/"*/; do
    [ -e "$plan_path" ] || continue
    local plan_name
    plan_name="$(basename "$plan_path")"
    plan_name="$(plan_to_name "$plan_name")"
    echo "[$(date '+%H:%M:%S')] Retrying blocked plan '$plan_name' -> todo/"
    mv "$plan_path" "$PLANS_DIR/todo/"
    unset "DISPATCHED[$plan_name]"
    DISPATCH_RETRIES[$plan_name]=0
  done
}

# ── Retry blocked plans on startup if requested ─────────────────────────────
if [ "$RETRY_BLOCKED" = true ]; then
  retry_blocked_plans
fi

echo "Hive: polling todo/ every ${POLL_INTERVAL}s (max $MAX_CONCURRENT concurrent, stale after ${STALE_TIMEOUT}s)"
echo "Press Ctrl-C to stop."
echo ""

# Reap any finished agents, non-blocking
reap_finished() {
  for pid in "${!ACTIVE_PIDS[@]}"; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null
      local exit_code=$?
      local name="${ACTIVE_PIDS[$pid]}"
      if [ "$exit_code" -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] done '$name'"
      else
        echo "[$(date '+%H:%M:%S')] FAILED '$name' (exit $exit_code)"
        # If plan is still in in-progress/, recover it
        local stuck_path
        stuck_path="$(find_plan_in "$PLANS_DIR/in-progress" "$name")"
        if [ -n "$stuck_path" ]; then
          local retries="${DISPATCH_RETRIES[$name]:-0}"
          retries=$((retries + 1))
          DISPATCH_RETRIES[$name]=$retries
          if [ "$retries" -ge "$MAX_RETRIES" ]; then
            echo "[$(date '+%H:%M:%S')] Moving '$name' to blocked/ after $retries failed attempts"
            mv "$stuck_path" "$PLANS_DIR/blocked/"
          else
            echo "[$(date '+%H:%M:%S')] Re-queuing '$name' to todo/ (attempt $retries/$MAX_RETRIES)"
            mv "$stuck_path" "$PLANS_DIR/todo/"
            unset "DISPATCHED[$name]"
          fi
        fi
      fi
      unset "ACTIVE_PIDS[$pid]"
      active_count=$((active_count - 1))
    fi
  done
}

while true; do
  # Reap finished agents and recover orphaned plans
  reap_finished
  recover_orphans

  # Scan todo/ for new plans
  for plan_path in "$PLANS_DIR/todo/"*.md "$PLANS_DIR/todo/"*/; do
    [ -e "$plan_path" ] || continue

    plan_name="$(basename "$plan_path")"
    plan_name="$(plan_to_name "$plan_name")"

    # Skip already-dispatched plans
    [ -n "${DISPATCHED[$plan_name]+x}" ] && continue

    # Wait if at concurrency limit
    while [ "$active_count" -ge "$MAX_CONCURRENT" ]; do
      sleep 1
      reap_finished
    done

    branch="$(read_plan_branch "$plan_path" "$plan_name")"
    echo "[$(date '+%H:%M:%S')] Dispatching '$plan_name' -> branch '$branch'"

    setsid "$CODER_SH" "$branch" "$plan_path" > /dev/null 2>&1 &
    agent_pid=$!
    ACTIVE_PIDS[$agent_pid]="$plan_name"
    DISPATCHED[$plan_name]=1
    active_count=$((active_count + 1))
  done

  # Sleep before next poll (interruptible by trap)
  sleep "$POLL_INTERVAL" &
  wait $! 2>/dev/null || true
done

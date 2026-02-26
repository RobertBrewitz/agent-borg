#!/bin/bash
# Hive - Continuously dispatch agents for plans in todo/
# Usage: ./hive.sh [--max-concurrent N] [--poll-interval S]
#
# Continuously polls plans/todo/ for new plans, dispatches agents (up to
# max-concurrent at a time), and reports completion status. Runs until
# interrupted with Ctrl-C.

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
MAX_CONCURRENT=3      # max parallel agents
POLL_INTERVAL=10      # seconds between polls for new plans

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-concurrent) MAX_CONCURRENT="$2"; shift 2 ;;
    --poll-interval) POLL_INTERVAL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./hive.sh [--max-concurrent N] [--poll-interval S]"
      echo ""
      echo "Options:"
      echo "  --max-concurrent Max parallel agents (default: 3)"
      echo "  --poll-interval  Seconds between todo/ polls (default: 10)"
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

# ── Continuous poll and dispatch ──────────────────────────────────────────────
declare -A DISPATCHED  # plan-name -> 1 (tracks already-dispatched plans)
active_count=0

echo "Hive: polling todo/ every ${POLL_INTERVAL}s (max $MAX_CONCURRENT concurrent)"
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
      fi
      unset "ACTIVE_PIDS[$pid]"
      active_count=$((active_count - 1))
    fi
  done
}

while true; do
  # Reap finished agents
  reap_finished

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

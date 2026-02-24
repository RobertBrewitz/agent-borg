#!/bin/bash
# Hive - Dispatch agents for all plans in todo/, report completion once per job
# Usage: ./hive.sh [--max-concurrent N]
#
# Scans plans/todo/ once, dispatches agents for each plan (up to max-concurrent
# at a time), waits for each to finish, and prints completion status.

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
MAX_CONCURRENT=3      # max parallel agents

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-concurrent) MAX_CONCURRENT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./hive.sh [--max-concurrent N]"
      echo ""
      echo "Options:"
      echo "  --max-concurrent Max parallel agents (default: 3)"
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

# Wait for any one child to finish, report its status, return its pid
wait_for_one() {
  if ! wait -n -p FINISHED_PID 2>/dev/null; then
    # wait -n -p not supported (bash < 5.1), fall back to polling
    while true; do
      for pid in "${!ACTIVE_PIDS[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
          wait "$pid" 2>/dev/null
          WAIT_EXIT=$?
          FINISHED_PID="$pid"
          return
        fi
      done
      sleep 1
    done
  fi
  WAIT_EXIT=$?
}

# ── Collect plans ────────────────────────────────────────────────────────────
PLANS=()
for plan_path in "$PLANS_DIR/todo/"*.md "$PLANS_DIR/todo/"*/; do
  [ -e "$plan_path" ] || continue
  PLANS+=("$plan_path")
done

if [ ${#PLANS[@]} -eq 0 ]; then
  echo "No plans in todo/."
  exit 0
fi

echo "Hive: ${#PLANS[@]} plan(s) to dispatch (max $MAX_CONCURRENT concurrent)"
echo ""

# ── Dispatch and wait ─────────────────────────────────────────────────────────
active_count=0
plan_idx=0

while [ "$plan_idx" -lt "${#PLANS[@]}" ] || [ "$active_count" -gt 0 ]; do
  # Dispatch plans up to concurrency limit
  while [ "$plan_idx" -lt "${#PLANS[@]}" ] && [ "$active_count" -lt "$MAX_CONCURRENT" ]; do
    plan_path="${PLANS[$plan_idx]}"
    plan_idx=$((plan_idx + 1))

    plan_name="$(basename "$plan_path")"
    plan_name="$(plan_to_name "$plan_name")"
    branch="$(read_plan_branch "$plan_path" "$plan_name")"

    echo "[$(date '+%H:%M:%S')] Dispatching '$plan_name' -> branch '$branch'"

    setsid "$CODER_SH" "$branch" "$plan_path" > /dev/null 2>&1 &
    agent_pid=$!
    ACTIVE_PIDS[$agent_pid]="$plan_name"
    active_count=$((active_count + 1))
  done

  # Wait for next agent to finish
  if [ "$active_count" -gt 0 ]; then
    FINISHED_PID=""
    WAIT_EXIT=0
    wait_for_one

    if [ -n "$FINISHED_PID" ] && [ -n "${ACTIVE_PIDS[$FINISHED_PID]+x}" ]; then
      plan_name="${ACTIVE_PIDS[$FINISHED_PID]}"
      if [ "$WAIT_EXIT" -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] done '$plan_name'"
      else
        echo "[$(date '+%H:%M:%S')] FAILED '$plan_name' (exit $WAIT_EXIT)"
      fi
      unset "ACTIVE_PIDS[$FINISHED_PID]"
      active_count=$((active_count - 1))
    fi
  fi
done

echo ""
echo "All plans dispatched and completed."

#!/bin/bash
# Hive - Poll plans/todo/ and dispatch agents automatically
# Usage: ./hive.sh [--poll-interval SECONDS] [--max-concurrent N]
#
# Watches plans/todo/ for new plans. When one appears, derives a branch name,
# spawns coder.sh in the background to execute it, and moves on.

set -e

# ── Defaults ──────────────────────────────────────────────────────────────────
POLL_INTERVAL=10      # seconds between scans
MAX_CONCURRENT=3      # max parallel agents

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --poll-interval) POLL_INTERVAL="$2"; shift 2 ;;
    --max-concurrent) MAX_CONCURRENT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./hive.sh [--poll-interval SECONDS] [--max-concurrent N]"
      echo ""
      echo "Options:"
      echo "  --poll-interval  Seconds between todo/ scans (default: 10)"
      echo "  --max-concurrent Max parallel agents (default: 3)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Resolve paths ─────────────────────────────────────────────────────────────
# For bare repos, git-common-dir IS the project root; for normal repos it's .git/
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
SHUTDOWN=false
declare -A ACTIVE_PIDS  # pid -> plan-name

cleanup() {
  SHUTDOWN=true
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

# Strip extension/trailing slash from plan name
# "add-feature.md" -> "add-feature"
# "add-feature/"   -> "add-feature"
plan_to_name() {
  local name="$1"
  name="${name%.md}"       # strip .md
  name="${name%/}"         # strip trailing slash
  echo "$name"
}

# Read **Branch:** field from plan header.
# For folder plans, reads the first stage file (numerically).
# Falls back to plan name if no Branch field found.
read_plan_branch() {
  local plan_path="$1"
  local plan_name="$2"
  local file

  if [ -d "$plan_path" ]; then
    # Folder plan — read first stage file
    file="$(ls "$plan_path"/*.md 2>/dev/null | sort | head -n1)"
    [ -z "$file" ] && { echo "$plan_name"; return; }
  else
    file="$plan_path"
  fi

  # Extract branch from **Branch:** line (first 20 lines of header)
  # Strip backticks and whitespace — plans often format as `branch-name`
  local branch
  branch="$(head -20 "$file" | sed -n 's/^\*\*Branch:\*\* *//p' | tr -d '[:space:]`')"

  if [ -n "$branch" ]; then
    echo "$branch"
  else
    echo "$plan_name"
  fi
}

# Count currently running agents (reap finished ones first)
reap_and_count() {
  local count=0
  for pid in "${!ACTIVE_PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      count=$((count + 1))
    else
      # Agent finished — reap it
      wait "$pid" 2>/dev/null
      local exit_code=$?
      local plan_name="${ACTIVE_PIDS[$pid]}"
      if [ "$exit_code" -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] ✓ '$plan_name' done (exit $exit_code)" >&2
      else
        echo "[$(date '+%H:%M:%S')] ✗ '$plan_name' FAILED (exit $exit_code)" >&2
      fi
      unset "ACTIVE_PIDS[$pid]"
    fi
  done
  echo "$count"
}

# Check if a plan is already being worked on
plan_is_active() {
  local plan_name="$1"
  for pid in "${!ACTIVE_PIDS[@]}"; do
    if [ "${ACTIVE_PIDS[$pid]}" = "$plan_name" ] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# ── Main loop ─────────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════╗"
echo "║              Borg Hive                       ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Plans dir:     $PLANS_DIR"
echo "║  Poll interval: ${POLL_INTERVAL}s"
echo "║  Max concurrent: $MAX_CONCURRENT"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Watching plans/todo/ for new plans..."
echo ""

while true; do
  $SHUTDOWN && exit 0

  # Reap finished agents
  active_count=$(reap_and_count)

  # Scan for plans in todo/
  for plan_path in "$PLANS_DIR/todo/"*.md "$PLANS_DIR/todo/"*/; do
    $SHUTDOWN && exit 0

    # Skip glob non-matches
    [ -e "$plan_path" ] || continue

    # Extract plan name
    plan_name="$(basename "$plan_path")"
    plan_name="$(plan_to_name "$plan_name")"

    # Skip if already running
    if plan_is_active "$plan_name"; then
      continue
    fi

    # Check concurrency limit
    if [ "$active_count" -ge "$MAX_CONCURRENT" ]; then
      echo "[$(date '+%H:%M:%S')] At max concurrency ($MAX_CONCURRENT), waiting..."
      break
    fi

    # Read branch from plan header, fall back to plan name
    branch="$(read_plan_branch "$plan_path" "$plan_name")"

    echo "[$(date '+%H:%M:%S')] Dispatching '$plan_name' → branch '$branch'"

    setsid "$CODER_SH" "$branch" "$plan_path" > /dev/null 2>&1 &
    agent_pid=$!
    ACTIVE_PIDS[$agent_pid]="$plan_name"
    active_count=$((active_count + 1))
  done

  # Sleep between polls
  sleep "$POLL_INTERVAL" &
  wait $! 2>/dev/null || true
done

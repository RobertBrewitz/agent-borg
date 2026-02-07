#!/bin/bash
# Borg - Run an agent loop on a single plan
# Usage: ./borg.sh <branch> <path-to-plan>
#
# The agent loops until the plan is done or blocked, handling context-window
# limits by re-invoking Claude, which resumes from the progress file.

set -e

MODEL="claude-opus-4-6"
MAX_ITERATIONS=10

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./borg.sh <branch> <path-to-plan>"
  echo "  e.g. ./borg.sh feature-auth plans/todo/2026-02-07-feature.md"
  exit 1
fi

BRANCH="$1"
PLAN_PATH="$(realpath "$2")"
PLAN="$(basename "$PLAN_PATH")"

if [ ! -f "$PLAN_PATH" ]; then
  echo "Error: Plan not found at '$2'"
  exit 1
fi

# Resolve project root for worktree layout
# For bare repos, git-common-dir IS the project root; for normal repos it's .git/
GIT_COMMON="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
if [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
  PROJECT_ROOT="$GIT_COMMON"
else
  PROJECT_ROOT="$(dirname "$GIT_COMMON")"
fi
PLANS_DIR="$PROJECT_ROOT/plans"
WORKTREE_DIR="$PROJECT_ROOT/$BRANCH"

# Determine current status from the path
PLAN_DIR="$(dirname "$PLAN_PATH")"
PLAN_STATUS="$(basename "$PLAN_DIR")"

if [[ "$PLAN_STATUS" != "todo" && "$PLAN_STATUS" != "in-progress" ]]; then
  echo "Error: Plan must be in todo/ or in-progress/, found in $PLAN_STATUS/"
  exit 1
fi

# Set up worktree: reuse existing or create new
if [ -d "$WORKTREE_DIR" ]; then
  echo "Using existing worktree: $WORKTREE_DIR"
else
  echo "Creating worktree '$BRANCH' at $WORKTREE_DIR"
  git worktree add "$WORKTREE_DIR" -b "$BRANCH" 2>/dev/null \
    || git worktree add "$WORKTREE_DIR" "$BRANCH"
fi

cd "$WORKTREE_DIR"

# Resolve the agent directory (where this script and CLAUDE.md live)
AGENT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_INSTRUCTIONS="$AGENT_DIR/CLAUDE.md"

if [ ! -f "$AGENT_INSTRUCTIONS" ]; then
  echo "Error: CLAUDE.md not found at $AGENT_INSTRUCTIONS"
  exit 1
fi

echo "Starting Borg - Plan: $PLAN ($PLAN_STATUS)"
echo "Project root: $PROJECT_ROOT"
echo "Worktree: $WORKTREE_DIR (branch: $BRANCH)"

# Function to run claude with retry logic for transient errors
run_claude_with_retry() {
  local max_retries=3
  local retry_delay=5
  local attempt=1
  local outfile="/tmp/borg_claude_output_$$"

  while [ $attempt -le $max_retries ]; do
    set +e  # Temporarily allow errors
    claude --model "$MODEL" --dangerously-skip-permissions --verbose --print \
      --append-system-prompt "$(cat "$AGENT_INSTRUCTIONS")" \
      -p "Execute plan: $PLAN_PATH — Worktree: $WORKTREE_DIR" 2>&1 | tee "$outfile"
    EXIT_CODE=${PIPESTATUS[0]}
    OUTPUT=$(cat "$outfile")
    rm -f "$outfile"
    set -e

    # Check for known transient error patterns
    if echo "$OUTPUT" | grep -q "No messages returned"; then
      echo "Warning: Claude returned no messages (attempt $attempt/$max_retries)"
    elif echo "$OUTPUT" | grep -q "rate limit\|Rate limit\|429"; then
      echo "Warning: Rate limited (attempt $attempt/$max_retries)"
    elif echo "$OUTPUT" | grep -q "overloaded\|503\|529"; then
      echo "Warning: API overloaded (attempt $attempt/$max_retries)"
    elif echo "$OUTPUT" | grep -q "timeout\|Timeout\|ETIMEDOUT"; then
      echo "Warning: Request timeout (attempt $attempt/$max_retries)"
    elif [ $EXIT_CODE -ne 0 ] && [ -z "$OUTPUT" ]; then
      echo "Warning: Claude exited with code $EXIT_CODE and no output (attempt $attempt/$max_retries)"
    else
      # Success or non-retryable error
      return 0
    fi

    if [ $attempt -lt $max_retries ]; then
      echo "Retrying in ${retry_delay}s..."
      sleep $retry_delay
      retry_delay=$((retry_delay * 2))  # Exponential backoff
    fi
    attempt=$((attempt + 1))
  done

  echo "Error: Failed after $max_retries attempts"
  return 1
}

plan_is_active() {
  [ -f "$PLANS_DIR/in-progress/$PLAN" ] || [ -f "$PLANS_DIR/todo/$PLAN" ]
}

for i in $(seq 1 $MAX_ITERATIONS); do
  if ! plan_is_active; then
    echo "Plan '$PLAN' is no longer in todo/ or in-progress/. Done!"
    exit 0
  fi

  echo "--- Iteration $i ---"

  if ! run_claude_with_retry; then
    echo "Iteration $i failed due to persistent Claude errors. Continuing..."
    sleep 10
    continue
  fi

  if ! plan_is_active; then
    echo "Plan '$PLAN' completed in $i iterations!"
    exit 0
  fi

  sleep 2
done

echo ""
echo "Reached max iterations ($MAX_ITERATIONS) without completing plan '$PLAN'."
echo "Check plans/progress/$PLAN for status."
exit 1

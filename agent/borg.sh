#!/bin/bash
# Borg - Long-running AI agent loop
# Usage: ./borg.sh [model=code|creative|refactor|research] [max_iterations=10]

set -e

# Default arguments
MAX_ITERATIONS=10
CODE="claude-sonnet-4-5"
CREATIVE="claude-opus-4-1"
REFACTOR="claude-opus-4.5"
RESEARCH="claude-sonnet-4-5"

# load arguments from command line
MODEL="$CODE"
if [ "$1" == "creative" ]; then
  MODEL="$CREATIVE"
elif [ "$1" == "research" ]; then
  MODEL="$RESEARCH"
elif [ "$1" == "refactor" ]; then
  MODEL="$REFACTOR"
fi

if [ -n "$2" ]; then
  MAX_ITERATIONS="$2"
fi

echo "Starting Borg - Model: $MODEL, Max Iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  OPEN_TASKS=$(grep -c '^\- \[ \]' TODO.md || echo "0" > /dev/null)
  echo "Borg Agent $i starting iteration. Open tasks: $OPEN_TASKS"

  OUTPUT=$(claude --model "$MODEL" --dangerously-skip-permissions --print < "CLAUDE.md" 2>&1 | tee /dev/stderr) || true

  OPEN_TASKS=$(grep -c '^\- \[ \]' TODO.md || echo "0" > /dev/null)
  echo "Borg Agent $i completed its iteration. Open tasks remaining: $OPEN_TASKS"

  OPEN_TASKS_INTEGER=$(echo "$OPEN_TASKS" | tr -d '\n' | tr -d '\r')
  if [ "$OPEN_TASKS_INTEGER" -eq 0 ]; then
    echo "Borg has completed all tasks in $i iterations!"
    exit 0
  fi

  sleep 2
done

echo ""
echo "Borg reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check PROGRESS.md for status."
exit 1

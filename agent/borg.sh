#!/bin/bash
# Borg - Long-running AI agent loop
# Usage: ./borg.sh [model=code|creative|research] [max_iterations=10]

set -e

# Default arguments
MAX_ITERATIONS=10
CODE="claude-sonnet-4-5"
CREATIVE="claude-opus-4-5"
RESEARCH="claude-haiku-4-5"

# load arguments from command line
MODEL="$CODE"
if [ "$1" == "creative" ]; then
  MODEL="$CREATIVE"
elif [ "$1" == "research" ]; then
  MODEL="$RESEARCH"
fi

if [ -n "$2" ]; then
  MAX_ITERATIONS="$2"
fi

echo "Starting Borg - Model: $MODEL, Max Iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo "Borg Agent $i starting iteration. Open tasks: $OPEN_TASKS"

  OUTPUT=$(claude --model "$MODEL" --dangerously-skip-permissions --print < "CLAUDE.md" 2>&1 | tee /dev/stderr) || true

  echo "Borg Agent $i completed its iteration. Open tasks remaining: $OPEN_TASKS"

  OPEN_TASKS=$(grep -c '^\- \[ \]' TODO.md || echo "0")
  if [ "$OPEN_TASKS" -eq 0 ]; then
      echo "All tasks complete"
      exit 0
  fi

  sleep 2
done

echo ""
echo "Borg reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check PROGRESS.md for status."
exit 1

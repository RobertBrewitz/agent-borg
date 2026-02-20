#!/bin/bash
# Symlink all skills into ~/.claude/skills/
# Usage: ./link-skills.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DST="$HOME/.claude/skills"

mkdir -p "$SKILLS_DST"

for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DST/$skill_name"

  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    echo "skip: $target exists and is not a symlink"
    continue
  fi

  ln -s "$skill_dir" "$target"
  echo "linked: $skill_name"
done

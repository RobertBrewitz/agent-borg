#!/bin/bash
# Symlink all skills into ~/.claude/skills/ and the coder subagent into ~/.claude/agents/
# Usage: ./link-skills.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_SRC="$SCRIPT_DIR/agent"
AGENTS_DST="$HOME/.claude/agents"

mkdir -p "$SKILLS_DST" "$AGENTS_DST"

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
  echo "linked skill: $skill_name"
done

for agent_file in "$AGENTS_SRC"/*.md; do
  [ -f "$agent_file" ] || continue
  name="$(basename "$agent_file")"
  case "$name" in
    AGENTS.md|CLAUDE.md) continue ;;
  esac
  target="$AGENTS_DST/$name"

  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    echo "skip: $target exists and is not a symlink"
    continue
  fi

  ln -s "$agent_file" "$target"
  echo "linked agent: ${name%.md}"
done

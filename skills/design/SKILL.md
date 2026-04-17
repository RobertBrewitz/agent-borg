---
name: design
description: You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.
---

# Design

| I/O | Directory |
|-----|-----------|
| Writes | `plans/design/` |

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design in small sections (200-300 words), checking after each section whether it looks right so far.

## Resolve Plans Directory

Before accessing any plan files, resolve the project root and plans directory. The bare repository IS the project root — `git rev-parse --git-common-dir` returns it directly (do NOT go to its parent):

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

All plan paths below use `$PLANS_DIR` as the root.

## The Process

**Understanding the idea:**

- Read `AGENTS.md` in the project root (or git worktree root) first to understand the project context. Do NOT read the contents of files in the `plans/` folder — those are managed by other skills
- Ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria

**Investigate before asking:**

Before asking the user a question, consider whether the answer is already in the codebase. If it might be, look first — read relevant files, grep for patterns, check existing implementations. Only ask the user what can't be answered by reading code.

Examples of things you should look up yourself:
- What frameworks, libraries, or patterns the project already uses
- How similar features are currently implemented
- What data structures, types, or APIs already exist
- File organization and naming conventions
- How tests are structured
- What configuration or infrastructure is in place

Examples of things you should still ask the user:
- Which approach they prefer among trade-offs
- Business requirements, priorities, and constraints
- Whether an existing pattern should be followed or changed
- UX preferences and product decisions
- Scope — what's in and what's out

When you investigate, briefly share what you found ("I see the project already uses X for Y — should we follow that pattern here?"). This shows your work and lets the user correct wrong assumptions early.

**Exploring approaches:**

- Before proposing approaches, explore the codebase to ground your options in what actually exists — existing patterns, dependencies, and constraints should inform your trade-offs, not guesswork
- Propose 2-3 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why

**Presenting the design:**

- Once you believe you understand what you're building, present the design
- Break it into sections of 200-300 words
- Ask after each section whether it looks right so far
- If the user makes changes to a section, present the updated section and re-confirm before moving on
- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

## Working from the Backlog

The project backlog lives at `$PLANS_DIR/backlog/` — one markdown file per task. When starting a design session:

1. List files in `$PLANS_DIR/backlog/` and present them to the user
2. Ask if any backlog items should feed into this design (or "None — new idea")
3. Read the selected backlog files to understand the task context
4. The user may combine multiple backlog tasks into a single design/plan

Keep track of which backlog files fed into the design. Delete the consumed backlog files from `$PLANS_DIR/backlog/` when committing the design document — don't defer this to the plan.

## After the Design

**Documentation:**

- Write the validated design to `$PLANS_DIR/design/<topic>-design.md`
- Commit the design document (run all git commands from `$PLANS_DIR` — it is its own git repo)
- Note: this design file is temporary — it gets deleted once a plan is created from it

**Implementation (if continuing):**

- Ask: "Ready to set up for implementation?"
- Use @write-plan to create detailed implementation plan

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design in sections, validate each
- **Be flexible** - Go back and clarify when something doesn't make sense

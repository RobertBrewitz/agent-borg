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

## The Process

**Understanding the idea:**

- Read `AGENTS.md` in the project root (or git worktree root) first to understand the project context. Do NOT read the entire codebase or browse files until you understand the goal of the design session. Do NOT read the contents of files in the `plans/` folder — those are managed by other skills
- Ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria

**Exploring approaches:**

- Propose 2-3 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why

**Presenting the design:**

- Once you believe you understand what you're building, present the design
- Break it into sections of 200-300 words
- Ask after each section whether it looks right so far
- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

## Working from the Backlog

The project backlog lives at `plans/backlog/` — one markdown file per task. When starting a design session:

1. List files in `$PLANS_DIR/backlog/` and present them to the user
2. Ask if any backlog items should feed into this design (or "None — new idea")
3. Read the selected backlog files to understand the task context
4. The user may combine multiple backlog tasks into a single design/plan

Keep track of which backlog files fed into the design. The resulting plan should include a task that deletes the consumed backlog files from `plans/backlog/` (committed in the plans repo).

## After the Design

**Documentation:**

- Write the validated design to `plans/design/<topic>-design.md`
- Commit the design document (run all git commands from `$PLANS_DIR` — it is its own git repo)
- Note: this design file is temporary — it gets deleted once a plan is created from it

**Implementation (if continuing):**

- Ask: "Ready to set up for implementation?"
- Use writing-plans to create detailed implementation plan

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design in sections, validate each
- **Be flexible** - Go back and clarify when something doesn't make sense

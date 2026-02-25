---
name: write-plan
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Write Plan

| I/O | Directory |
|-----|-----------|
| Reads | `plans/design/` |
| Writes | `plans/draft/` |

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, docs they might need to check, how to verify it compiles. Give them the whole plan as bite-sized tasks. Frequent commits.

- **DRY (Don't Repeat Yourself):** Extract shared logic when duplication is real and proven, not speculative. Three similar lines is fine — a premature abstraction is worse.
- **YAGNI (You Aren't Gonna Need It):** Only build what the current task requires. No "while we're here" extras, no future-proofing hooks, no configurability nobody asked for.
- **No tests.** Never add tests to a plan. No test files, no `#[test]` functions, no test modules. Testing is a separate concern handled outside the plan pipeline.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the write-plan skill."

## Resolve Plans Directory

Before accessing any plan files, resolve the project root and plans directory. The bare repository IS the project root — `git rev-parse --git-common-dir` returns it directly (do NOT go to its parent):

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

All plan paths below use `$PLANS_DIR` as the root.

## First: New or Existing?

Before doing anything else, use `AskUserQuestion` to prompt:

- **Question:** "New plan or existing?"
- **Options:** "Write new plan" / "Revise existing plan"

Then:

- **If new:** Check `$PLANS_DIR/design/` for existing design documents from `/design`. If any exist, list them and ask which design to use as input (or "None — start from scratch"). Read the selected design doc before proceeding — it contains the validated requirements and architecture decisions.

  Then ask: "Single file or multi-stage folder?" Options: "Single file" / "Multi-stage folder".
  - **Single file:** Save to `$PLANS_DIR/draft/<feature-name>.md`.
  - **Folder:** Create `$PLANS_DIR/draft/<feature-name>/` with numbered stage files (`01-setup.md`, `02-core.md`, etc.). Each stage is a self-contained plan with its own header and tasks. Group related tasks into stages by logical phase (setup, core logic, integration, polish, etc.).
- **If existing:** List all `.md` files and subdirectories in `$PLANS_DIR/draft/`. Use `AskUserQuestion` to prompt which plan to work on (list the names as options). Then read the chosen plan (all stage files for folders) and ask what changes are needed. Revise following all the conventions below.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**

- "Write the implementation code" - step
- "Run `cargo check` to verify it compiles" - step
- "Commit" - step

## Gather agent skills (REQUIRED — your primary source of codebase knowledge)

**Ask the human:** "What agent skills should I use for this plan?"

Skills live in `~/.claude/skills/` (global) and `./.claude/skills/` (project-local). No other search paths exist.

Read every provided skill (`skills/<name>/SKILL.md`). These are your primary reference for:

- File paths and line ranges
- Struct/function names and signatures
- Module layout and architecture
- Existing patterns and conventions

**You MAY also read source code, Grep, and Glob** to fill gaps, verify details, or understand context that skills don't cover. Skills-first, code as needed — but never guess paths or APIs when you can look them up.

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILLS: [comma-separated list of agent skills used in this plan with @ syntax]

**Goal:** [One sentence describing what this builds]

**Branch:** branch-name (no backticks — plain text only, parsed by hive.sh)

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

**Branch field:** Before writing the plan, check `git worktree list` and `git branch` to see if an existing branch matches this work. If the plan continues or builds on a prior plan's branch, use that branch name. Otherwise pick a new descriptive name. Hive and coder use this field to determine which worktree to run in.

## Task Structure

All tasks use `### Task N:` headings and `**Step N:**` bold labels for steps. No other heading levels inside tasks. **Never include test files or test code.**

````markdown
### Task N: [Component Name]

**Files:**

- Create: `exact/path/to/file.rs`
- Modify: `exact/path/to/existing.rs:123-145`

**Step 1: Write the implementation**

```rust
pub fn function(input: Type) -> ReturnType {
    // complete code here
}
```

**Step 2: Verify**

Run: `cargo fmt && cargo check`
Expected: PASS

**Step 3: Commit**

Run: `git add src/path/file.rs && git commit -m "feat: add specific feature"`
````

## Backlog Cleanup

If any backlog files from `plans/backlog/` were used as input for this plan (directly or via a design session), include a task in the plan that deletes the consumed backlog files:

1. Delete the consumed files from `$PLANS_DIR/backlog/`
2. Any new out-of-scope work discovered during planning should be created as new backlog files (see CLAUDE.md Backlog Items format)
3. Commit in the plans repo (`$PLANS_DIR`)

This task should typically be the last task in the plan.

## Skill Gap Report

After saving the plan, if you read any source code (Read, Grep, Glob) to fill gaps not covered by skills, append a **Skill Gap Report** section at the bottom of the plan:

```markdown
---

## Skill Gap Report

The following were looked up from source code because no skill covered them:

- **`src/engine/input.rs`** — `InputState` struct fields and `process_events()` signature. Needed for Task 3.
- **`src/engine/physics.rs:45-80`** — `PhysicsWorld::step()` method and collision callback pattern. Needed for Tasks 5-6.
```

Each entry should note the file/symbol looked up and which task needed it. This tells the user which skills to create for future plans.

## Cleanup

After saving the plan:

1. Check if a design document exists for this feature (e.g. `$PLANS_DIR/design/<topic>-design.md` or `$PLANS_DIR/design/<topic>-design/`). If one exists, delete it.
2. Check if any review files exist for this plan (e.g. `$PLANS_DIR/review/<plan-name>-self-review.md`). If any exist, delete them — they're stale after a rewrite.
3. Commit all deletions. Run all git commands from `$PLANS_DIR` — it is its own git repo.

## Remember

- Exact file paths always (sourced from skills, never guessed)
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, no tests (see definitions in Overview), frequent commits
- Skills first, then read code to fill gaps — never guess when you can look it up
- Plans may have bugs — always read the relevant skills before implementing, even if a plan provides exact code

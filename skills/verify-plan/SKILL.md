---
name: verify-plan
description: Use when reviewing a plan before execution, dry-running a plan to check feasibility, or validating that a plan follows writing-plans conventions and that references match loaded agent skills
---

# Verify Plan

| I/O | Directory |
|-----|-----------|
| Reads | `plans/draft/` |
| Writes | `plans/draft/` (rewritten plans), `plans/todo/` (promoted plans) |

## Overview

Review-and-rewrite gate that checks a plan for structural quality AND codebase feasibility, fixes any issues found, and promotes passing plans. This is a single-pass workflow: review → rewrite → re-verify → promote.

**Announce at start:** "I'm using the verify-plan skill to review this plan."

## When to Use

- After `write-plan` creates a plan, before handing it off for execution
- When resuming a plan written by a different agent or in a previous session
- When a plan has been edited and needs re-verification

## Resolve Plans Directory

Before accessing any plan files, resolve the project root and plans directory. The bare repository IS the project root — `git rev-parse --git-common-dir` returns it directly (do NOT go to its parent):

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

All plan paths below use `$PLANS_DIR` as the root.

## Invocation

1. Accept plan path as argument, OR list `$PLANS_DIR/draft/` and ask which to verify. List both `.md` files and subdirectories (folder plans).
2. Read the full plan file (for folder plans, read all stage files in numeric order).
3. Collect all `@skill-name` references from the plan. Skills live in `~/.claude/skills/` (global) and `./.claude/skills/` (project-local) — no other search paths exist. For each, read the skill's `SKILL.md` to understand what the skill provides. This context informs both passes — structural review can verify skills are referenced correctly, and feasibility review can check that the plan uses skill APIs/patterns that actually exist.
4. Run Pass 1 (structural), then Pass 2 (feasibility)
5. If Pass 2 encounters references not covered by any loaded skill, **read source code, Grep, or Glob** to verify them directly. Only mark UNVERIFIABLE if you can't confirm via skills OR code.
6. Print the report
7. If any non-PASS issues found, rewrite the plan (see **Rewrite Phase** below), then re-verify

## Pass 1 — Structural Review

Check against `writing-plans` conventions. For each item, assign PASS, FAIL, or WARN.

**Header checks:**

| Check        | What to look for                                            |
| ------------ | ----------------------------------------------------------- |
| Title        | `# [Feature Name] Implementation Plan`                      |
| Sub-skills   | `> **For Claude:** REQUIRED SUB-SKILLS:` with @ syntax refs |
| Goal         | `**Goal:**` — one sentence                                  |
| Branch       | `**Branch:**` — valid branch name. If branch exists, verify it's a worktree. If new, verify it doesn't collide with an existing branch. |
| Architecture | `**Architecture:**` — 2-3 sentences                         |
| Tech Stack   | `**Tech Stack:**` present                                   |
| Separator    | `---` after header                                          |

**Per-task checks:**

| Check               | What to look for                                                                                                                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Task heading        | `### Task N: [Component Name]` (always H3, no other heading levels inside tasks)                                                                                                                                               |
| Step labels         | `**Step N: ...**` (bold text, not headings)                                                                                                                                                                                    |
| Files section       | `**Files:**` with Create/Modify/Test lines                                                                                                                                                                                     |
| Modify line ranges  | `file.rs:123-145` format (not bare paths)                                                                                                                                                                                      |
| TDD cycle           | TDD tasks: 5 steps — write test → run (expect FAIL) → implement → run (expect PASS) → commit. Non-TDD tasks (wiring, config, imports, formatting): change → verify (`cargo check`) → commit (3 steps). Both formats are valid. |
| Single-action steps | Each step is one action, not compound                                                                                                                                                                                          |
| Complete code       | No placeholder comments ("add logic here", "implement this", "TODO")                                                                                                                                                           |
| Run/Expected pairs  | Every `Run:` has a corresponding `Expected:`                                                                                                                                                                                   |
| Skill @ refs        | Skills referenced with `@skill-name` syntax                                                                                                                                                                                    |

## Pass 2 — Feasibility Review

Verify the plan against loaded skills first. **You MAY also read source code, Grep, and Glob** to fill gaps, verify file existence, check signatures, or confirm details that skills don't cover. Skills-first, code as needed.

For each item, assign PASS, BLOCKER, WARN, or UNVERIFIABLE.

| Check                            | How to verify                                                             |
| -------------------------------- | ------------------------------------------------------------------------- |
| `Modify:` paths exist            | Check skill first, then Glob/Read to confirm                              |
| `Create:` paths do NOT exist     | Check skill first, then Glob to confirm path is new                       |
| Struct/function refs correct     | Check skill first, then Grep/Read to verify types/signatures              |
| @ skill refs exist               | `skills/<name>/SKILL.md` can be read                                      |
| API usage matches skill          | Code in plan matches patterns/signatures from skill or source             |
| References not covered by skills | Read source code to verify — only UNVERIFIABLE if you truly can't confirm |

**Important:** When checking `Create:` paths, account for files created by earlier tasks in the same plan.

## Severities

- **BLOCKER** — Will cause execution to fail. Must fix.
- **WARNING** — Likely problem. Should review.
- **NOTE** — Suggestion for improvement.
- **UNVERIFIABLE** — No skill covers this reference. Ask the user for a skill before proceeding.

## Output Format

Print the report to the conversation. For folder plans, review each stage separately and print a combined summary at the end.

```
## Plan Verification: <filename>

### Structural Review

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | Header: Goal | PASS | |
| 2 | Header: Sub-skills | FAIL | Missing > **For Claude:** line |
| ... | ... | ... | ... |

### Feasibility Review

| # | Reference | Status | Detail |
|---|-----------|--------|--------|
| 1 | Modify: `src/engine/camera.rs` | PASS | Exists (248 lines) |
| 2 | Create: `src/engine/input.rs` | BLOCKER | Already exists |
| ... | ... | ... | ... |

### Summary

- **BLOCKER:** N
- **WARNING:** N
- **UNVERIFIABLE:** N
- **NOTE:** N
- **PASS:** N

**Verdict: READY / REVIEW / NOT READY / NEEDS SKILLS**
```

### Skill Gap Report

If you read any source code (Read, Grep, Glob) to verify references not covered by skills, add this section to the report:

```
### Skill Gap Report

The following were verified from source code (no skill covered them):

- **`src/engine/input.rs`** — verified `InputState` struct exists (Task 3 references it)
- **`src/engine/physics.rs:45-80`** — verified `PhysicsWorld::step()` signature (Tasks 5-6)
```

Each entry should note the file/symbol looked up and which plan reference needed it. This tells the user which skills to create for future plans.

**Verdict rules:**

- **READY** — zero blockers, zero warnings, zero unverifiable
- **REVIEW** — zero blockers, has warnings (no unverifiable)
- **NEEDS SKILLS** — has unverifiable items (list what skills are needed)
- **NOT READY** — has blockers

## Rewrite Phase

If the verdict is anything other than **READY**, rewrite the plan to fix all issues. This is the core of the skill — don't punt fixes back to the user.

**What to fix:**

- **BLOCKERs** — Must fix. Wrong paths → correct them. Missing files → update Create/Modify lines. Wrong signatures → look up the real ones from skills or code and update.
- **FAILs** (structural) — Must fix. Missing header fields → add them. Wrong heading levels → correct them. Missing Run/Expected pairs → add them. Placeholder code → write real code.
- **WARNINGs** — Should fix. Bare paths without line ranges → add ranges. Compound steps → split them.
- **NOTEs** — Fix if straightforward, skip if subjective.
- **UNVERIFIABLE** — Cannot fix without more information. Leave these and flag to user.

**Rewrite rules:**

1. Follow all `write-plan` conventions (task structure, TDD cycle, header format, etc.)
2. Use loaded skills and source code as reference — same sources you used during review
3. Rewrite in-place: overwrite the plan file in `$PLANS_DIR/draft/`
4. For folder plans, rewrite only the stage files that had issues
5. No review files to clean up — reports are only printed to the conversation

**After rewriting, re-verify:**

Run both passes again on the rewritten plan. Print a new report. This loop repeats until the plan reaches READY or NEEDS SKILLS (the only verdicts that can't be self-fixed).

**Maximum 2 rewrite cycles.** If the plan still isn't READY after 2 rewrites, stop and show the user the remaining issues. Something fundamental is wrong that needs human input.

## Promotion Gate

After the final verdict, act on it:

- **READY** — Move the plan from `draft/` to `todo/`. Commit the move. Run all git commands from `$PLANS_DIR` — it is its own git repo.
- **NEEDS SKILLS** — Leave the plan in `draft/`. List the specific skills needed and ask the user to provide them before re-running verification.
- **NOT READY after 2 rewrites** — Leave the plan in `draft/`. Show the remaining issues and ask the user for guidance.

This is the only gate between `draft/` and `todo/`. Plans must pass verification to reach `todo/`.

## Red Flags

**Never:**

- Execute any plan steps
- Run cargo or other build commands
- Skip Pass 2 because "the plan looks fine structurally"
- Guess whether a path or API exists — look it up via skills or code
- Rewrite without re-verifying — every rewrite gets a fresh review

**Always:**

- Run both passes, even if Pass 1 finds issues
- Check every `Modify:` and `Create:` path against loaded skills and/or source code, not just a sample
- Account for files created by earlier tasks when checking `Create:` paths
- Report the full table, including PASSes (gives confidence in thoroughness)
- Use skills first, then read code to fill gaps — never guess when you can look it up
- Rewrite the plan to fix issues rather than telling the user to do it
- Remind the implementer: plans may have bugs — always read the relevant skills before implementing, even if a plan provides exact code

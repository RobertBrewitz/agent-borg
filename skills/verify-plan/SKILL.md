---
name: verify-plan
description: Use when reviewing a plan before execution, dry-running a plan to check feasibility, or validating that a plan follows writing-plans conventions and that references match loaded agent skills
---

# Verify Plan

## Overview

Dry-run review that checks a plan for structural quality AND codebase feasibility before execution. Read-only — does not modify files, execute steps, or run commands.

**Announce at start:** "I'm using the verify-plan skill to review this plan."

## When to Use

- After `writing-plans` creates a plan, before handing it off for execution
- When resuming a plan written by a different agent or in a previous session
- When a plan has been edited and needs re-verification

**Do NOT use for:** Writing or fixing plans — use `writing-plans` for that.

## Resolve Plans Directory

Before accessing any plan files, resolve the project root and plans directory. The bare repository IS the project root — `git rev-parse --git-common-dir` returns it directly (do NOT go to its parent):

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

All plan paths below use `$PLANS_DIR` as the root.

## Invocation

1. Accept plan path as argument, OR list `$PLANS_DIR/draft/` and `$PLANS_DIR/todo/` and ask which to verify. When listing, also check `$PLANS_DIR/review/` for existing reviews. Mark each plan as **new** (no review exists) or **reviewed** (review file exists). Show this status in the options so the user knows which plans have already been reviewed. Prefer surfacing unreviewed plans first.
2. Read the full plan file. If a review already exists for this plan, read it too — compare against the current plan to note whether the plan has changed since the last review (e.g. different line count, modified timestamp). If unchanged, ask the user whether to re-verify or skip.
3. Collect all `@skill-name` references from the plan. Skills live in `~/.claude/skills/` (global) and `./.claude/skills/` (project-local) — no other search paths exist. For each, read the skill's `SKILL.md` to understand what the skill provides. This context informs both passes — structural review can verify skills are referenced correctly, and feasibility review can check that the plan uses skill APIs/patterns that actually exist.
4. Run Pass 1 (structural), then Pass 2 (feasibility)
5. If Pass 2 encounters references not covered by any loaded skill, **read source code, Grep, or Glob** to verify them directly. Only mark UNVERIFIABLE if you can't confirm via skills OR code.
6. Print the report

## Pass 1 — Structural Review

Check against `writing-plans` conventions. For each item, assign PASS, FAIL, or WARN.

**Header checks:**

| Check        | What to look for                                            |
| ------------ | ----------------------------------------------------------- |
| Title        | `# [Feature Name] Implementation Plan`                      |
| Sub-skills   | `> **For Claude:** REQUIRED SUB-SKILLS:` with @ syntax refs |
| Goal         | `**Goal:**` — one sentence                                  |
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

Print the report to the conversation AND save it to `$PLANS_DIR/review/<plan-filename>` (e.g. if the plan is `2026-02-06-feature.md`, save the review to `$PLANS_DIR/review/2026-02-06-feature.md`). Create the `review/` directory if it doesn't exist.

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

## Red Flags

**Never:**

- Modify the plan file
- Execute any plan steps
- Run cargo or other build commands
- Write any files other than the review file in `$PLANS_DIR/review/`
- Skip Pass 2 because "the plan looks fine structurally"
- Guess whether a path or API exists — look it up via skills or code

**Always:**

- Run both passes, even if Pass 1 finds issues
- Check every `Modify:` and `Create:` path against loaded skills and/or source code, not just a sample
- Account for files created by earlier tasks when checking `Create:` paths
- Report the full table, including PASSes (gives confidence in thoroughness)
- Use skills first, then read code to fill gaps — never guess when you can look it up

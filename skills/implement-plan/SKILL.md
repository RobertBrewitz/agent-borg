---
name: implement-plan
description: Interactive plan execution with user checkpoints between tasks. More collaborative than borg.sh — user can steer, skip, modify, or course-correct mid-flight.
---

# Implement Plan

| I/O | Directory |
|-----|-----------|
| Reads | `plans/todo/` |
| Writes | `plans/done/` |

## Overview

Execute a verified plan step-by-step inside an interactive Claude Code session. Unlike `borg.sh` (headless, autonomous looping), this skill keeps the user in the loop with checkpoints between tasks. The user can review results, modify approach, skip tasks, or course-correct at any time.

**Announce at start:** "I'm using the implement-plan skill."

## When to Use

- User wants to execute a plan with oversight
- Plan needs human judgment at decision points
- First time running a plan (want to validate the approach interactively before trusting it to borg.sh)
- Resuming a blocked plan that needs human input

**Use borg.sh instead when:** The plan is verified, trusted, and the user wants fully autonomous execution.

## Resolve Plans Directory

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

## Phase 1: Select Plan

List plans from `$PLANS_DIR/todo/` and `$PLANS_DIR/in-progress/`. Show both `.md` files and subdirectories (folder plans). For each, check `$PLANS_DIR/progress/<plan-name>.md` to indicate whether it's resumable.

**Note:** `in-progress/` is internal resume state — plans move there automatically when execution begins. It is not an input directory.

Use `AskUserQuestion` to prompt:

- **Question:** "Which plan should we execute?"
- **Options:** List plan names with status annotations:
  - `add-feature (todo)` — fresh start
  - `add-feature (in-progress, step 4/12)` — resumable

If no plans exist in `todo/` or `in-progress/`, tell the user and suggest using `write-plan` first.

## Phase 2: Load Context

1. Read the full plan (all stage files for folder plans).
2. Collect all `@skill-name` references. Read each skill's `SKILL.md`.
4. Read `agent/AGENTS.md` for patterns and gotchas.
5. If a progress file exists at `$PLANS_DIR/progress/<plan-name>.md`, read it and determine resume point.

**Present a summary to the user:**

```
Plan: <name>
Tasks: <N> (stages: <M> if folder plan)
Skills: @skill1, @skill2, ...
Resume: Starting fresh / Resuming at Task <N>, Step <M>
Warnings: <any unresolved review warnings, or "None">
```

Use `AskUserQuestion`:

- **Question:** "Ready to start? Any concerns or modifications before we begin?"
- **Options:** "Start executing" / "Let me review the plan first" / "Modify the plan first"

If "review" — show the plan contents and wait for the go-ahead.
If "modify" — suggest using `write-plan` to revise, then come back.

## Phase 3: Workspace Setup

Check if we're already in the correct worktree for this plan.

**If a progress file exists** with a worktree path, verify that worktree still exists and is on the correct branch.

**If no worktree exists:**

- Use `AskUserQuestion`:
  - **Question:** "This plan needs a worktree. How should we set it up?"
  - **Options:** "Create new worktree (recommended)" / "Use current workspace"

- If creating a worktree, use the `@using-git-worktrees` skill to set one up. Use the plan name as the branch name (e.g., `add-feature`).

**If using current workspace:** Confirm with the user that uncommitted changes won't conflict.

## Phase 4: Execute Plan

Move plan from `todo/` to `in-progress/` (if not already there). Create or update the progress file. Run all plan-directory git commands from `$PLANS_DIR` — it is its own git repo, separate from the project repo.

### Task Loop

For each task (respecting resume point if resuming):

#### 4a. Preview

Show the user what's about to happen:

```
--- Task <N>/<Total>: <Task Name> ---
Files: <list from plan>
Steps: <count>
Type: TDD / Non-TDD
```

Use `AskUserQuestion`:

- **Question:** "Execute this task?"
- **Options:** "Go ahead" / "Skip this task" / "Let me modify the approach" / "Stop here for now"

- **"Skip":** Mark task as skipped in progress notes, move to next task.
- **"Modify":** Ask the user what they want to change. Adjust the approach for this task only (don't modify the plan file). Execute the modified version.
- **"Stop":** Update progress file with current position and exit gracefully.

#### 4b. Execute Steps

Execute each step in the task sequentially:

1. **Read the relevant skills** listed in the plan header before implementing — plans may have bugs, skills are the source of truth.
2. Follow the step instructions from the plan.
3. After implementation steps, run verification: the project's build/test commands (e.g., `cargo fmt && cargo check && cargo test`, `npm test`, etc.). Use whatever the plan specifies in its Run/Expected pairs.
4. Show the user the result (pass/fail, test output summary).

**On step failure:**

Do NOT silently retry 3 times like borg.sh. Instead:

- Show the error clearly.
- Use `AskUserQuestion`:
  - **Question:** "Step failed. How should we proceed?"
  - **Options:** "Fix it and retry" / "Skip this step" / "Modify the approach" / "Stop and mark as blocked"

- **"Fix it":** Diagnose the issue, propose a fix, implement it with user approval, then retry.
- **"Skip":** Move to next step, note in progress.
- **"Modify":** Discuss alternative approach with user, execute that instead.
- **"Block":** Move plan to `blocked/`, update progress file with failure context.

#### 4c. Commit

After each task completes (all steps pass):

- Stage and commit the changes with an appropriate message.
- Show the user the commit summary.

#### 4d. Checkpoint

After committing, update the progress file and present:

```
--- Checkpoint: Task <N>/<Total> complete ---
Committed: <git hash> - <message>
Next: Task <N+1>: <name>
Progress: <N>/<Total> tasks done
```

Use `AskUserQuestion`:

- **Question:** "Continue to next task?"
- **Options:** "Continue" / "Take a break (progress saved)" / "Review what we've done"

- **"Break":** Update progress file, tell user how to resume (`/implement-plan` and pick the in-progress plan).
- **"Review":** Show git log of commits made this session, then ask again.

### Stage Transitions (folder plans only)

When all tasks in a stage are complete, before starting the next stage:

```
--- Stage <N> complete, starting Stage <N+1>: <stage-name> ---
```

Show stage summary and ask to continue (same checkpoint pattern).

## Phase 5: Completion

When all tasks (and stages) are done:

1. **Test cleanup:** Review all tests written during this plan. Delete any no-op tests that just restate the implementation (e.g. asserting a constant equals itself, checking a struct field exists, testing language guarantees). TDD scaffolding tests that were useful during development but are trivially true after implementation should be removed. Commit the cleanup separately.
2. Run a final verification (full test suite).
3. Move plan from `in-progress/` to `done/`.
4. Delete the progress file.
5. Show summary:

```
Plan complete: <name>
Tasks: <N> completed, <M> skipped
Commits: <count>
Branch: <branch-name>
```

6. Ask: "Want to merge to main now, or leave in done/ for later? (Use `/merge-plan` to build a merge plan, then `/merge` to execute it.)"

## Progress File Format

Same format as CLAUDE.md specifies, with additional interactive notes:

```markdown
# Progress: <plan-name>

- **Worktree:** `<path>`
- **Stage:** 02-core.md (omit for single-file plans)
- **Last completed task:** 3
- **Next task:** 4
- **Git hash:** abc1234
- **Skipped tasks:** 2 (reason: user decided to handle manually)
- **Notes:** <context for resume>
```

## Gotchas and Shared Knowledge

During execution, if you discover patterns or gotchas:

- Append to `agent/AGENTS.md` (same format as CLAUDE.md specifies).
- If you discover out-of-scope work, append to `BACKLOG.md` in the feature branch (not main). Tell the user what you added.
- Tell the user when you add entries to AGENTS.md.

## Red Flags

**Never:**

- Execute steps without showing the user what you're about to do
- Silently retry failures — always involve the user
- Modify the plan file during execution (note deviations in progress file instead)
- Skip the initial context-loading phase
- Proceed past a failed step without user decision
- Commit without showing the user what's being committed

**Always:**

- Read skills before implementing (even if the plan has exact code)
- Show checkpoint summaries between tasks
- Save progress before stopping (user can resume later)
- Give the user the option to stop, skip, or modify at every checkpoint
- Run verification after every implementation step

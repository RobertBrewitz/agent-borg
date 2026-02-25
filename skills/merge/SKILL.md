---
name: merge
description: Interactive merge execution with human checkpoints. Reads merge plans from plans/merge/, squash-merges feature branches into main via integration branch, archives completed plans.
---

# Merge

| I/O | Directory |
|-----|-----------|
| Reads | `plans/merge/` |
| Writes | `plans/archive/` |

## Overview

Execute a merge plan interactively with human checkpoints at every critical step. Squash-merge feature branches into an integration branch, verify, land on main, then archive source plans and clean up worktrees.

**Announce at start:** "I'm using the merge skill."

**Never polled by hive.sh.** Merges always require human oversight.

## Resolve Paths

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

## Phase 1: Select Merge Plan

List all plans in `$PLANS_DIR/merge/`. Use `AskUserQuestion` to prompt which merge plan to execute.

If no merge plans exist, tell the user to run `/merge-plan` first to create one.

## Phase 2: Load and Present

1. Read the full merge plan.
2. Show the user a summary: integration branch name, branches to merge (in order), conflict expectations.
3. Use `AskUserQuestion`:
   - **Question:** "Ready to start the merge?"
   - **Options:** "Start" / "Let me review the plan first" / "Abort"

## Phase 3: Execute Merge Plan

Follow the merge plan task-by-task (same pattern as implement-plan):

### For each task:

#### 3a. Preview

Show what's about to happen (which branch, expected conflicts).

Use `AskUserQuestion`:
- **Question:** "Execute this merge step?"
- **Options:** "Go ahead" / "Skip" / "Modify approach" / "Stop here"

#### 3b. Execute

1. Run the squash-merge command from the plan.
2. If conflicts occur:
   - Show the conflicts clearly.
   - Follow the plan's resolution instructions.
   - Show the resolved result to the user before committing.
3. Run verification (build + tests) after each merge.
4. Show results to the user.

#### 3c. Checkpoint

After each successful merge + commit:

```
--- Merged: <branch> (<N>/<Total>) ---
Commit: <hash> - <message>
Tests: PASS
Next: <next-branch or "Land on main">
```

Use `AskUserQuestion`:
- **Question:** "Continue?"
- **Options:** "Continue" / "Stop here (progress noted)" / "Review what we've done"

**On failure:**

- Show the error clearly.
- Use `AskUserQuestion`:
  - **Question:** "Merge step failed. How should we proceed?"
  - **Options:** "Fix and retry" / "Skip this branch" / "Abort merge"

- **"Fix and retry":** Diagnose, propose fix, get user approval, retry.
- **"Skip":** Note the skipped branch, continue with next.
- **"Abort":** Leave the integration branch as-is, tell user how to resume or clean up.

## Phase 4: Land on Main

After all feature branches are merged into the integration branch:

1. Run final verification (full test suite).
2. Show the user the complete diff: `git diff main...integrate/<name> --stat`.
3. Use `AskUserQuestion`:
   - **Question:** "All branches merged and tests pass. Land on main?"
   - **Options:** "Merge to main" / "Let me inspect first" / "Abort"

4. If approved, build the changes summary (see Phase 5 for format) and use it as the `--no-ff` merge commit message.
5. Verify main passes tests.

## Phase 5: Archive and Clean Up

After landing on main:

1. Move each source plan from `done/` to `archive/`.
2. Move the merge plan from `merge/` to `archive/`.
3. Remove feature worktrees then branches — order matters (worktree must be removed before branch can be deleted). Use `git worktree remove --force` then `git branch -D` — force is required because squash-merges leave worktree state and git can't detect squashed branches as merged.
4. Remove integration worktree then branch (same order, same flags).
5. Commit the plan moves (run all plan-directory git commands from `$PLANS_DIR` — it is its own git repo, separate from the project repo).

Write a **changes summary** for the merge commit message and final output. Read each merged plan's goal/description and the squash commit messages. Format as a short title line naming the merged features, followed by one paragraph per feature describing what actually changed. This goes in both the `--no-ff` merge commit message and the final output shown to the user.

Example:

```
integrate: feature-a + feature-b

- Feature A: short description of what changed and why. Mention new
  APIs added, old code removed, and behavioral differences.

- Feature B: short description of what changed and why. Mention new
  APIs added, old code removed, and behavioral differences.
```

After the summary, show cleanup info:

```
Plans archived: <list>
Worktrees removed: <list>
Main: <git hash> — tests pass
```

## Red Flags

**Never:**
- Merge directly into main without an integration branch
- Force push to main
- Delete worktrees before verifying the merge on the integration branch
- Auto-resolve conflicts without showing the user
- Skip test verification after any merge step
- Proceed past a failure without user decision

**Always:**
- Show every conflict resolution to the user
- Run tests after each merge step
- Get explicit user approval before landing on main
- Keep worktrees until main is updated and verified
- Archive plans only after successful landing on main

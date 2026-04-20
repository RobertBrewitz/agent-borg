---
name: merge
description: Merge completed feature branches into main. Discovers done plans, analyzes diffs, squash-merges each feature onto an integration branch, then squash-merges into main. Stops only on uncertain conflicts or before landing on main.
---

# Merge

| I/O | Directory |
|-----|-----------|
| Reads | `plans/done/` |
| Writes | `plans/archive/` |

## Overview

End-to-end merge: discover done plans, match to worktree branches, analyze diffs and conflicts, squash-merge each feature onto an integration branch, then merge into main. One commit per feature is preserved on main.

**Announce at start:** "I'm using the merge skill."

## Plan Directory

See `@plan-directory` for the shared `plans/` layout, lifecycle, and nested-git-repo rule.

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

## Phase 1: Discover Merge Candidates

### 1a. List Done Plans

```bash
ls "$PLANS_DIR/done/"
```

### 1b. Match Plans to Branches

```bash
git worktree list
```

Match plan names to branch names (e.g., `selective-mulligan.md` → branch `mulligan` or `selective-mulligan`). Use fuzzy matching (strip common prefixes/suffixes, check substrings).

**No matching branch:** Note as "already merged or branch deleted" — skip it.

### 1c. Select Plans

- **One candidate:** Auto-select, no prompt.
- **Multiple candidates:** Use `AskUserQuestion` with `multiSelect: true`:
  - **Question:** "Which completed plans should be included in this merge?"
  - **Options:** List each plan with its matched branch name.
- **Zero candidates:** Tell the user there's nothing to merge and stop.

## Phase 2: Analyze Diffs

For each selected branch:

### 2a. Diff Against Main

```bash
git diff main...<branch> --stat
git diff main...<branch> --name-only
```

### 2b. Commit History

```bash
git log main..<branch> --oneline
```

### 2c. Read the Done Plan

Read the plan file (or all stage files for folder plans) to understand the intent.

### 2d. Build the Conflict Map

Find files touched by multiple branches. For each overlap, classify:

- **Compatible:** Different regions of the file (likely auto-merge)
- **Overlapping:** Same lines modified (manual resolution needed)
- **Semantic:** Different regions but logically interdependent (e.g., both add items to the same enum)

```bash
git diff main...<branch1> -- <file>
git diff main...<branch2> -- <file>
```

## Phase 3: Determine Merge Order

Order branches by conflict minimization:

1. **No conflicts** — merge first
2. **Compatible conflicts only** — merge next
3. **Overlapping/semantic conflicts** — merge last, fewest conflicts first

**Dependency check:** If branch B references symbols/files that only exist in A's diff, A must merge first.

Show the user a summary of the merge order and conflict expectations before proceeding.

## Phase 4: Create Integration Branch

**Naming:** Join branch names with `-`, append `-merge`. Example: branches `audio-player` and `selective-mulligan` → `audio-player-selective-mulligan-merge`.

```bash
git worktree add $PROJECT_ROOT/integrate-<name> -b integrate/<name> main
cd $PROJECT_ROOT/integrate-<name>
```

Verify clean baseline:

```bash
cargo fmt && cargo check && cargo test
```

## Phase 5: Squash-Merge Each Feature

For each branch (in merge order):

### 5a. Squash-Merge

```
Merging: <branch> (<N>/<Total>)
```

```bash
cd $PROJECT_ROOT/integrate-<name>
git merge --squash <branch>
```

### 5b. Handle Conflicts

- **No conflicts or compatible conflicts:** Auto-resolve, show summary.
- **Unexpected or semantic conflicts:** STOP and use `AskUserQuestion`:
  - **Question:** "Unexpected conflict in `<file>`. How should I proceed?"
  - **Options:** "Show me the conflict" / "Try auto-resolve" / "Skip this branch" / "Abort"

### 5c. Verify and Commit

```bash
cargo fmt && cargo check && cargo test
git commit -m "feat: <plan-name> (squashed from <branch>)

<2-4 line summary of what the feature does, derived from the done plan>"
```

Show compact status and auto-continue:

```
[N/Total] Merged: <branch> — tests pass
```

### 5d. On Failure

If build or tests fail:

1. Attempt to diagnose and fix (up to 2 attempts).
2. If still failing, use `AskUserQuestion`:
   - **Question:** "Merge of `<branch>` broke the build. How should we proceed?"
   - **Options:** "Let me fix it manually" / "Skip this branch" / "Abort merge"

## Phase 6: Land on Main

1. Run final verification on integration branch.
2. Show the squash commits on the integration branch and the overall diff:
   ```bash
   git log main..integrate/<name> --oneline
   git diff main...integrate/<name> --stat
   ```
3. Use `AskUserQuestion`:
   - **Question:** "All branches merged and tests pass. Land on main?"
   - **Options:** "Merge to main" / "Let me inspect first" / "Abort"
4. If approved, squash-merge into main:
   ```bash
   cd $PROJECT_ROOT/main
   git merge --squash integrate/<name>
   git commit -m "integrate: <feature-a> + <feature-b>

   - Feature A: summary of changes from done plan
   - Feature B: summary of changes from done plan"
   ```
5. Verify main passes tests.

## Phase 7: Archive and Clean Up

Proceed automatically after landing:

1. Move each source plan from `done/` to `archive/`.
2. Remove feature worktrees then branches (order matters — worktree first, then branch):
   ```bash
   git worktree remove --force $PROJECT_ROOT/<branch>
   git branch -D <branch>
   ```
3. Remove integration worktree then branch (same order, same flags).
4. Commit the plan moves in the plans repo.

Show final output:

```
Plans archived: <list>
Worktrees removed: <list>
Main: <git hash> — tests pass
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Done plan, no matching branch | Skip — already merged or deleted |
| No conflicts between branches | Merge in any order, all clean |
| Compatible conflicts (different regions) | Auto-resolve, show summary |
| Overlapping conflicts (same lines) | Stop, ask user |
| Semantic conflicts (logically related) | Stop, ask user |
| Branch depends on another branch | Merge dependency first |
| Build/test failure after merge | Try to fix (2 attempts), then ask user |

## Red Flags

**Never:**
- Merge directly into main — always use an integration branch
- Force push to main
- Delete worktrees before verifying the merge on the integration branch
- Auto-resolve semantic/unexpected conflicts without asking
- Skip reading the done plans
- Merge branches out of dependency order
- Skip test verification after any merge step

**Always:**
- Create an integration branch from main first
- Read each done plan before analyzing its diff
- Run tests after each squash-merge
- Squash each feature individually (one commit per feature on integration branch)
- Get user approval before landing on main
- Keep worktrees until main is updated and verified
- Archive plans only after successful landing

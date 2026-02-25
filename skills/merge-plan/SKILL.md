---
name: merge-plan
description: Use when completed plans in done/ need to be merged into main, when multiple worktree branches need integration, or when preparing a merge plan that handles cross-branch conflicts
---

# Merge Plan

| I/O | Directory |
|-----|-----------|
| Reads | `plans/done/` |
| Writes | `plans/merge/` |

## Overview

Read completed plans from `plans/done/`, diff each corresponding worktree branch against main, identify cross-branch conflicts, and write a merge plan. All merges happen on a dedicated integration branch — main is never touched directly until everything is verified.

**Announce at start:** "I'm using the merge-plan skill to build a merge plan."

## Resolve Paths

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

## Phase 1: Discover Merge Candidates

### 1a. List Done Plans

List all plans in `$PLANS_DIR/done/` (files and folders). These are completed plans with implemented branches.

### 1b. Match Plans to Branches

For each done plan, find the corresponding worktree branch:

```bash
git worktree list
```

Match plan names to branch names (e.g., `selective-mulligan.md` → branch `mulligan` or `selective-mulligan`). Branch names may not exactly match plan names — use fuzzy matching (strip common prefixes/suffixes, check substrings).

**If a done plan has no matching worktree branch:** Note it as "already merged or branch deleted" — skip it.

### 1c. Select Plans to Merge

Use `AskUserQuestion` with `multiSelect: true`:

- **Question:** "Which completed plans should be included in this merge?"
- **Options:** List each plan with its matched branch name. Do NOT collect diffs yet — that happens in Phase 2 after the user decides which plans to merge.

## Phase 2: Analyze Diffs

For each selected branch, collect:

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

Read the plan file (or all stage files for folder plans) to understand the intent of the changes.

### 2d. Build the Conflict Map

Find files touched by multiple branches:

```bash
# Collect all changed files per branch, find overlaps
```

For each conflicting file, get the actual diffs from each branch to understand whether changes are:

- **Compatible:** Different regions of the file (likely auto-merge)
- **Overlapping:** Same lines modified (manual resolution needed)
- **Semantic:** Different regions but logically interdependent (e.g., both add items to the same enum, both modify the same function's callers)

```bash
# For each conflicting file, show the specific hunks from each branch
git diff main...<branch1> -- <file>
git diff main...<branch2> -- <file>
```

## Phase 3: Determine Merge Order

Order branches by conflict minimization:

1. **Branches with no conflicts** — merge first (clean merges, no risk)
2. **Branches with only compatible conflicts** — merge next (auto-merge likely succeeds)
3. **Branches with overlapping/semantic conflicts** — merge last, in order of fewest conflicts

**Dependency check:** If branch B's changes depend on branch A's changes (e.g., B modifies code that A introduces), A must merge first. Detect this by checking if B's diff references symbols/files that only exist in A's diff.

## Phase 4: Write the Merge Plan

**Naming:** Derive the merge name from the branches being merged — take the first 4 characters of each branch name, join with `-`, append `-merge`. For example, merging branches `audio-player` and `selective-mulligan` produces the name `audi-sele-merge`. Use this for both the plan filename and integration branch:

- **Plan:** `$PLANS_DIR/merge/<name>.md` (e.g., `merge/audi-sele-merge.md`)
- **Integration branch:** `integrate/<name>` (e.g., `integrate/audi-sele-merge`)

**Important:** Merge plans go to `plans/merge/`, NOT `plans/draft/` or `plans/todo/`. The `todo/` directory is polled by hive.sh for autonomous execution — merges require human oversight and must be run interactively via `/merge`.

### Plan Structure

```markdown
# Merge <name> to Main

> **For Claude:** REQUIRED SUB-SKILLS: @merge-plan

**Goal:** Merge N completed feature branches into main via integration branch.

**Integration branch:** `integrate/<name>`

**Branches (merge order):**

| Order | Branch | Plan | Files Changed | Conflicts |
|-------|--------|------|---------------|-----------|
| 1 | `clean-branch` | clean-feature.md | 3 | None |
| 2 | `compat-branch` | compat-feature.md | 5 | 1 (compatible) |
| 3 | `conflict-branch` | conflict-feature.md | 8 | 3 (2 overlap, 1 semantic) |

---
```

### Task 1: Create Integration Branch

````markdown
### Task 1: Create integration branch

**Step 1: Create branch from main**

```bash
cd $PROJECT_ROOT/main
git checkout -b integrate/<name>
```

Or if using worktrees:

```bash
git worktree add $PROJECT_ROOT/integrate-<name> -b integrate/<name> main
cd $PROJECT_ROOT/integrate-<name>
```

**Step 2: Verify clean baseline**

```bash
cargo fmt && cargo check && cargo test
```

Expected: PASS (identical to main)
````

### Task per Branch

Each feature branch gets one task, merged into the integration branch:

````markdown
### Task N: Merge `<branch>` into integration

**Conflict level:** None / Compatible / Overlapping

**Step 1: Squash-merge the branch**

```bash
cd $PROJECT_ROOT/integrate-<name>  # or wherever integration branch is checked out
git merge --squash <branch>
```

Expected: Clean merge / Conflicts in <file list>

**Step 2: Resolve conflicts** (only if conflicts expected)

For each conflicting file, describe the specific resolution:

- `src/path/file.rs` — **Keep both:** Branch adds X at line N, other branch added Y at line M. Include both additions.
- `src/path/other.rs` — **Combine:** Both branches modify `function_name()`. Use branch-A's signature change and branch-B's body change.

Include the expected resolved code for each conflict.

**Step 3: Verify**

```bash
cargo fmt && cargo check && cargo test
```

Expected: PASS

**Step 4: Commit the squashed feature**

```bash
git commit -m "feat: <plan-name> (squashed from <branch>)"
```
````

### Final Task: Land on Main

````markdown
### Task N+1: Land integration branch on main

**Step 1: Final verification on integration branch**

```bash
cargo fmt && cargo check && cargo test
```

Expected: PASS

**Step 2: Build changes summary and merge integration branch into main**

Write a changes summary for the merge commit. Read each merged plan's goal and the squash commit messages. Format: a title line naming the merged features, then one paragraph per feature describing what actually changed (new APIs, removed code, behavioral changes). Example:

```
integrate: feature-a + feature-b

- Feature A: short description of what changed and why. Mention new
  APIs added, old code removed, and behavioral differences.

- Feature B: short description of what changed and why. Mention new
  APIs added, old code removed, and behavioral differences.
```

Use this as the merge commit message:

```bash
cd $PROJECT_ROOT/main
git merge integrate/<name> --no-ff -m "<changes summary>"
```

If main moved ahead, rebase integration branch onto main, re-verify, then merge.

**Step 3: Archive plans and clean up**

```bash
# Archive each merged plan
mv $PLANS_DIR/done/<plan-name> $PLANS_DIR/archive/

# Order matters: remove worktree FIRST (frees the branch), then delete the branch.
# --force: worktrees may have staged changes left over from squash-merge
# -D: squash-merge creates new commits, so git can't detect the branch as merged

# Remove feature worktrees, then branches
git worktree remove --force $PROJECT_ROOT/<branch>
git branch -D <branch>

# Remove integration worktree, then branch
git worktree remove --force $PROJECT_ROOT/integrate-<name>
git branch -D integrate/<name>
```

**Step 4: Verify cleanup**

- All merged plans moved from `done/` → `archive/`
- All merged worktrees removed
- All merged branches deleted
- `done/` only contains plans not yet merged
- Main has all changes and tests pass

**Step 5: Summary**

List all merged branches, archived plans, and remaining worktrees.
````

## Phase 5: Present to User

Show the user:

1. **Merge order** with rationale
2. **Conflict summary** — which files, what kind, proposed resolutions
3. **Risk assessment** — any semantic conflicts that need human judgment

Use `AskUserQuestion`:

- **Question:** "Merge plan written to plans/merge/. Ready to execute it interactively?"
- **Options:** "Run it now with /merge" / "I'll review and adjust first"

If "Run it now" — invoke the `merge` skill (it reads from `merge/`).
If "Review first" — leave in `merge/` and tell the user to run `/merge` when ready.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Done plan, no matching branch | Skip — already merged or deleted |
| No conflicts between branches | Merge in any order, all clean |
| Compatible conflicts (different regions) | Merge in order, auto-merge handles it |
| Overlapping conflicts (same lines) | Write explicit resolution code in plan |
| Semantic conflicts (logically related) | Flag for human review, suggest resolution |
| Branch depends on another branch | Merge dependency first |
| Merge fails unexpectedly | Stop, don't force — ask user |

## Common Mistakes

### Merging without reading the plans
- **Problem:** Can't write good conflict resolutions without understanding intent
- **Fix:** Always read the done plan to understand what each branch does

### Wrong merge order
- **Problem:** Creates unnecessary conflicts or breaks dependencies
- **Fix:** Follow the ordering algorithm — clean first, conflicts last, respect dependencies

### Force-resolving semantic conflicts
- **Problem:** Code compiles but logic is wrong (e.g., duplicate enum variants, conflicting state transitions)
- **Fix:** Flag semantic conflicts for human review, provide resolution suggestion but don't assume

### Deleting worktrees before verifying merge
- **Problem:** Can't recover if merge introduced bugs
- **Fix:** Keep worktrees until tests pass on main after all merges complete

## Red Flags

**Never:**
- Merge directly into main — always use an integration branch
- Force push to main
- Delete a worktree before its merge is verified on the integration branch
- Auto-resolve semantic conflicts without flagging them
- Skip reading the done plans
- Merge branches out of dependency order

**Always:**
- Create an integration branch from main first
- Read each done plan before analyzing its diff
- Show the conflict map to the user
- Write explicit resolution code for overlapping conflicts
- Run full test suite after each merge into integration
- Squash each feature into the integration branch (one clean commit per feature)
- Merge integration into main only after all squash-merges pass
- Keep worktrees until main is updated and verified

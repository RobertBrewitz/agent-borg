---
name: using-git-worktrees
description: Git worktree flow for this project's bare-repo layout. Use when starting feature work that needs isolation, before executing a plan, when creating an integration branch for merges, or when tearing down a finished worktree. Covers path resolution, safe creation (new vs existing branch), integration-branch conventions, and correct-order removal. Use whenever a skill references `@using-git-worktrees`, or whenever you need to add, inspect, or remove a worktree — do not improvise `git worktree` commands.
---

# Using Git Worktrees

| I/O | Directory |
|-----|-----------|
| Reads | `$PROJECT_ROOT` (bare repo), `$PROJECT_ROOT/<branch>/` worktrees |
| Writes | creates and removes worktree directories + branches |

## Overview

This project uses a **bare repository** at `$PROJECT_ROOT` with every worktree as a sibling directory. Worktrees isolate concurrent work — each plan gets its own, each integration attempt gets its own, and they're cheap to create and destroy. The rules below prevent the three things that actually go wrong: creating a worktree inside the bare repo by accident, colliding with an existing branch, and removing a branch while its worktree still references it.

**Announce at start:** "I'm using the using-git-worktrees skill."

## Layout

```
$PROJECT_ROOT/              # bare git repo (HEAD, objects/, refs/) — this IS the repo
├── main/                   # worktree on main
├── <feature-branch>/       # one worktree per feature plan
├── integrate-<name>/       # integration worktree (merge skill)
├── plans/                  # separate nested git repo — not a worktree
```

`$PROJECT_ROOT` itself is never checked out. Every checkout lives in a sibling directory named after its branch.

## Path Resolution

Always resolve paths the same way. `git rev-parse --git-common-dir` returns the bare repo directly — do not walk to its parent:

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
WORKTREE="$PROJECT_ROOT/$BRANCH"
```

From inside any worktree, these two commands still return the bare repo; that's the whole point. If `$PROJECT_ROOT` resolves to `.git` (a relative path), you're running from a non-bare repo — stop and tell the user, this skill assumes the bare-repo layout.

## Creating a Worktree

### 1. Resolve and validate

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
WORKTREE="$PROJECT_ROOT/$BRANCH"
```

Before creating:

- **Branch name sanity.** Reject empty, whitespace-only, or names containing `..`, spaces, or a leading `-`. Plan-derived branch names are usually fine; guard against accidents anyway.
- **Directory already exists?** If `$WORKTREE` is a directory, check whether it's already a registered worktree (`git worktree list | grep -F "$WORKTREE"`). If yes, reuse it — do not recreate. If it's an unrelated directory, stop and ask the user.
- **Branch already exists?** Check with `git show-ref --verify --quiet "refs/heads/$BRANCH"`. Existing branches must be attached with the existing-branch form below; new branches use the create form. Picking the wrong form is the most common failure mode.

### 2. Create — new branch

When `$BRANCH` does not yet exist, branch from `main` (the project's integration branch):

```bash
git worktree add "$WORKTREE" -b "$BRANCH" main
```

### 3. Create — existing branch

When `$BRANCH` already exists as a ref, attach a worktree to it:

```bash
git worktree add "$WORKTREE" "$BRANCH"
```

### 4. Robust fallback (used by the coder subagent)

If you don't know ahead of time whether the branch exists, try the create form first and fall back to the attach form:

```bash
if [ -d "$WORKTREE" ]; then
  cd "$WORKTREE"
else
  git worktree add "$WORKTREE" -b "$BRANCH" 2>/dev/null \
    || git worktree add "$WORKTREE" "$BRANCH"
  cd "$WORKTREE"
fi
```

This is the right default for autonomous agents — they don't need to pre-check state.

### 5. Change into it

All subsequent work happens inside `$WORKTREE`. Don't try to operate on a worktree from outside it; many git commands behave unexpectedly in the bare repo directory.

## Integration Worktrees

The `merge` skill creates a short-lived integration worktree to squash-merge features before landing on main. The naming and location are fixed conventions:

- **Directory:** `$PROJECT_ROOT/integrate-<name>/`
- **Branch:** `integrate/<name>` (note the slash in the ref, dash in the dirname)
- **Base:** always `main`

```bash
git worktree add "$PROJECT_ROOT/integrate-<name>" -b "integrate/<name>" main
cd "$PROJECT_ROOT/integrate-<name>"
```

`<name>` is typically the feature branches joined with `-` and suffixed `-merge` (e.g., `audio-player-selective-mulligan-merge`) — see `@merge` for the exact naming rule. The dirname uses `integrate-` (dash) because directory names can't contain slashes, while the ref uses `integrate/` (slash) so it groups under a namespace in `git branch` listings.

## Listing and Inspecting

```bash
git worktree list                 # all worktrees: path, HEAD, branch
git worktree list --porcelain     # machine-readable
```

From inside a worktree:

```bash
git rev-parse --show-toplevel     # this worktree's path
git branch --show-current         # this worktree's branch
```

Matching a plan to its worktree (used by `merge` and `hive`): parse `git worktree list`, take the branch in brackets on each line, and fuzzy-match against plan names (strip common prefixes/suffixes, check substrings).

## Removing a Worktree

**Order matters: worktree first, then branch.** If you delete the branch while the worktree still points at it, git reattaches the worktree to a detached HEAD and leaves orphan state behind. If you delete the worktree first, the branch is safe to drop cleanly.

### 1. Check for uncommitted work

From the worktree:

```bash
cd "$WORKTREE"
git status --porcelain
```

Non-empty output means uncommitted changes. Stop and ask the user — do not `--force` past their work. This is the check `git worktree remove` does for you, but running it yourself gives a cleaner error surface.

### 2. Remove the worktree

```bash
git worktree remove --force "$PROJECT_ROOT/$BRANCH"
```

`--force` is appropriate here because you've already verified the worktree is clean (or the user has approved blowing away changes). It covers the case where the worktree is the current directory or has submodule residue.

### 3. Remove the branch

```bash
git branch -D "$BRANCH"
```

`-D` (uppercase) is used because feature branches are typically squash-merged, so git doesn't see them as "merged" and refuses `-d`. Only run this after the feature has landed on main (or the user has explicitly discarded the branch).

### 4. Integration worktrees

Same two-step pattern, same order:

```bash
git worktree remove --force "$PROJECT_ROOT/integrate-<name>"
git branch -D "integrate/<name>"
```

## Quick Reference

| Situation | Command |
|-----------|---------|
| Resolve project root | `PROJECT_ROOT="$(git rev-parse --git-common-dir)"` |
| New branch worktree | `git worktree add "$PROJECT_ROOT/$BRANCH" -b "$BRANCH" main` |
| Existing branch worktree | `git worktree add "$PROJECT_ROOT/$BRANCH" "$BRANCH"` |
| Autonomous create-or-attach | `add -b` then fall back to plain `add` |
| Integration worktree | `git worktree add "$PROJECT_ROOT/integrate-<n>" -b "integrate/<n>" main` |
| List worktrees | `git worktree list` |
| Remove worktree | `git worktree remove --force "$PROJECT_ROOT/$BRANCH"` then `git branch -D "$BRANCH"` |
| Check clean before remove | `git status --porcelain` inside the worktree |

## Red Flags

**Never:**

- Walk up from `git rev-parse --git-common-dir` to its parent. The bare repo IS the project root.
- Create a worktree at a path that isn't `$PROJECT_ROOT/<branch>/`. The rest of the pipeline (hive, merge, resume files) assumes this layout.
- Delete a branch before its worktree — you'll leave an orphan worktree entry pointing at a detached HEAD.
- Use `--force` to paper over uncommitted changes without the user's say-so.
- Reuse a branch name that belongs to someone else's active worktree. Check `git worktree list` first.

**Always:**

- Resolve `PROJECT_ROOT` fresh at startup — don't hard-code paths.
- Pick the right create form: `-b <branch>` for new, plain `add` for existing. The fallback chain above handles the ambiguous case.
- Remove worktree then branch, in that order.
- Verify `git status --porcelain` is empty before removing a feature worktree unless the user has approved discarding the work.

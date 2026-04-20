---
name: plan-directory
description: Shared reference for the plans/ directory layout, PLANS_DIR resolution, and the plan lifecycle. Loaded by design, write-plan, verify-plan, implement-plan, self-review, and merge so they share one source of truth for structure (not behavior).
---

# Plan Directory

Shared conventions for skills that read or write under `plans/`. This skill defines **structure and invariants only** — each action skill owns its own behavior.

## Resolve `PLANS_DIR`

The bare repository IS the project root — `git rev-parse --git-common-dir` returns it directly (do NOT go to its parent):

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

All paths below are relative to `$PLANS_DIR`.

## Lifecycle

```
backlog/   →  design/   →  draft/   →  todo/   →  in-progress/   →  done/   →  archive/
 (ideas)     (validated    (drafted   (ready    (being             (merged    (post-
              requirements) plan)      to run)   implemented)       to main)   merge)
```

Side-channels (not on the main path):

- `resume/<plan-name>.md` — resume state for `implement-plan`. Created when a plan enters `in-progress/`, deleted when the plan reaches `done/`.
- `review/<plan-name>-self-review.md` — findings from `self-review`. Deleted once findings are resolved, or on verify/archive (stale after rewrites).

## Ownership per stage

| Directory | Written by | Read by | Notes |
|-----------|------------|---------|-------|
| `backlog/` | user, write-plan (spillover) | design, write-plan | one `.md` per idea; consumed files are deleted |
| `design/` | design | write-plan | deleted by write-plan once the plan that used it is written |
| `draft/` | write-plan, verify-plan | verify-plan | plan can be a single `.md` or a folder of numbered stages |
| `todo/` | verify-plan (promotion) | implement-plan | ready to execute |
| `in-progress/` | implement-plan | implement-plan, self-review | active work; has matching `resume/` file. `self-review` (thorough mode) runs here before moving to `done/` |
| `done/` | implement-plan | merge | implemented, not yet merged to main |
| `archive/` | merge | — | post-merge record |
| `resume/` | implement-plan | implement-plan | resume state, one file per in-progress plan |
| `review/` | self-review | user, verify-plan | stale after rewrites — delete, don't carry forward |

## Plan shape

A plan is either:

- **Single file:** `<stage>/<feature-name>.md`
- **Folder:** `<stage>/<feature-name>/` with numbered stage files (`01-setup.md`, `02-core.md`, …). Each stage is self-contained with its own header and tasks.

Moves between stages preserve the shape (file stays a file, folder stays a folder).

## `plans/` is its own git repo

`$PLANS_DIR` is a **nested git repository**, separate from the project repo. Consequences:

- Run plan-directory git commands (commits, moves, deletions) from `$PLANS_DIR`, not from `$PROJECT_ROOT`.
- The project repo does not track `plans/` contents.
- A stage transition is a move + commit inside `$PLANS_DIR`.

## Backlog cleanup protocol

When a backlog file feeds into a design or plan:

1. Track which backlog files were consumed.
2. Delete them from `$PLANS_DIR/backlog/` **at the point of commit**:
   - `design` deletes consumed backlog files when committing the design document.
   - `write-plan` deletes them when committing the plan (if the design didn't already).
3. New out-of-scope work discovered during design/planning becomes **new** backlog files, not inline tasks.

Do not defer backlog cleanup to a later stage — the signal that a backlog item is "taken" is its absence from `backlog/`.

## Invariants

- Each plan appears in exactly one lifecycle stage directory at a time.
- `resume/<plan-name>.md` implies the plan is in `in-progress/`.
- A `review/` file older than the plan's current stage is stale — delete rather than trust.
- A plan in `done/` has a matching feature branch (merge relies on this).

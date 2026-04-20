---
name: hive
description: One-shot dispatcher for the autonomous coding pipeline. Scans plans/todo/ (plus stale plans/in-progress/ with a resume file) and launches coder subagents in parallel via the Task tool, up to a configurable concurrency limit. Report back when the batch finishes.
---

# Hive

| I/O | Directory |
|-----|-----------|
| Reads | `plans/todo/`, `plans/in-progress/`, `plans/resume/` |
| Writes | nothing directly — dispatches `coder` subagents which move plans to `done/` or `blocked/` |

## Overview

Pick up work from `plans/todo/` and any stalled `plans/in-progress/` plans, then launch a batch of parallel `coder` subagents — one per plan — via the `Task` tool. Each coder owns its worktree end-to-end. This skill is one-shot: dispatch, wait, summarize. Run `/hive` again to pick up more work.

Replaces the old `hive.sh` shell dispatcher.

**Announce at start:** "I'm using the hive skill."

## Arguments

The skill accepts optional arguments via the invocation (e.g. `/hive 5 --retry-blocked`):

| Flag / Positional | Default | Meaning |
|-------------------|---------|---------|
| `N` (first number) | `3` | Max concurrent coder subagents per batch |
| `--retry-blocked` | off | Move every plan in `blocked/` back to `todo/` before dispatching |
| `--only <name>` | — | Dispatch only the named plan (skip scanning) |

## Plan Directory

See `@plan-directory` for the shared `plans/` layout, lifecycle, and nested-git-repo rule.

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

## Phase 1: Resolve and Prep

1. Resolve `PROJECT_ROOT` and `PLANS_DIR`.
2. If `--retry-blocked` was given, `mv` everything in `$PLANS_DIR/blocked/` to `$PLANS_DIR/todo/` and commit inside `$PLANS_DIR`:
   ```bash
   cd "$PLANS_DIR"
   git add -A && git commit -m "hive: retry blocked plans"
   ```
3. Confirm `$PROJECT_ROOT/agent/coder.md` exists (subagent definition). If missing, abort with a clear error — setup is incomplete.

## Phase 2: Collect Work

Build a list of `(plan_name, branch, plan_path)` tuples.

### Plans in `todo/`

List every `.md` file and every subdirectory under `$PLANS_DIR/todo/`. Each one is a plan. `plan_name` is the filename without `.md` (or the directory name).

### Stale plans in `in-progress/`

List plans in `$PLANS_DIR/in-progress/`. For each:

- Check `$PLANS_DIR/resume/<plan-name>.md`. If the resume file exists and its mtime is older than **30 minutes** (1800s), the plan is orphaned — treat it as dispatchable.
- If no resume file exists for an in-progress plan, it's also orphaned.
- Move orphaned plans back to `todo/`:
  ```bash
  mv "$PLANS_DIR/in-progress/<plan>" "$PLANS_DIR/todo/"
  ```

Commit the moves inside `$PLANS_DIR`.

### Branch resolution

For each plan, read the `**Branch:**` metadata from the plan file (top 20 lines). Strip backticks and whitespace. If absent, use `plan_name` as the branch.

For folder plans, read the first `.md` file alphabetically (typically `01-*.md`).

### `--only <name>`

When `--only` is passed, short-circuit Phase 2: look for the named plan in `todo/` or `in-progress/`, build a single-element list, skip the scan.

## Phase 3: Report the Batch

Before dispatching, show the user what you're about to launch:

```
Hive: dispatching N plans (max M concurrent)

  1. add-feature        → feature-add
  2. refactor-parser    → parser-refactor
  3. fix-race-condition → fix-race
  ...
```

If the list is empty, say so and exit:

```
Hive: nothing to do — todo/ and in-progress/ are clean.
```

## Phase 4: Dispatch

Launch coder subagents in batches of up to `max_concurrent` (default 3).

For each plan in the current batch, emit **one `Task` tool call per plan, all in the same assistant message** so they run in parallel. Each call uses:

- `subagent_type: "coder"` (defined in `$PROJECT_ROOT/agent/coder.md` — must be linked into the user's agents directory; see Setup in README.md)
- `description`: `"Execute plan <plan-name>"`
- `prompt`: the invocation briefing (see below)

### Coder prompt template

```
Execute plan: <plan-name>

- Plan path: <absolute path to plan file or folder>
- Branch: <branch>
- Worktree: <project-root>/<branch>/

Follow the workflow in agent/coder.md (your subagent definition).
Return a one-paragraph summary when done.
```

Keep the prompt minimal — the agent definition carries the workflow.

### Batching

If `N > max_concurrent`:

1. Launch the first `max_concurrent` as parallel Task calls in one message.
2. Wait for all results (the Task tool returns when each finishes).
3. Emit the next batch. Repeat until the list is drained.

Do **not** interleave — each batch must fully settle before the next launches, so the concurrency cap actually holds.

## Phase 5: Summarize

After every batch has run, report a single table of outcomes:

```
Hive results (N plans):

  done:     add-feature, fix-race-condition
  blocked:  refactor-parser (step 4 failed 3x)
  stalled:  <plan-name> (context exhausted — re-run /hive to resume)

Totals: 2 done, 1 blocked, 1 stalled
```

- **done** = plan is now in `plans/done/`
- **blocked** = plan is now in `plans/blocked/`
- **stalled** = plan is still in `plans/in-progress/` with a resume file — a subsequent `/hive` will pick it up

Determine each outcome by checking `plans/done/`, `plans/blocked/`, and `plans/in-progress/` after all subagents return.

## Red Flags

**Never:**

- Launch more than `max_concurrent` coders at once.
- Dispatch a plan that another coder is actively working on (check `in-progress/` vs. age of the resume file).
- Modify plan files, resume files, or worktrees yourself — that's the coder's job.
- Continuously poll. This skill is one-shot. The user re-runs `/hive` for more work.

**Always:**

- Read `**Branch:**` from the plan before dispatching (don't assume `plan_name == branch`).
- Commit plan moves inside `$PLANS_DIR` (it's a separate git repo).
- Report every outcome, including stalls, so the user knows what to re-run.

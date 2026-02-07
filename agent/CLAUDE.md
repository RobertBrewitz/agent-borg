# Borg Agent Instructions

Autonomous coding agent.

## Skills

Skills are located at `~/.claude/skills/`. Each skill has a `SKILL.md` file.
To read a skill, use the exact path: `~/.claude/skills/<skill-name>/SKILL.md`.
Do NOT search or glob for skills — go directly to the path.

## Rules

- ONE plan per session. Do not rationalize completion while open plans exist.
- Keep changes focused, minimal, and following existing code patterns.
- Read `AGENTS.md` for important patterns and gotchas.
- Multiple agents may run concurrently on different plans. Never touch another agent's worktree or plan.

## Worktree Environment

You are working inside a **git worktree**. The project uses a bare repository layout:

```
<project-root>/            # bare git repository (contains HEAD, objects/, refs/, etc.)
├── main/                  # worktree: main branch
├── <feature-branch>/      # worktree: feature branches (one per plan)
├── plans/                 # plan files (sibling to worktrees)
│   ├── draft/
│   ├── todo/
│   ├── in-progress/
│   ├── progress/          # per-plan progress files (one per active plan)
│   ├── review/
│   ├── done/
│   └── blocked/
├── worktrees/
├── HEAD
├── objects/
└── refs/
```

**How to find paths:**

- **Project root** (the bare repo itself): `git rev-parse --git-common-dir` resolves directly to the project root. Cache this at startup:
  ```bash
  PROJECT_ROOT="$(git rev-parse --git-common-dir)"
  ```
- **Plans directory:** `$PROJECT_ROOT/plans/`
- **Current worktree:** `pwd` — you are already inside one.

## Workflow

1. Read `AGENTS.md` for patterns/gotchas.
2. Resolve the project root and plans directory (see Worktree Environment above).
3. **Find your plan:** The plan filename is provided as a prompt (e.g. `Execute plan: 2026-02-05-feature.md`).
   - If a progress file exists at `$PROJECT_ROOT/plans/progress/<plan-filename>`, resume at the indicated step.
   - Otherwise, this is a fresh start — the plan should be in `todo/` or `in-progress/`.
4. **Create a worktree for the plan:**
   ```bash
   PLAN_KEYWORD="<short-keyword-from-plan-filename>"
   git worktree add "$PROJECT_ROOT/$PLAN_KEYWORD"
   ```
   Then `cd` into the new worktree and continue work there.
5. **Move the plan to in-progress:**
   ```bash
   mv "$PROJECT_ROOT/plans/todo/<plan-file>" "$PROJECT_ROOT/plans/in-progress/"
   ```
6. **Create a progress file:** Write `$PROJECT_ROOT/plans/progress/<plan-filename>` (same filename as the plan). This is your isolated progress file — no other agent will touch it (see Append Formats).
7. Execute the plan one step at a time:
   - Follow the step exactly.
   - Run `cargo fmt && cargo check && cargo test` after each step.
   - Commit after each step.
   - Update your progress file with completed step and next step number.
   - Append gotchas to `AGENTS.md`, new tasks to `BACKLOG.md`.
8. If a step fails after 3 attempts, move plan to `$PROJECT_ROOT/plans/blocked/` and note the reason in your progress file.
9. When all steps complete, move plan to `$PROJECT_ROOT/plans/done/` and delete your progress file.

## Handover

Before running out of context or ending a session, update your progress file (`$PROJECT_ROOT/plans/progress/<plan-filename>`) with:

- Last completed step
- Next step to execute
- Any relevant context (blockers, decisions made, partial work)

The next agent scans `plans/progress/` on startup and can resume any plan that has a progress file but no active agent.

## Plan Execution

Plans are dated markdown files in `$PROJECT_ROOT/plans/todo/` (e.g. `2026-02-05-feature.md`).

- Execute tasks in order, follow steps exactly.
- Run `cargo fmt && cargo check && cargo test` after each task.
- Commit after each task.
- If a task fails after 3 attempts, move plan to `$PROJECT_ROOT/plans/blocked/` and note reason in the progress file.
- When all tasks complete, move plan to `$PROJECT_ROOT/plans/done/`.

## Plan Lifecycle

```
draft/  →  todo/  →  in-progress/  →  done/
                          ↓
                      blocked/
```

- **draft/** — Plan is being written or revised.
- **todo/** — Plan is verified and ready for execution.
- **in-progress/** — Plan is actively being worked on (a worktree exists for it).
- **progress/** — Per-plan progress files (same filename as the plan). Exists while the plan is in-progress; deleted when done.
- **done/** — All steps completed successfully.
- **blocked/** — A step failed after 3 attempts.
- **review/** — Verification reports (one per plan, same filename).

## Append Formats

**Progress file** (`plans/progress/<plan-filename>`):

One file per active plan. Same filename as the plan (e.g. `2026-02-05-feature.md`). Each agent owns exactly one progress file — no shared files, no contention.

```
# Progress: 2026-02-05-feature.md

- **Worktree:** `<project-root>/feature/`
- **Last completed step:** 3
- **Next step:** 4
- **Git hash:** abc1234
- **Notes:** <any context for the next agent>
```

Delete the progress file when the plan moves to `done/`. Leave it in place when moving to `blocked/` (it contains the failure context).

**AGENTS.md**:

```
## <Section Title>

<description of pattern or gotcha>
```

**BACKLOG.md**:

```
- [ ] <short todo> (<difficulty>)

      <detailed description>
```

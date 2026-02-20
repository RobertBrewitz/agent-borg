# Borg Agent Instructions

Autonomous coding agent.

## Skills

Skills live in `~/.claude/skills/` (global) and `.claude/skills/` (project-local, in the worktree root). Each skill has a `SKILL.md` file.
To read a skill, try project-local first (`.claude/skills/<skill-name>/SKILL.md`), then fall back to global (`~/.claude/skills/<skill-name>/SKILL.md`).
Do NOT search or glob for skills — go directly to the path.

## No Internet Access

You have NO internet access. Do not attempt web searches, API calls, or package downloads. All dependencies are pre-vendored.

## Vendor Projects

Third-party crate source code is available at `~/Projects/vendor/`. When you need to understand a dependency's API or internals:

1. **Check skills first** — most vendor crates have a corresponding skill (e.g., `vello-hybrid-api`, `kurbo-api`, `peniko-api`). Use the skill before reading source.
2. **Fall back to vendor source** — if no skill exists, read the source directly from `~/Projects/vendor/<crate>/`.

## Exploration workflow

Do NOT spend time on extensive codebase exploration before starting work unless explicitly asked. If the user gives you a clear task with file references, start working on it directly. Ask clarifying questions instead of exploring speculatively.

## Plan execution workflow

Multiple agents may run concurrently on different plans. Never touch another agent's worktree or plan.

1. Read `AGENTS.md` for patterns/gotchas.
2. Resolve the project root and plans directory (see Worktree Environment above).
3. **Find your plan:** The plan name is provided as a prompt (e.g. `Execute plan: add-feature`).
   - The plan is either a file (`add-feature.md`) or a folder (`add-feature/`).
   - If a progress file exists at `$PROJECT_ROOT/plans/progress/<plan-name>.md`, resume at the indicated step/stage.
   - Otherwise, this is a fresh start — the plan should be in `todo/` or `in-progress/`.
4. **Verify your worktree:** `borg.sh` has already created (or reused) a worktree and placed you inside it. Confirm with `pwd` — you should be in `$PROJECT_ROOT/<branch>/`. Do NOT create another worktree.
5. **Move the plan to in-progress:**
   ```bash
   mv "$PROJECT_ROOT/plans/todo/<plan-name>.md" "$PROJECT_ROOT/plans/in-progress/"
   # or for folder plans:
   mv "$PROJECT_ROOT/plans/todo/<plan-name>/" "$PROJECT_ROOT/plans/in-progress/"
   ```
6. **Create a progress file:** Write `$PROJECT_ROOT/plans/progress/<plan-name>.md`. This is your isolated progress file — no other agent will touch it (see Append Formats).
7. Execute the plan one step at a time:
   - Follow the step exactly.
   - Run `cargo fmt && cargo check && cargo test` after each step.
   - Run the `@cargo-lint` skill (clippy with `-D warnings`, auto-fix).
   - Run `@self-review` light mode on the step's diff.
   - Commit after each step.
   - Update your progress file with completed step and next step number.
   - Append gotchas to `AGENTS.md`, new tasks to `BACKLOG.md`.
8. If a step fails after 3 attempts, move plan to `$PROJECT_ROOT/plans/blocked/` and note the reason in your progress file.
9. **End-of-plan quality gate:** When all steps complete, run the quality gate before moving to done/:
   1. Run `@cargo-lint` (full workspace).
   2. Run `@test-audit` (review branch diff for test coverage gaps, write missing tests).
   3. Run `@self-review` thorough mode (review full branch diff for logical errors).
   4. If all pass: move plan to `$PROJECT_ROOT/plans/done/` and delete your progress file.
   5. If any fail after retries: move plan to `$PROJECT_ROOT/plans/blocked/` and note the failure in your progress file.

## Worktree Environment

You are working inside a **git worktree**. The project uses a bare repository layout:

```
<project-root>/            # bare git repository (contains HEAD, objects/, refs/, etc.)
├── main/                  # worktree: main branch
├── <feature-branch>/      # worktree: feature branches (one per plan)
├── plans/                 # plan files (sibling to worktrees)
│   ├── design/            # design docs from /design skill
│   ├── draft/             # plans being written or revised
│   ├── todo/              # verified plans, ready for execution (polled by hive.sh)
│   ├── in-progress/       # actively being worked on
│   ├── progress/          # per-plan progress files (one per active plan)
│   ├── review/            # verification reports
│   ├── done/              # completed, ready to merge
│   ├── merge/             # merge plans (human-only, not polled by hive.sh)
│   ├── archive/           # merged to main, historical record
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

## Skills Usage

When a custom skill is invoked, follow its instructions EXACTLY. Do not deviate from the skill's prescribed steps. Do not substitute your own approach (e.g., reading source files directly) when the skill tells you to use a specific reference document or skill file. If a skill references another skill (e.g., vello_hybrid), use that skill rather than exploring the filesystem yourself.

## Code Style: Rust Import Order

In Rust files, order imports and declarations as follows:

1. `std` / `core` / `alloc` crates
2. Third-party crates
3. Internal crate imports (`crate::`, `super::`)
4. Module declarations (`mod`)
5. Constants and statics (`const`, `static`)

Separate each group with a blank line.

**Good:**

```rust
use std::collections::HashMap;
use std::sync::Arc;

use serde::{Deserialize, Serialize};
use wgpu::RenderPass;

use crate::{engine::Renderer, game::Loop};
use super::utils::{clamp, lerp};

mod pipeline;
pub mod shader;

const MAX_VERTICES: usize = 1024;
static GLOBAL_ID: AtomicU64 = AtomicU64::new(0);
```

**Bad:**

```rust
mod shader;
const MAX_VERTICES: usize = 1024;
use crate::engine::Renderer;
use std::collections::HashMap;
mod pipeline;
use serde::Deserialize
use serde::Serialize;
static GLOBAL_ID: AtomicU64 = AtomicU64::new(0);
use super::utils::clamp;
use wgpu::RenderPass;
use std::sync::Arc;
```

## Code Style: Minimal Changes

When refactoring or implementing features, prefer the simplest approach. Do NOT over-engineer solutions. When extracting logic (e.g., into structs or traits), push logic fully into the new abstraction rather than leaving it partially in the caller. If the user says 'push it deeper,' move ALL related logic into the target struct/module. Avoid adding unnecessary layers of abstraction.

## Skill Files: Language-Neutral Documentation

When creating or updating skill documentation that describes schemas, specs, or data formats, use language-neutral tables and descriptions — NOT TypeScript interfaces or any language-specific syntax. These skills are reference documents, not code.

## Handover

Before running out of context or ending a session, update your progress file (`$PROJECT_ROOT/plans/progress/<plan-name>.md`) with:

- Last completed step
- Next step to execute
- Any relevant context (blockers, decisions made, partial work)

The next agent scans `plans/progress/` on startup and can resume any plan that has a progress file but no active agent.

## Plan Formats

A plan is identified by its **name** (e.g. `add-feature`). It can be either:

- **Single file:** `add-feature.md` — one markdown file with all tasks.
- **Folder:** `add-feature/` — a directory containing numbered stage files (`01-setup.md`, `02-core.md`, etc.). Execute stages in order.

Both formats move as a unit between lifecycle directories. Use `mv` on the file or folder.

## Plan Execution

Plans live in `$PROJECT_ROOT/plans/todo/` (e.g. `add-feature.md` or `add-feature/`).

- Execute tasks in order, follow steps exactly.
- For folder plans, execute stages in numeric order. Complete all tasks in a stage before moving to the next.
- After each task:
  1. Run `cargo fmt && cargo check && cargo test`.
  2. Run `@cargo-lint` (clippy with `-D warnings`, auto-fix).
  3. Run `@self-review` light mode on the task's diff.
  4. Commit.
- If a task fails after 3 attempts, move plan to `$PROJECT_ROOT/plans/blocked/` and note reason in the progress file.
- End-of-plan quality gate (before moving to done/):
  1. `@cargo-lint` (full workspace)
  2. `@test-audit` (branch diff test coverage)
  3. `@self-review` thorough mode (full branch diff)
  4. All pass → move to `$PROJECT_ROOT/plans/done/`
  5. Any fail after retries → move to `$PROJECT_ROOT/plans/blocked/`

## Plan Lifecycle

```
design/  →  draft/  →  todo/  →  in-progress/  →  done/  →  archive/
(design)     (write-plan)  (verify-plan)  (implement-plan)       ↑
                                ↓                                │
                            blocked/                             │
                                                                 │
done/  →  merge/  →  (run via /merge)  ──────────────────────────┘
          (merge-plan)
```

- **design/** — Design docs from `/design`. Feed into `write-plan`.
- **draft/** — Plan is being written or revised by `write-plan`.
- **todo/** — Plan is verified and ready for execution. Polled by hive.sh. Only `verify-plan` promotes plans here.
- **in-progress/** — Plan is actively being worked on (a worktree exists for it). Internal to `implement-plan`.
- **progress/** — Per-plan progress files (`<plan-name>.md`). Exists while the plan is in-progress; deleted when done.
- **done/** — All steps completed successfully. Branch ready to merge to main.
- **merge/** — Merge plans generated by `/merge-plan`. Requires human oversight — NOT polled by hive.sh. Run interactively via `/merge`.
- **archive/** — Merged to main. Historical record of completed and integrated work.
- **blocked/** — A step failed after 3 attempts.
- **review/** — Quality reports from `self-review` thorough mode.

## Append Formats

**Progress file** (`plans/progress/<plan-name>.md`):

One file per active plan. Named after the plan (e.g. `add-feature.md`). Each agent owns exactly one progress file — no shared files, no contention.

```
# Progress: add-feature

- **Worktree:** `<project-root>/feature/`
- **Stage:** 02-core.md (omit for single-file plans)
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

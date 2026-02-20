# Agent Borg

A set of configuration files and skills that turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into an autonomous coding agent. Designed to work with **git worktree** layouts — a bare repository with worktree branches as sibling directories and a shared `plans/` repository at the project root. A wrapper script (`borg.sh`) runs Claude Code in a loop, where each iteration picks up a plan from `plans/todo/`, creates a worktree for it, executes it step by step, and commits along the way. Progress is tracked per-plan in `plans/progress/`, allowing multiple agents to work on different plans concurrently without contention. Plans are written and verified using dedicated skills before execution begins.

## **Important**

**Use at your own risk.**

## Task Planning

1. Use the `write-plan` skill to create detailed implementation plans before starting work.
2. Use the `verify-plan` skill to review, rewrite, and promote plans to `todo/`.

## Project Layout

The agent expects a bare repository with worktrees. The `plans/` directory is its own git repository, sibling to the worktrees:

```
<project-root>/            # bare git repository (contains HEAD, objects/, refs/, etc.)
├── main/                  # worktree: main branch
├── <feature-branch>/      # worktree: feature branches (one per plan)
├── plans/                 # separate git repo for plan files
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

## Setup

1. Copy the contents of the `agent/` folder into each worktree root (or the main worktree).
2. Copy the `agent/.plans/` directory to `<project-root>/plans/` and initialize it as its own git repo (`git init` inside `plans/`).
3. Copy the contents of the `skills/` folder to `~/.claude/skills/` or the project's `.claude/skills/` folder.

## Agent Files

These files live in the worktree root after setup:

- **`CLAUDE.md`** — Instructions that Claude Code reads on startup. Defines the worktree environment, agent workflow, plan execution rules, handover format, and how to use skills. ONE plan per session. The agent resolves the project root via `git rev-parse --git-common-dir` and locates plans at `$PROJECT_ROOT/plans/`.
- **`borg.sh`** — Wrapper script that runs Claude Code in a loop on a single plan. Usage: `./borg.sh <branch> <path-to-plan>`. Creates or reuses a worktree for the given branch, then loops until the plan is done or blocked, handling context-window limits by re-invoking Claude (which resumes from the progress file). Includes retry logic with exponential backoff for transient API errors. Run multiple instances in parallel for concurrent plans.
- **`AGENTS.md`** — Shared knowledge base for patterns and gotchas discovered during execution. Agents append to this file so future iterations avoid repeating mistakes.
- **`BACKLOG.md`** — Parking lot for tasks discovered during execution that are out of scope for the current plan.
- **`PROGRESS.md`** — *(Deprecated. Progress is now tracked per-plan in `plans/progress/`.)*

## Skills

### Plan Pipeline

- **`design`** — Explores ideas through collaborative dialogue, writes design docs to `plans/design/`.
- **`write-plan`** — Reads designs from `plans/design/`, creates detailed implementation plans in `plans/draft/`. TDD cycles, exact file paths, complete code, explicit commands. Single-file or multi-stage folders.
- **`verify-plan`** — Reads plans from `plans/draft/`, validates structure and feasibility. Rewrites the plan to fix any issues found, re-verifies, and promotes passing plans to `plans/todo/`.
- **`implement-plan`** — Reads plans from `plans/todo/`, executes interactively with user checkpoints. Completed plans go to `plans/done/`.
- **`merge-plan`** — Reads completed plans from `plans/done/`, analyzes worktree branches, writes merge plans to `plans/merge/`.
- **`merge`** — Reads merge plans from `plans/merge/`, executes squash-merges interactively with human oversight. Archives plans to `plans/archive/`.

### Quality

- **`cargo-lint`** — Runs `cargo clippy` with `-D warnings` (all warnings are errors), auto-fixes issues, and checks for doc warnings. Retries up to 3 times before blocking.
- **`self-review`** — Agent reviews its own code diff for logical errors. Light mode runs per-step (quick scan of the step's diff). Thorough mode runs at end-of-plan (full branch diff against base, writes a review report to `plans/review/`). Auto-fixes issues and blocks on unresolvable problems.
- **`test-audit`** — Verifies that changed code has adequate test coverage by reading the branch diff and test files. Writes missing tests for uncovered public functions and error paths. No coverage tooling — qualitative assessment by the agent.

## Plan Lifecycle

```
design/  →  draft/  →  todo/  →  in-progress/  →  done/  →  archive/
(design)   (write-plan) (verify-plan)  (implement-plan)       ↑
                          review ↺                             │
                            rewrite                            │
                                ↓                              │
                            blocked/                           │
                                                               │
done/  →  merge/  →  (run via /merge)  ────────────────────────┘
          (merge-plan)
```

- **design/** — Design docs from `/design`. Feed into `write-plan`.
- **draft/** — Plan is being written by `write-plan`, or being rewritten by `verify-plan`.
- **todo/** — Plan is verified and ready for execution. Polled by hive.sh. Only `verify-plan` promotes plans here.
- **in-progress/** — Plan is actively being worked on (internal to `implement-plan`).
- **merge/** — Merge plans from `/merge-plan`. Requires human oversight, run via `/merge`.
- **progress/** — Per-plan progress files. Exists while the plan is in-progress; deleted when done.
- **review/** — Quality reports from `self-review` thorough mode.
- **done/** — All steps completed successfully.
- **archive/** — Merged to main. Historical record.
- **blocked/** — A step failed after 3 attempts.

## License

Dual-licensed under MIT or Apache-2.0, at your option.

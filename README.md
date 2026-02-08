# Agent Borg

A set of configuration files and skills that turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into an autonomous coding agent. Designed to work with **git worktree** layouts — a bare repository with worktree branches as sibling directories and a shared `plans/` repository at the project root. A wrapper script (`borg.sh`) runs Claude Code in a loop, where each iteration picks up a plan from `plans/todo/`, creates a worktree for it, executes it step by step, and commits along the way. Progress is tracked per-plan in `plans/progress/`, allowing multiple agents to work on different plans concurrently without contention. Plans are written and verified using dedicated skills before execution begins.

## **Important**

**Use at your own risk.**

## Task Planning

1. Use the `write-plan` skill to create detailed implementation plans before starting work.
2. Use the `verify-plan` skill to review plans for structural correctness and feasibility.
3. Use the `write-plan` skill to resolve any plan issues found during verification.

## Project Layout

The agent expects a bare repository with worktrees. The `plans/` directory is its own git repository, sibling to the worktrees:

```
<project-root>/            # bare git repository (contains HEAD, objects/, refs/, etc.)
├── main/                  # worktree: main branch
├── <feature-branch>/      # worktree: feature branches (one per plan)
├── plans/                 # separate git repo for plan files
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

- **`write-plan`** — Creates detailed, step-by-step implementation plans with TDD cycles, exact file paths, complete code, and explicit commands. Plans can be single-file (`plans/draft/<name>.md`) or multi-stage folders (`plans/draft/<name>/` with numbered stage files). Uses agent skills as the primary source of codebase knowledge, supplemented by reading source code. Includes a skill gap report when source code had to be consulted directly.
- **`verify-plan`** — Read-only dry-run review that checks a plan for structural quality (against `write-plan` conventions) and codebase feasibility (verifying paths, types, and APIs exist). Produces a report with blockers, warnings, notes, and a verdict (READY / REVIEW / NEEDS SKILLS / NOT READY). Saves reports to `plans/review/`. Does not modify any files other than the review.

## Plan Lifecycle

```
draft/  →  todo/  →  in-progress/  →  done/
                          ↓
                      blocked/
```

- **draft/** — Plan is being written or revised.
- **todo/** — Plan is verified and ready for execution.
- **in-progress/** — Plan is actively being worked on (a worktree exists for it).
- **progress/** — Per-plan progress files. Exists while the plan is in-progress; deleted when done.
- **review/** — Verification reports (one per plan).
- **done/** — All steps completed successfully.
- **blocked/** — A step failed after 3 attempts.

## License

Dual-licensed under MIT or Apache-2.0, at your option.

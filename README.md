# Agent Borg

A set of configuration files and skills that turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into an autonomous coding agent. Designed to work with **git worktree** layouts — a bare repository with worktree branches as sibling directories and a shared `plans/` folder at the project root. A wrapper script (`borg.sh`) runs Claude Code in a loop, where each iteration picks up a plan from `plans/todo/`, creates a worktree for it, executes it step by step, and commits along the way. Progress is tracked per-plan in `plans/progress/`, allowing multiple agents to work on different plans concurrently without contention. Plans are written and verified using dedicated skills before execution begins.

## **Important**

**Use at your own risk.**

## Task planning

1. Use the `writing-plans` skill to create detailed implementation plans before starting work.
2. Use the `verifying-plans` skill to review plans for structural correctness and feasibility.
3. Use the `writing-plans` skill to resolve any plan issues found during verification.

## Project Layout

The agent expects a bare repository with worktrees:

```
<project-root>/
├── .bare/              # bare git repository
├── main/               # worktree: main branch
├── <feature-branch>/   # worktree: created per plan
└── plans/              # shared plan files
    ├── draft/
    ├── todo/
    ├── in-progress/
    ├── progress/       # per-plan progress files (one per active plan)
    ├── review/
    ├── done/
    └── blocked/
```

## Setup

1. Copy the contents of the `agent/` folder into each worktree root (or the main worktree).
2. Copy the `agent/.plans/` directory to `<project-root>/plans/` (the bare repo parent, sibling to worktrees).
3. Copy the contents of the `skills/` folder to `~/.claude/skills/` or the project's `.claude/skills/` folder.

## Agent files

These files live in the root of your project after setup:

- **`CLAUDE.md`** — Instructions that Claude Code reads on startup. Defines the worktree environment, agent workflow, plan execution rules, handover format, and how to use skills.
- **`borg.sh`** — Wrapper script that runs Claude Code in a loop on a single plan. Usage: `./borg.sh <plan-filename>`. Loops until the plan is done or blocked, handling context-window limits by re-invoking Claude (which resumes from the progress file). Includes retry logic with exponential backoff for transient API errors. Run multiple instances in parallel for concurrent plans.
- **`AGENTS.md`** — Shared knowledge base for patterns and gotchas discovered during execution. Agents append to this file so future iterations avoid repeating mistakes.
- **`BACKLOG.md`** — Parking lot for tasks discovered during execution that are out of scope for the current plan.
- **`PROGRESS.md`** — *(Deprecated. Progress is now tracked per-plan in `plans/progress/`.)*

## Skills

- **`writing-plans`** — Creates detailed, step-by-step implementation plans with TDD cycles, exact file paths, complete code, and explicit commands. Plans are saved to `plans/draft/`. When a plan moves to `todo/` and execution begins, the agent creates a dedicated worktree and moves the plan to `plans/in-progress/`.
- **`verifying-plans`** — Dry-run review that checks a plan for structural quality and codebase feasibility. Produces a report with blockers, warnings, and a verdict (READY / NOT READY). Does not modify any files.

## License

Dual-licensed under MIT or Apache-2.0, at your option.

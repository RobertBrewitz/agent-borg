# Agent Borg

A set of Claude Code skills and a subagent that turn [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into an autonomous coding pipeline. Designed to work with **git worktree** layouts — a bare repository with worktree branches as sibling directories and a shared `plans/` repository at the project root. The `/hive` slash command scans `plans/todo/`, dispatches one `coder` subagent per plan (up to a concurrency limit), and waits for them to finish. Each coder creates or reuses a worktree, executes the plan end-to-end inside its own context window, and moves the plan to `done/` or `blocked/`. Resume state is tracked per-plan in `plans/resume/`, so a subsequent `/hive` can pick up any plan whose coder ran out of context. Plans are written and verified using dedicated skills before execution begins.

## **Important**

**Use at your own risk.**

## Task Planning

1. Add task ideas to `plans/backlog/` as individual markdown files.
2. Use the `design` skill to explore backlog items (or new ideas) and write design docs to `plans/design/`.
3. Use the `write-plan` skill to create detailed implementation plans in `plans/draft/`.
4. Use the `verify-plan` skill to review, rewrite, and promote plans to `plans/todo/`.

## Project Layout

The pipeline expects a bare repository with worktrees. The `plans/` directory is its own git repository, sibling to the worktrees:

```
<project-root>/            # bare git repository (contains HEAD, objects/, refs/, etc.)
├── main/                  # worktree: main branch
├── <feature-branch>/      # worktree: feature branches (one per plan)
├── plans/                 # separate git repo for plan files
│   ├── backlog/           # task summaries — ideas/work items to turn into plans
│   ├── design/            # design docs from /design skill
│   ├── draft/             # plans being written or revised
│   ├── todo/              # verified plans, ready for execution (scanned by /hive)
│   ├── in-progress/       # actively being worked on
│   ├── resume/            # per-plan resume files (one per active plan)
│   ├── review/            # verification reports
│   ├── done/              # completed, ready to merge
│   ├── merge/             # merge plans (human-only, not scanned by /hive)
│   ├── archive/           # merged to main, historical record
│   └── blocked/
├── worktrees/
├── HEAD
├── objects/
└── refs/
```

## Setup

1. Create a `plans/` directory at `<project-root>/` and initialize it as its own git repo (`git init` inside `plans/`). Create the subdirectories: `backlog/`, `design/`, `draft/`, `todo/`, `in-progress/`, `resume/`, `review/`, `done/`, `merge/`, `archive/`, `blocked/`.
2. Copy the `agent/` folder into each worktree root (or the main worktree). It holds `AGENTS.md` (the shared-knowledge file) and `coder.md` (the subagent definition).
3. Link `agent/coder.md` into `~/.claude/agents/coder.md` (or the project-local `.claude/agents/coder.md`) so Claude Code can discover the subagent. Symlink or copy — either works.
4. Copy the contents of `skills/` to `~/.claude/skills/` or the project's `.claude/skills/` folder. Alternatively, run `link-skills.sh` to symlink them.

## Agent Files

These files live in the `agent/` directory (copied into each worktree root during setup):

- **`CLAUDE.md`** — Instructions Claude Code reads on startup in the worktree. Defines the worktree environment and the day-to-day workflow for interactive sessions. The pipeline resolves the project root via `git rev-parse --git-common-dir` and locates plans at `$PROJECT_ROOT/plans/`.
- **`coder.md`** — Subagent definition used by `/hive`. A coder owns one plan end-to-end: creates or reuses a worktree, executes each step with quality gates, runs the end-of-plan quality gate, and moves the plan to `done/` or `blocked/`. Link this into `~/.claude/agents/` (or project-local `.claude/agents/`) so Claude Code's Task tool can invoke it.
- **`AGENTS.md`** — Shared knowledge base for patterns and gotchas discovered during execution. Coders append to this file so future runs avoid repeating mistakes.

## Skills

### Plan Pipeline

- **`design`** — Explores ideas through collaborative dialogue, writes design docs to `plans/design/`.
- **`write-plan`** — Reads designs from `plans/design/`, creates detailed implementation plans in `plans/draft/`. Exact file paths, complete code, explicit commands. No tests. Single-file or multi-stage folders.
- **`verify-plan`** — Reads plans from `plans/draft/`, validates structure and feasibility. Rewrites the plan to fix any issues found, re-verifies, and promotes passing plans to `plans/todo/`.
- **`implement-plan`** — Reads plans from `plans/todo/`, executes interactively with user checkpoints. Completed plans go to `plans/done/`.
- **`hive`** — One-shot dispatcher. Scans `plans/todo/` (plus stale `plans/in-progress/`), launches `coder` subagents in parallel up to a concurrency limit, and reports results.
- **`merge-plan`** — Reads completed plans from `plans/done/`, analyzes worktree branches, writes merge plans to `plans/merge/`.
- **`merge`** — Reads merge plans from `plans/merge/`, executes squash-merges interactively with human oversight. Archives plans to `plans/archive/`.

### Quality

- **`cargo-lint`** — Runs `cargo clippy` with `-D warnings` (all warnings are errors), auto-fixes issues, and checks for doc warnings. Retries up to 3 times before blocking.
- **`self-review`** — Agent reviews its own code diff for logical errors. Light mode runs per-step (quick scan of the step's diff). Thorough mode runs at end-of-plan (full branch diff against base, writes a review report to `plans/review/`). Auto-fixes issues and blocks on unresolvable problems.
- **`test-audit`** — Verifies that changed code has adequate test coverage by reading the branch diff and test files. Writes missing tests for uncovered public functions and error paths. No coverage tooling — qualitative assessment by the agent.

## Plan Lifecycle

```
backlog/  →  design/  →  draft/  →  todo/  →  in-progress/  →  done/  →  archive/
             (design)   (write-plan) (verify-plan)  (/hive or         ↑
                                       review ↺    implement-plan)   │
                                         rewrite                      │
                                             ↓                        │
                                         blocked/                     │
                                                                      │
done/  →  merge/  →  (run via /merge)  ──────────────────────────────┘
          (merge-plan)
```

- **backlog/** — Task summaries: ideas and work items to be turned into plans. Each file is one task. Consumed by `/design`.
- **design/** — Design docs from `/design`. Feed into `write-plan`.
- **draft/** — Plan is being written by `write-plan`, or being rewritten by `verify-plan`.
- **todo/** — Plan is verified and ready for execution. Scanned by `/hive`. Only `verify-plan` promotes plans here.
- **in-progress/** — Plan is actively being worked on (a worktree exists for it). A stale in-progress plan (no recent resume-file activity) is recovered back to `todo/` by the next `/hive` run.
- **merge/** — Merge plans from `/merge-plan`. Requires human oversight, run via `/merge`.
- **resume/** — Per-plan resume files. Exists while the plan is in-progress; deleted when done.
- **review/** — Quality reports from `self-review` thorough mode.
- **done/** — All steps completed successfully. Branch ready to merge.
- **archive/** — Merged to main. Historical record.
- **blocked/** — A step failed after 3 attempts.

## Autonomous Execution

Run the `/hive` slash command from an interactive Claude Code session inside any worktree:

```
/hive                  # default: up to 3 concurrent coder subagents
/hive 5                # up to 5 concurrent
/hive --retry-blocked  # move blocked/ plans back to todo/ first, then dispatch
/hive --only add-auth  # dispatch a single named plan
```

`/hive` reads each plan's `**Branch:**` field to determine the worktree branch (falling back to the plan name if absent), launches one `coder` subagent per plan via the Task tool, waits for the batch, and reports outcomes (done / blocked / stalled). A stalled plan is one whose coder ran out of context mid-plan — re-run `/hive` and a fresh coder resumes from the plan's resume file.

## License

Dual-licensed under MIT or Apache-2.0, at your option.

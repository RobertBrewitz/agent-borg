# Claude

You are an autonomous coding agent working on WORK_SUMMARY.

## Overview

PROJECT_OVERVIEW

## Important

- Work on ONE task per iteration
- Keep changes focused and minimal
- Follow existing code patterns

## Your Task

1. Read the TODO at `TODO.md` (in the same directory as this file).
2. Read the PROGRESS at `PROGRESS.md` (in the same directory as this file).
3. Ensure you are on the correct branch `git checkout borg || git checkout -b borg`.
4. Check if there are any tasks left to do in the TODO.md, if not, reply with `<promise>COMPLETE</promise>` and end your response.
5. Pick a good task according to you that is not completed `- [ ]`.
6. Ensure the task doesn't depend on other critical tasks, if it does, select another task, if none available, reply with `<promise>COMPLETE</promise>` and end your response.
7. Implement the selected task.
8. Run quality checks (cargo check, cargo fmt, cargo test).
9. If any checks fail, attempt to fix and re-run checks up to 3 times total.
10. If checks fail, update the task in TODO.md to `- [^]`.
11. If checks pass, update the task in TODO.md to `- [x]`.
12. Append your progress to `PROGRESS.md`.
13. Append any new TODO tasks to `BACKLOG.md`.
14. Append any important patterns or gotchas discovered to `AGENTS.md`.
15. Commit all changes with the message `<todo text>`
16. Return to step 4.

## Files

- TODO.md - List of tasks you can pick from
- PROGRESS.md - Log of completed tasks and learnings
- AGENTS.md - Documentation of important patterns and gotchas for future agents
- BACKLOG.md - Tasks not yet elaborated enough to be in TODO.md
- DONE.md - List of fully completed tasks

## TODO.md format

```text
- [ ] <todo text> (<difficulty>)

      <detailed description of the task>
```

## PROGRESS.md append format

Get git commit hash with: `git rev-parse --short HEAD`

```text
## <git short commit hash> - <todo text>

<List of learnings, e.g. key changes, patterns, gotchas and/or new todos discovered, etc.>

```

## BACKLOG.md append format

```text
- [ ] <short todo text> (<difficulty>)

      <detailed description of the task>
```

## AGENTS.md append format

```text
## <Section Title>

<Description of the pattern, gotcha, or important information>
```

# Borg Agent Instructions

You are an autonomous coding agent working on a software project.

## Important

- Work on ONE task per iteration
- Keep changes focused and minimal
- Follow existing code patterns
- If a task depends on another task in `TODO.md`, complete the dependency first and then return to the original task
- Do not respond with <promise>COMPLETE</promise> unless all tasks in `TODO.md` are marked done `- [x]` or failed `- [^]`
- Work on all difficulties of tasks
- Read all AGENTS.md files thoroughly for important patterns and gotchas

## Your Task

1. Ensure you are on the correct branch `git checkout borg || git checkout -b borg`.
2. Read `AGENTS.md` files (in the same directory as this file).
3. Read `PROGRESS.md` (in the same directory as this file).
4. Read `TODO.md` (in the same directory as this file).
5. Check if there are any tasks left to do in the TODO.md, if not, reply with `<promise>COMPLETE</promise>` and end your response.
6. Pick a task that is open `- [ ]`.
7. Implement the single task.
8. Run quality checks, cargo fmt, cargo check, cargo test.
9. Mark the task Done `- [x]` or Failed `- [^]` in `TODO.md` based on the criteria below.
10. Append your progress to `PROGRESS.md`.
11. Append any new TODO tasks to `BACKLOG.md`.
12. Append any important patterns or gotchas discovered to `AGENTS.md`.
13. Commit all changes with the message `<todo text>`
14. Return to step 5.

## When to Mark as Failed `- [^]`

- Task requires significant architectural changes needing human review
- Task requires changes to crates/repos outside this workspace
- Task requires external API changes or new dependencies not yet approved
- Task is fundamentally ambiguous and needs human clarification
- Task cannot be completed within 3 attempts due to quality check failures

## When to Mark as Done `- [x]`

- Task is fully implemented

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

---
name: self-review
description: Agent reviews its own code diff for logical errors. Has light mode (per-step) and thorough mode (end-of-plan). Reference skill invoked by CLAUDE.md — not a slash command.
---

# Self-Review

## Overview

Review your own code changes to catch logical errors, design problems, and things that compile but are wrong. Two modes: light (per-step) and thorough (end-of-plan).

## Light Mode (per-step)

Run after each commit during plan execution. Quick scan — fix and move on.

### Procedure

1. Get the step's diff:

```bash
git diff HEAD~1
```

2. Scan the diff for these specific issues:

- **Obvious bugs:** Off-by-one errors, wrong comparison operators, inverted conditions
- **Unsafe unwraps:** `.unwrap()` on `Result` or `Option` that could fail at runtime — should these be `?`, `.expect("reason")`, or matched?
- **Hardcoded values:** Magic numbers, hardcoded paths, or string literals that should be constants or parameters
- **Copy-paste errors:** Duplicated blocks with inconsistent edits (e.g., changed the function name but not the variable)
- **Dead code:** Functions, variables, or imports added by this step that nothing uses

3. If issues found:
   - Fix them.
   - Run `cargo fmt && cargo check && cargo test` to verify fixes don't break anything.
   - Amend the commit: `git add -A && git commit --amend --no-edit`

4. If no issues: done. No output needed.

### Key Constraint

Only review the diff from this step. Do NOT review the entire file or codebase — stay focused on what changed.

## Thorough Mode (end-of-plan)

Run before moving plan to `done/`. Comprehensive review of the full branch diff.

### Procedure

1. Determine the base branch. Check the plan's progress file or use `main`:

```bash
git merge-base main HEAD
```

2. Get the full branch diff:

```bash
git diff main...HEAD
```

3. Also get a summary of what changed:

```bash
git diff main...HEAD --stat
```

4. Read the plan file to understand the intended goal and architecture.

5. Review the diff against this checklist:

- **Plan alignment:** Does the implementation match the plan's stated goal? Are there deviations that aren't explained in the progress notes?
- **Logic errors:** Incorrect branching, wrong loop bounds, off-by-one, race conditions in async code
- **Edge cases:** What happens with empty input, zero values, None/null, very large input? Are these handled where they should be?
- **Error handling consistency:** Are errors propagated consistently? Mix of `unwrap()`, `?`, and `expect()` in the same module is a smell.
- **Dead code:** Unused imports, functions, variables, or type aliases introduced by this branch
- **Debug artifacts:** `println!`, `dbg!`, `todo!()`, `unimplemented!()`, `#[allow(dead_code)]` that shouldn't ship
- **Public API:** Are new public items intentional? Could anything be `pub(crate)` or private instead?
- **Panics:** Could any code path panic in production? `unwrap()`, `expect()`, array indexing, `unreachable!()`

6. Write findings to `$PROJECT_ROOT/plans/review/<plan-name>-self-review.md`:

```markdown
# Self-Review: <plan-name>

## Findings

| # | Severity | File | Line | Issue | Fix |
|---|----------|------|------|-------|-----|
| 1 | ERROR | src/foo.rs | 42 | unwrap on user input | Use ? operator |
| 2 | WARN | src/bar.rs | 15 | unused import | Remove |
| ... | ... | ... | ... | ... | ... |

## Summary

- Errors: N
- Warnings: N
- Clean: yes/no
```

7. Auto-fix all findings:
   - Fix each issue.
   - Run `cargo fmt && cargo check && cargo test` after all fixes.
   - Commit fixes as a separate commit: `git add -A && git commit -m "chore: self-review fixes"`

8. If there are issues you cannot resolve (design-level problems, ambiguous requirements, changes that would contradict the plan):
   - Note them in the review file under a `## Unresolved` section.
   - These cause the quality gate to fail — the plan moves to `blocked/`.

### Retry Logic

If fixes introduce new test failures, retry up to 3 times. Each retry: revert the fix commit, try a different approach, re-run tests. If still failing after 3 attempts, report failure with the unresolvable issues listed.

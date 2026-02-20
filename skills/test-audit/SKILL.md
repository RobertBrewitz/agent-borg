---
name: test-audit
description: Verify changed code has adequate test coverage by analyzing the branch diff. Reference skill invoked by CLAUDE.md at end-of-plan — not a slash command.
---

# Test Audit

## Overview

Verify that code changed in this branch has adequate test coverage. Not a coverage tool — the agent reads the diff and tests to make a qualitative judgment. Runs at end-of-plan, before moving to `done/`.

## Procedure

### Step 1: Get the branch diff

```bash
git diff main...HEAD
```

### Step 2: Identify testable additions

From the diff, list all:

- New public functions and methods
- New public structs, enums, and their impl blocks
- Modified public function signatures (changed parameters or return types)
- New trait implementations

Ignore:

- Private helper functions called only from tested public functions
- Type aliases, re-exports, and use statements
- Derive macros and attribute changes
- Documentation-only changes

### Step 3: For each testable item, check coverage

For each item identified in Step 2:

1. Search for tests that call or exercise this item:

```bash
grep -r "function_name\|StructName" tests/ src/ --include="*.rs" -l
```

2. Read the matching test files. Evaluate:

- **Happy path:** Is there at least one test that calls the function with valid input and checks the result?
- **Error path:** If the function returns `Result`, is there a test that triggers the `Err` case?
- **Edge cases:** For functions with branching (`if`/`match`), are the important branches covered? Focus on:
  - Empty/zero/None inputs
  - Boundary values (if applicable)
  - The "else" branch that's easy to forget
- **Struct construction:** For new structs, is there a test that creates one and verifies its fields/behavior?

3. Classify each item:

- **COVERED** — adequate tests exist
- **PARTIAL** — tests exist but miss error paths or important branches
- **MISSING** — no tests found

### Step 4: Fix gaps

For each MISSING or PARTIAL item:

1. Write the test. Follow the project's existing test patterns:
   - Check whether tests live in `tests/` (integration) or inline `#[cfg(test)] mod tests` (unit).
   - Match the naming convention of existing tests.
   - Use the same assertion style (`assert_eq!`, `assert!`, `assert_matches!`).

2. For MISSING items: write a test covering the happy path and at least one error/edge case.

3. For PARTIAL items: add the missing cases (error path, edge case) to the existing test file.

4. Run the new tests:

```bash
cargo test <test_name>
```

5. If a test fails: fix the test (not the implementation — if the implementation is wrong, that's a self-review issue, not a test-audit issue). Retry up to 3 times.

### Step 5: Report

If any tests were written, note them in the progress file:

```
- **Test audit:** Added tests for `foo::bar()` (happy + error path), `Baz::new()` (construction)
```

If you could not write adequate tests after 3 attempts (e.g., the function requires complex setup you don't understand, or it depends on external state), write the gaps to the progress file and report failure:

```
- **Test audit BLOCKED:** Could not test `complex_function()` — requires database connection setup not covered by any skill
```

## What This Skill Does NOT Do

- **No coverage tooling.** No tarpaulin, no llvm-cov, no coverage percentages. The agent reads code and makes a judgment.
- **No coverage targets.** "80% coverage" is not a goal. The goal is: "are the important behaviors tested?"
- **No testing private internals.** If a private function is only reachable through a tested public function, it's covered.
- **No testing trivial code.** Getters, simple constructors with no logic, and `Display` impls don't need dedicated tests unless they contain branching logic.

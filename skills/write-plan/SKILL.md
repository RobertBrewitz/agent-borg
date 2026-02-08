---
name: write-plan
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Write Plan

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the write-plan skill."

## Resolve Plans Directory

Before accessing any plan files, resolve the project root and plans directory. The bare repository IS the project root — `git rev-parse --git-common-dir` returns it directly (do NOT go to its parent):

```bash
PROJECT_ROOT="$(git rev-parse --git-common-dir)"
PLANS_DIR="$PROJECT_ROOT/plans"
```

All plan paths below use `$PLANS_DIR` as the root.

## First: New or Existing?

Before doing anything else, use `AskUserQuestion` to prompt:

- **Question:** "New plan or existing?"
- **Options:** "Write new plan" / "Revise existing plan"

Then:

- **If new:** Ask: "Single file or multi-stage folder?" Options: "Single file" / "Multi-stage folder".
  - **Single file:** Save to `$PLANS_DIR/draft/<feature-name>.md`.
  - **Folder:** Create `$PLANS_DIR/draft/<feature-name>/` with numbered stage files (`01-setup.md`, `02-core.md`, etc.). Each stage is a self-contained plan with its own header and tasks. Group related tasks into stages by logical phase (setup, core logic, integration, polish, etc.).
- **If existing:** List all `.md` files and subdirectories in `$PLANS_DIR/draft/` and `$PLANS_DIR/todo/`. Use `AskUserQuestion` to prompt which plan to work on (list the names as options). Then read the chosen plan (all stage files for folders) and check `$PLANS_DIR/review/` for a matching review (`<plan-name>.md` for single-file plans, `<plan-name>/` folder for multi-stage plans). If a review exists:
  1. Read the review(s) and collect all non-PASS items (BLOCKERs, WARNINGs, NOTEs). For folder plans, read all per-stage review files.
  2. Group them by category. Use `AskUserQuestion` with `multiSelect: true` to prompt which categories to resolve (e.g. "Blockers (3 items)" / "Warnings (2 items)" / "Notes (1 item)").
  3. Revise the plan to address all items in the selected categories.
  4. After revision, delete the review file or folder — it is now stale.

  If no review exists, ask what changes are needed. Revise following all the conventions below.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**

- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Gather agent skills (REQUIRED — your primary source of codebase knowledge)

**Ask the human:** "What agent skills should I use for this plan?"

Skills live in `~/.claude/skills/` (global) and `./.claude/skills/` (project-local). No other search paths exist.

Read every provided skill (`skills/<name>/SKILL.md`). These are your primary reference for:

- File paths and line ranges
- Struct/function names and signatures
- Module layout and architecture
- Existing patterns and conventions

**You MAY also read source code, Grep, and Glob** to fill gaps, verify details, or understand context that skills don't cover. Skills-first, code as needed — but never guess paths or APIs when you can look them up.

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILLS: [comma-separated list of agent skills used in this plan with @ syntax]

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

There are two task formats: **TDD** (default for anything that produces testable behavior) and **non-TDD** (for wiring, config, imports, formatting — no testable behavior). Both use `### Task N:` headings and `**Step N:**` bold labels for steps. No other heading levels inside tasks.

**TDD task** (default):

````markdown
### Task N: [Component Name]

**Files:**

- Create: `exact/path/to/file.rs`
- Modify: `exact/path/to/existing.rs:123-145`
- Test: `tests/exact/path/to/test.rs`

**Step 1: Write the failing test**

```rust
#[test]
fn test_specific_behavior() {
    let result = function(input);
    assert_eq!(result, expected);
}
```

**Step 2: Run test to verify it fails**

Run: `cargo test test_specific_behavior`
Expected: FAIL (test should fail since implementation doesn't exist yet)

**Step 3: Write minimal implementation**

```rust
pub fn function(input: Type) -> ReturnType {
    expected
}
```

**Step 4: Run test to verify it passes**

Run: `cargo test test_specific_behavior`
Expected: PASS

**Step 5: Commit**

Run: `git add tests/path/test.rs src/path/file.rs && git commit -m "feat: add specific feature"`
````

**Non-TDD task** (wiring, config, imports, formatting):

````markdown
### Task N: [Component Name]

**Files:**

- Modify: `exact/path/to/file.rs:10-15`

**Step 1: Make the change**

```rust
// complete code here
```

**Step 2: Verify**

Run: `cargo fmt && cargo check`
Expected: PASS

**Step 3: Commit**

Run: `git add exact/path/to/file.rs && git commit -m "chore: description"`
````

## Skill Gap Report

After saving the plan, if you read any source code (Read, Grep, Glob) to fill gaps not covered by skills, append a **Skill Gap Report** section at the bottom of the plan:

```markdown
---

## Skill Gap Report

The following were looked up from source code because no skill covered them:

- **`src/engine/input.rs`** — `InputState` struct fields and `process_events()` signature. Needed for Task 3.
- **`src/engine/physics.rs:45-80`** — `PhysicsWorld::step()` method and collision callback pattern. Needed for Tasks 5-6.
```

Each entry should note the file/symbol looked up and which task needed it. This tells the user which skills to create for future plans.

## Cleanup

After saving the plan, check if a design document exists for this feature (e.g. `$PLANS_DIR/draft/<topic>-design.md` or `$PLANS_DIR/draft/<topic>-design/`). If one exists, delete it and commit the deletion — the plan is the source of truth now.

## Remember

- Exact file paths always (sourced from skills, never guessed)
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits
- Skills first, then read code to fill gaps — never guess when you can look it up

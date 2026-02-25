---
name: cargo-lint
description: Run clippy with strict settings and auto-fix lint issues. Reference skill invoked by CLAUDE.md during plan execution — not a slash command.
---

# Cargo Lint

## Overview

Strict clippy enforcement with auto-fix. Run this after `cargo fmt && cargo check && cargo test` passes. This skill defines the procedure — follow it exactly.

## Procedure

### Step 1: Run clippy

```bash
cargo clippy --workspace --all-targets -- -D warnings
```

- If clean: done. No output needed.
- If warnings/errors: go to Step 2.

### Step 2: Attempt auto-fix

```bash
cargo clippy --fix --allow-dirty --allow-staged
```

Then re-run the check:

```bash
cargo clippy --workspace --all-targets -- -D warnings
```

- If clean: stage the auto-fixed files (`git add -A`) so fixes are included in the next commit. Done.
- If still failing: go to Step 3.

### Step 3: Manual fix

Read each remaining diagnostic. For each one:

1. Read the file and line referenced in the diagnostic.
2. Understand what clippy is asking for.
3. Edit the code to resolve the lint.
4. Do NOT suppress lints with `#[allow(...)]` unless the lint is genuinely a false positive. If you suppress a lint, add a comment explaining why.

Re-run:

```bash
cargo clippy --workspace --all-targets -- -D warnings
```

### Step 4: Doc warnings check

```bash
cargo doc --no-deps --document-private-items 2>&1
```

Review the output for warnings (broken intra-doc links, missing docs on public items that require them). Fix any warnings using the same fix-and-recheck pattern.

### Retry Logic

If clippy still fails after 3 full cycles of Steps 1-3, write the unresolvable diagnostics to the progress file and report failure. Include the exact compiler output.

### Configuration

Default lint level: `-D warnings` (all warnings are errors).

If the project has specific overrides, they should be in `Cargo.toml` or `.clippy.toml` — respect those. Do NOT add project-specific configuration to this skill.

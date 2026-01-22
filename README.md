# Agent Borg

An autonomous AI agent for tasks derived from the Ralph.

## **Important**

This is very new to me, I am still experimenting.

**Use at your own risk.**

## Overview

- Kanban style markdown files
- Keep your tasks minimal and focused on one task at a time.
- You can add new tasks to `BACKLOG.md` for future elaboration, the agent should not pick tasks from there.
- Add elaborated tasks to `TODO.md` for the agent to pick from.
- The agent appends progress to `PROGRESS.md`.
- The agent documents important information in `AGENTS.md` for future iterations.
- You can move tasks to `DONE.md` once verified by you.
- See `CLAUDE.md` for detailed agent instructions.

## Notes

### Worktree

I **strongly** recommend working in a worktree enabled git repository to be able to work at the same time as the agent.

A worktree repository is a git repository that allows multiple branches to be checked out at the same time in different directories.

So when the agent finishes a task, you can immediately cherry-pick and verify in another branch; Or focus on harder problems while the agent works on easier tasks.

### Cherry-picking and verification

I cherry-pick commits in order to verify each task is done correctly and perhaps add my own changes.

### Failed tasks

I might implement failed tasks myself, re-elaborate in `TODO.md` or add them to `BACKLOG.md` for future elaboration.

## Usage

### Setup

Copy all files inside of the `agent` folder into the **root** of your project directory.

### Update AGENTS.md

Add any important architectural or project specific information to the top of `AGENTS.md` for the agent(s) to read.

### Add tasks

Add your coding tasks to the `TODO.md` file in the following format:

```text
- [ ] <todo text> (<difficulty>)

      <detailed description of the task>
```

### Start the agent

Run the script with optional parameters for model type and maximum iterations:

```bash
./borg.sh [model=code|creative|research] [max_iterations=10]
```

## License

Dual-licensed under MIT or Apache-2.0, at your option.

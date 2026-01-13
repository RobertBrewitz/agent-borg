# Agent Borg

An autonomous AI agent for tasks derived from the Ralph.

## Overview

- Kanban style markdown files
- Keep your tasks minimal and focused on one task at a time.
- You can add new tasks to `BACKLOG.md` for future elaboration, the agent should not pick tasks from there.
- Add elaborated tasks to `TODO.md` for the agent to pick from.
- The agent appends progress to `PROGRESS.md`.
- The agent documents important information in `AGENTS.md` for future iterations.
- You can move tasks to `DONE.md` once verified by you.
- See `CLAUDE.md` for detailed agent instructions.

## Usage

### Setup

Copy all files inside of the agent folder into the **root** of your project directory.

### Update CLAUDE.md

Edit the `CLAUDE.md` file to reflect your project.

- Replace `WORK_SUMMARY` with a brief summary of the work to be done.
- Replace `PROJECT_OVERVIEW` with an overview of the project.

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

## Notes

- I cherry-pick commits in order to verify each task is done correctly and perhaps add my own changes.
- I might elaborate on failed tasks and add them back to `TODO.md` or `BACKLOG.md` for further elaboration.

## License

Dual-licensed under MIT or Apache-2.0, at your option.

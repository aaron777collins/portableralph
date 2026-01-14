# Usage Guide

Complete reference for using PortableRalph.

## Basic Usage

```bash
~/ralph/ralph.sh <plan-file> [mode] [max-iterations]
```

Ralph reads your plan file and autonomously implements it, one task at a time.

## Command Reference

### Arguments

| Argument | Required | Default | Description |
|:---------|:---------|:--------|:------------|
| `plan-file` | Yes | - | Path to your plan/spec markdown file |
| `mode` | No | `build` | `plan` or `build` |
| `max-iterations` | No | unlimited | Maximum loop iterations |

### Flags

| Flag | Description |
|:-----|:------------|
| `--help`, `-h` | Show help message |
| `--version`, `-v` | Show version |
| `--test-notify` | Test notification configuration |

### Examples

```bash
# Build from a plan until complete
~/ralph/ralph.sh ./docs/feature-spec.md

# Plan mode only (analyze and create task list, no implementation)
~/ralph/ralph.sh ./docs/feature-spec.md plan

# Build with max 20 iterations
~/ralph/ralph.sh ./docs/feature-spec.md build 20

# Plan with max 5 iterations
~/ralph/ralph.sh ./docs/feature-spec.md plan 5

# Test notification setup
~/ralph/ralph.sh --test-notify
```

## Modes

### Plan Mode

```bash
~/ralph/ralph.sh ./feature.md plan
```

In plan mode, Ralph:

1. Reads and analyzes your plan file
2. Explores the codebase to understand what exists
3. Creates a prioritized task list
4. Identifies dependencies between tasks
5. Updates the progress file with the analysis

!!! note
    Plan mode does **not** make any code changes. Use it to review the approach before implementation.

**Use plan mode when:**

- Starting a complex feature
- You want to review the approach before implementation
- You need to understand the scope of work

### Build Mode

```bash
~/ralph/ralph.sh ./feature.md build
```

In build mode, Ralph:

1. Reads the plan and progress file
2. Picks ONE uncompleted task
3. Searches codebase to verify it's not already done
4. Implements the task
5. Runs validation (tests, build, lint)
6. Updates progress file and commits
7. Loops back for the next task

**Use build mode when:**

- You have a clear plan ready
- You want autonomous implementation
- After reviewing a plan mode output

## Progress File

Ralph creates `<plan-name>_PROGRESS.md` in your current directory.

### Location

If your plan file is `./docs/auth-feature.md`, the progress file will be `./auth-feature_PROGRESS.md`.

### Format

```markdown
# Progress: auth-feature

## Status
IN_PROGRESS

## Analysis
Brief analysis of existing code vs what's needed.

## Task List
- [x] Task 1: Create user model
- [x] Task 2: Add login endpoint
- [ ] Task 3: Add JWT middleware
- [ ] Task 4: Write tests

## Completed This Iteration
- Task 2: Added POST /auth/login endpoint with password validation

## Notes
- Found existing bcrypt helper in src/utils/crypto.ts
- User model should extend BaseModel for timestamps
```

### Status Values

| Status | Meaning |
|:-------|:--------|
| `PLANNING` | Plan mode is analyzing |
| `IN_PROGRESS` | Build mode is implementing |
| `RALPH_DONE` | All tasks complete, loop will exit |

### Task Markers

| Marker | Meaning |
|:-------|:--------|
| `[ ]` | Pending task |
| `[x]` | Completed task |

## Exit Conditions

The Ralph loop exits when any of these occur:

| Condition | Description |
|:----------|:------------|
| `RALPH_DONE` | All tasks complete - normal successful exit |
| Max iterations | Limit reached (if specified) |
| `Ctrl+C` | Manual stop - progress is saved |

## Tips & Best Practices

### Start with Plan Mode

For complex features, always run plan mode first:

```bash
# First: create the task breakdown
~/ralph/ralph.sh ./feature.md plan

# Review the progress file
cat ./feature_PROGRESS.md

# Then: implement
~/ralph/ralph.sh ./feature.md build
```

### Watch the Output

Ralph runs in your terminal. Watch for:

- Unexpected file changes
- Test failures
- Going off-track

!!! warning
    Use `Ctrl+C` if Ralph goes in the wrong direction.

### Check Progress

Monitor what Ralph is doing:

```bash
# In another terminal
watch cat ./feature_PROGRESS.md
```

### Use Max Iterations for Safety

For unattended runs, set a limit:

```bash
# Run overnight but cap at 50 iterations
~/ralph/ralph.sh ./feature.md build 50
```

### Keep Plans Focused

Smaller, focused plans work better than large monolithic ones.

### Review Commits

Ralph commits after each task. Review the git log:

```bash
git log --oneline -10
git revert HEAD  # Undo last commit if needed
```

# PortableRalph

A dead-simple autonomous AI development loop that works in **any repo**.

Based on [The Ralph Playbook](https://github.com/ghuntley/how-to-ralph-wiggum) methodology.

## Quick Start

```bash
# Install (one time)
git clone https://github.com/YOUR_USERNAME/portableralph.git ~/ralph
chmod +x ~/ralph/ralph.sh

# Use (from any repo)
~/ralph/ralph.sh ./my-plan.md
```

## For AI Agents

**To invoke Ralph from another AI agent:**

```bash
# Run Ralph on a plan file (loops until RALPH_DONE in progress file)
~/ralph/ralph.sh /path/to/plan.md build

# Or plan-only mode (creates task list, doesn't implement)
~/ralph/ralph.sh /path/to/plan.md plan
```

**Plan file format** - just markdown describing what to build:
```markdown
# Feature: Whatever You Want

## Goal
Clear description of the objective.

## Requirements
- Bullet points of what needs to happen
- Be specific about acceptance criteria

## Context (optional)
- Relevant files or patterns to follow
- Any constraints or preferences
```

**Exit signal**: Add `RALPH_DONE` to `<plan-name>_PROGRESS.md` when work is complete.

---

## What is this?

Ralph is an AI development loop that:
1. Takes a plan file (your feature spec, bug description, whatever)
2. Breaks it into tasks
3. Implements each task one at a time
4. Loops until done (or you stop it)

**No setup required in your project.** Just point it at a plan file and go.

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/portableralph.git ~/ralph
chmod +x ~/ralph/ralph.sh
```

## Usage

```bash
# From any repo directory:
~/ralph/ralph.sh <plan-file> [mode] [max-iterations]
```

### Examples

```bash
# Build from a plan until complete
~/ralph/ralph.sh ./docs/feature-spec.md

# Plan mode only (analyze and create task list)
~/ralph/ralph.sh ./docs/feature-spec.md plan

# Build with max 20 iterations
~/ralph/ralph.sh ./docs/feature-spec.md build 20

# Plan with max 5 iterations
~/ralph/ralph.sh ./docs/feature-spec.md plan 5
```

### Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `plan-file` | Yes | - | Path to your plan/spec file |
| `mode` | No | `build` | `plan` or `build` |
| `max-iterations` | No | unlimited | Max loop iterations |

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                    YOUR PLAN FILE                        │
│              (feature spec, bug report, etc)             │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                    RALPH LOOP                            │
│                                                          │
│  1. Read plan + progress file                            │
│  2. Pick ONE task                                        │
│  3. Search codebase (don't assume not implemented)       │
│  4. Implement task                                       │
│  5. Run tests/validation                                 │
│  6. Update progress file                                 │
│  7. Commit                                               │
│  8. Loop back to 1 (fresh context)                       │
│                                                          │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              <plan-name>_PROGRESS.md                     │
│                                                          │
│  - Task list with [x] / [ ] status                       │
│  - Notes and discoveries                                 │
│  - RALPH_DONE when complete                              │
└─────────────────────────────────────────────────────────┘
```

## Exit Conditions

The loop exits when:
1. **`RALPH_DONE`** appears in the progress file (work complete)
2. **Max iterations** reached (if specified)
3. **Ctrl+C** to stop manually

## Progress File

Ralph creates `<plan-name>_PROGRESS.md` in your current directory.

This is the **only artifact** left in your repo. It tracks:
- Task list with completion status
- What was done each iteration
- Notes and discoveries

Example:
```markdown
# Progress: my-feature

## Status
IN_PROGRESS

## Task List
- [x] Add user model
- [x] Create API endpoint
- [ ] Add validation
- [ ] Write tests

## Completed This Iteration
- Create API endpoint: Added POST /users endpoint

## Notes
- Found existing validation helper in src/utils
```

## Writing Plan Files

### Simple Example
```markdown
# Fix: Login Button Not Working

## Problem
The login button on /login page doesn't submit the form.

## Expected
Clicking login should POST to /api/auth/login and redirect on success.

## Files
- src/pages/login.tsx
- src/api/auth.ts
```

### Feature Example
```markdown
# Feature: User Authentication

## Goal
Add JWT-based authentication to the API.

## Requirements
- Login endpoint that returns JWT token
- Middleware to validate tokens
- Protected routes require valid token
- Token expiry: 24 hours

## Acceptance Criteria
- POST /auth/login with valid credentials returns token
- Protected endpoints return 401 without token
- Tokens expire after 24 hours
```

### Refactor Example
```markdown
# Refactor: Extract Database Layer

## Goal
Move all database calls to a dedicated data access layer.

## Current State
Database queries scattered throughout API handlers.

## Target State
- src/db/ folder with query functions
- Handlers call db functions, not raw queries
- All queries in one place for optimization

## Constraints
- Don't change API responses
- Keep existing tests passing
```

## Tips

### Use Plan Mode First
For complex features, run plan mode first:
```bash
~/ralph/ralph.sh ./feature.md plan
```
Review the task list in the progress file, then run build mode:
```bash
~/ralph/ralph.sh ./feature.md build
```

### Watch It Work
Ralph runs in your terminal - watch for issues and Ctrl+C if it goes off track.

### Check Progress
The progress file shows what Ralph is doing:
```bash
cat ./my-plan_PROGRESS.md
```

## Requirements

- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Bash shell
- Git (optional, for commits)

## Files

```
~/ralph/
├── ralph.sh          # Main script
├── PROMPT_plan.md    # Plan mode prompt template
├── PROMPT_build.md   # Build mode prompt template
└── README.md
```

## How the Loop Works (Technical)

Each iteration:
1. Script substitutes `${PLAN_FILE}`, `${PROGRESS_FILE}`, `${PLAN_NAME}` in prompt
2. Prompt is piped to `claude -p --dangerously-skip-permissions`
3. Claude reads plan/progress, does ONE task, updates progress file
4. Script checks for `RALPH_DONE` in progress file
5. If not done, loops back with fresh context

The progress file is the **shared state** between iterations. Each Claude invocation starts fresh but reads/writes the progress file to track state.

## License

MIT

---

*Inspired by [@GeoffreyHuntley](https://x.com/GeoffreyHuntley)'s Ralph technique.*

# Usage Guide

This guide explains **what Ralph does**, **why you'd use each feature**, and **how to get the best results**.

---

## :thinking: What Problem Does Ralph Solve?

Imagine you want to add a new feature to your codebase. Normally you'd:

1. Think about what needs to be done
2. Break it into tasks
3. Implement each task one by one
4. Test, fix, repeat
5. Commit your changes

**Ralph automates this entire process.** You write a plan describing what you want, and Ralph figures out the tasks, implements them, tests them, and commits them—all autonomously.

---

## :rocket: The Two Modes Explained

Ralph has two modes: **Plan** and **Build**. Understanding when to use each is key to getting great results.

### :mag: Plan Mode — "Let me think about this first"

```bash
ralph ./feature.md plan
```

**What it does:**

Plan mode is like asking a senior developer to review your feature request and create a task breakdown. Ralph will:

1. **Read your plan** to understand what you want
2. **Explore your codebase** using subagents from multiple perspectives
3. **Identify gaps** between current state and desired state
4. **Consider contingencies** - what could go wrong? What are the dependencies?
5. **Create a task list** with logical ordering based on dependencies
6. **Write everything down** in a progress file
7. **Exit automatically** after creating the task list (runs once)

**Why use it:**

| Situation | Why Plan Mode Helps |
|:----------|:--------------------|
| Complex features | See the full scope before committing |
| Unfamiliar codebase | Let Ralph explore and document what exists |
| Want to review first | Check the approach before any code changes |
| Estimating work | Get a task breakdown to understand effort |

!!! tip "Plan mode is safe and automatic"
    Plan mode makes **zero code changes**. It only reads files and writes a progress file. It runs once then exits automatically—no need to press Ctrl+C or set max-iterations.

**Example output** (in `feature_PROGRESS.md`):

```markdown
## Analysis
The codebase already has a User model in src/models/user.ts.
Authentication middleware exists but doesn't validate JWTs.
No existing login endpoint found.

## Task List
- [ ] Task 1: Add JWT dependency to package.json
- [ ] Task 2: Create POST /auth/login endpoint
- [ ] Task 3: Update auth middleware to validate JWTs
- [ ] Task 4: Add tests for login flow
- [ ] Task 5: Update API documentation
```

---

### :hammer: Build Mode — "Go implement this"

```bash
ralph ./feature.md build
```

**What it does:**

Build mode is the autonomous implementation engine. Ralph will:

1. **Read the plan and progress file** to know what's done and what's left
2. **Pick ONE task** from the list (the next uncompleted one)
3. **Search the codebase** to make sure it's not already done
4. **Implement the task** by writing/modifying code
5. **Validate the work** by running tests, build, lint
6. **Update the progress file** marking the task complete
7. **Commit the changes** with a descriptive message
8. **Loop back** and repeat until all tasks are done

**Why use it:**

| Situation | Why Build Mode Helps |
|:----------|:---------------------|
| You have a clear plan | Ralph executes it autonomously |
| Repetitive implementation | Let Ralph handle the grunt work |
| Overnight runs | Set it running and review in the morning |
| After reviewing plan mode | You approved the approach, now execute |

!!! warning "Build mode writes code"
    Build mode **will modify your codebase**. Always review commits afterward, and use `max-iterations` for unattended runs.

---

## :arrows_counterclockwise: The Recommended Workflow

For best results, use **Plan → Review → Build**:

```bash
# Step 1: Let Ralph analyze and create a task breakdown
ralph ./my-feature.md plan

# Step 2: Review the progress file
cat ./my-feature_PROGRESS.md
# Does the task list make sense?
# Did Ralph understand your intent?
# Any tasks missing or wrong?

# Step 3: If it looks good, run build mode
ralph ./my-feature.md build
```

**Why this workflow?**

- **Catches misunderstandings early** — If Ralph misinterprets your plan, you'll see it in the task list before any code is written
- **Gives you control** — You can edit the progress file to add/remove/reorder tasks before building
- **Safer** — You review the approach before committing to it

---

## :shield: Safety Features

### Max Iterations

Limit how many tasks Ralph will complete:

```bash
# Stop after 10 iterations (tasks)
ralph ./feature.md build 10
```

**When to use:**

- Running unattended (overnight, CI/CD)
- Testing Ralph on a new codebase
- Large features where you want to review periodically

### Manual Stop

Press `Ctrl+C` at any time to stop Ralph. Your progress is saved—you can resume later by running the same command.

### Review Commits

Ralph commits after each task. If something goes wrong:

```bash
# See what Ralph did
git log --oneline -5

# Undo the last task
git revert HEAD

# Or reset multiple commits
git reset --hard HEAD~3
```

---

## :clipboard: The Progress File

The progress file is Ralph's memory between iterations. It tracks:

- **Status** — Is Ralph planning, building, or done?
- **Analysis** — What Ralph learned about your codebase
- **Task List** — All tasks with completion status
- **Notes** — Important discoveries and decisions

### Location

The progress file is created in your **current directory** (not where the plan file is):

| Plan File | Progress File |
|:----------|:--------------|
| `./feature.md` | `./feature_PROGRESS.md` |
| `./docs/auth.md` | `./auth_PROGRESS.md` |
| `/home/user/plans/api.md` | `./api_PROGRESS.md` |

### Status Values

| Status | Meaning | Set By | What to Do |
|:-------|:--------|:-------|:-----------|
| `IN_PROGRESS` | Ready for build mode | Plan mode | Run build mode |
| `RALPH_DONE` | All tasks complete! | Build mode only | Review the changes |

!!! warning "Critical Status Rules"
    - **Plan mode** always sets status to `IN_PROGRESS` and exits after 1 iteration
    - **Build mode** only writes `RALPH_DONE` after ALL tasks are verified complete
    - Plan mode should **NEVER** write `RALPH_DONE` under any circumstances
    - When in doubt, build mode leaves status as `IN_PROGRESS`
    - **The marker must be on its own line** to be detected (not inline with other text)

### Editing the Progress File

You can manually edit the progress file before running build mode:

- **Add tasks** — Insert new `- [ ] Task: description` lines
- **Remove tasks** — Delete lines you don't want
- **Reorder tasks** — Move lines to change execution order
- **Mark done** — Change `[ ]` to `[x]` to skip a task

---

## :zap: Quick Reference

### Commands

```bash
# Analyze and create task list (safe, runs once then exits)
ralph ./plan.md plan

# Implement all tasks autonomously until RALPH_DONE
ralph ./plan.md build

# Implement with a safety limit
ralph ./plan.md build 20

# Configuration commands
ralph config commit on      # Enable auto-commit (default)
ralph config commit off     # Disable auto-commit
ralph config commit status  # Show current setting

# Notification commands
ralph notify setup    # Configure notifications
ralph notify test     # Send a test notification
```

### Flags

| Flag | Description |
|:-----|:------------|
| `--help`, `-h` | Show help message |
| `--version`, `-v` | Show version |

---

## :gear: Configuration

### Auto-Commit

By default, Ralph commits after each iteration. You can disable this globally or per-plan.

#### Global Setting

```bash
# Disable auto-commit globally
ralph config commit off

# Re-enable auto-commit
ralph config commit on

# Check current setting
ralph config commit status
```

This setting is stored in `~/.ralph.env` and persists across sessions.

#### Per-Plan Override

Add `DO_NOT_COMMIT` on its own line anywhere in your plan file:

```markdown
# Feature: Experimental Widget

DO_NOT_COMMIT

## Goal
Try out a new widget implementation without committing changes.

## Requirements
- Build the widget
- Test locally
```

!!! tip "When to disable commits"
    - **Experimental work** — Try ideas without cluttering git history
    - **Large refactors** — Make many changes, then commit manually with a meaningful message
    - **Learning/testing** — Explore Ralph's behavior without affecting your repo

---

## :bulb: Tips for Success

<div class="grid cards" markdown>

-   :dart: **Write focused plans**

    ---

    Smaller, specific plans work better than large vague ones. "Add user login" beats "Improve authentication system".

-   :eyes: **Watch the first few iterations**

    ---

    Monitor Ralph initially to make sure it understands your codebase and intent correctly.

-   :memo: **Review the progress file**

    ---

    After plan mode, check if the task breakdown makes sense before running build mode.

-   :test_tube: **Have tests**

    ---

    Ralph runs your test suite to validate changes. Good tests = better results.

</div>

---

## :sos: Troubleshooting

### Ralph keeps doing the same task

The task might be failing validation. Check:

- Are tests passing?
- Is the build succeeding?
- Look at the terminal output for errors

### Ralph misunderstood my plan

Run plan mode again with a clearer plan file, or manually edit the progress file to fix the task list.

### Ralph is going in the wrong direction

Press `Ctrl+C` immediately, then:

1. Review what changed: `git diff HEAD~1`
2. Revert if needed: `git revert HEAD`
3. Clarify your plan or edit the progress file
4. Run again

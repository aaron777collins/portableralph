# How It Works

Technical deep-dive into Ralph's architecture and execution model.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         ralph.sh                                 │
│                    (Orchestration Loop)                          │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PROMPT_*.md                                 │
│              (Mode-specific instructions)                        │
│                                                                  │
│   PROMPT_plan.md  ──────►  Analysis & task breakdown            │
│   PROMPT_build.md ──────►  Implementation & validation          │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Claude CLI                                 │
│            claude -p --dangerously-skip-permissions              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Progress File                                  │
│              <plan-name>_PROGRESS.md                             │
│                                                                  │
│   • Shared state between iterations                              │
│   • Task list with completion status                             │
│   • RALPH_DONE signals completion                                │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Flow

### Initialization

```bash
~/ralph/ralph.sh ./feature.md build
```

1. Validate plan file exists
2. Determine progress file name
3. Create progress file if missing
4. Select prompt template
5. Send start notification

### The Loop

Each iteration:

```
1. Check exit conditions
   ├─ RALPH_DONE in progress file? → Exit
   └─ Max iterations reached? → Exit

2. Build prompt
   └─ Substitute ${PLAN_FILE}, ${PROGRESS_FILE}, ${PLAN_NAME}

3. Execute Claude
   └─ Claude reads files, implements task, updates progress

4. Post-iteration
   ├─ Send notification (every 5 iterations)
   ├─ Sleep 2 seconds
   └─ Loop back to step 1
```

### Termination

| Exit Condition | Meaning |
|:---------------|:--------|
| `RALPH_DONE` | Success - all tasks complete |
| Max iterations | Limit reached |
| `Ctrl+C` | Manual stop |

## Prompt Templates

### PROMPT_plan.md

Used in `plan` mode. Instructs Claude to:

1. Read and analyze the plan file
2. Explore the codebase thoroughly
3. Identify what exists vs. what's needed
4. Create a prioritized task breakdown
5. Update progress file with analysis

!!! info "Important"
    Plan mode makes **no code changes**—analysis only.

### PROMPT_build.md

Used in `build` mode. Instructs Claude to:

1. Read plan and progress files
2. Select ONE uncompleted task
3. Search codebase first (verify not already done)
4. Implement the task
5. Run validation (tests, build, lint)
6. Update progress file
7. Commit changes
8. Set `RALPH_DONE` if all tasks complete

!!! info "Important"
    Build mode does **one task per iteration**.

## State Management

### Fresh Context Each Iteration

Each Claude invocation starts fresh—no memory of previous iterations. The progress file is the **only** persistent state:

```markdown
# Progress: feature-name

## Status
IN_PROGRESS          ← Controls loop

## Task List
- [x] Completed       ← What's done
- [ ] Pending         ← What's left

## Notes
- Discoveries         ← Knowledge transfer
```

### Why Fresh Context?

| Benefit | Description |
|:--------|:------------|
| **No overflow** | Long sessions don't degrade |
| **Clean slate** | No accumulated confusion |
| **Explicit state** | Everything written down |
| **Debuggable** | Progress shows what happened |

## Variable Substitution

| Variable | Example |
|:---------|:--------|
| `${PLAN_FILE}` | `/home/user/repo/feature.md` |
| `${PROGRESS_FILE}` | `feature_PROGRESS.md` |
| `${PLAN_NAME}` | `feature` |

## Notifications

### Flow

```
notify.sh
    │
    ├──► Slack (webhook)
    ├──► Discord (webhook)
    ├──► Telegram (bot API)
    └──► Custom (your script)
```

Messages sent to **all** configured platforms. Unconfigured platforms silently skipped.

### Custom Script Interface

```bash
$1 = "🚀 Ralph Started\nPlan: feature\nMode: build"
```

Your script handles delivery. Exit code ignored.

## Files

```
~/ralph/
├── ralph.sh               # Orchestration loop
├── notify.sh              # Notification dispatcher
├── setup-notifications.sh # Setup wizard
├── PROMPT_plan.md         # Plan mode prompt
├── PROMPT_build.md        # Build mode prompt
├── .env.example           # Config template
└── docs/                  # Documentation
```

## Security

### dangerously-skip-permissions

Ralph uses `claude -p --dangerously-skip-permissions`:

- Allows any command execution
- Skips confirmation prompts
- Enables autonomous operation

!!! danger "Warning"
    Use with caution. Review commits. Set max-iterations for unattended runs.

### Credential Protection

- `.gitignore` blocks `.env*` files
- Config stored in `~/.ralph.env` (outside repo)
- Wizard sets `chmod 600` on config
- No credentials in prompt templates

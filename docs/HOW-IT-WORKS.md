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
│                                                                  │
│   • Reads plan file                                              │
│   • Reads progress file                                          │
│   • Executes ONE task                                            │
│   • Updates progress file                                        │
│   • Commits changes                                              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Progress File                                  │
│              <plan-name>_PROGRESS.md                             │
│                                                                  │
│   • Shared state between iterations                              │
│   • Task list with completion status                             │
│   • Notes and discoveries                                        │
│   • RALPH_DONE signals completion                                │
└─────────────────────────────────────────────────────────────────┘
```

## Execution Flow

### 1. Initialization

```bash
~/ralph/ralph.sh ./feature.md build
```

Ralph:
1. Validates the plan file exists
2. Determines progress file name (`feature_PROGRESS.md`)
3. Creates progress file if it doesn't exist
4. Selects prompt template based on mode
5. Sends start notification (if configured)

### 2. The Loop

Each iteration:

```
┌──────────────────────────────────────────────────────────────┐
│ 1. Check exit conditions                                      │
│    └─► RALPH_DONE in progress file? → Exit                   │
│    └─► Max iterations reached? → Exit                        │
│                                                               │
│ 2. Build prompt                                               │
│    └─► Load PROMPT_build.md template                         │
│    └─► Substitute ${PLAN_FILE}, ${PROGRESS_FILE}, ${PLAN_NAME}│
│                                                               │
│ 3. Execute Claude                                             │
│    └─► echo "$PROMPT" | claude -p --dangerously-skip-permissions │
│    └─► Claude reads files, implements task, updates progress  │
│                                                               │
│ 4. Post-iteration                                             │
│    └─► Send notification (every 5 iterations)                │
│    └─► Sleep 2 seconds                                       │
│    └─► Loop back to step 1                                   │
└──────────────────────────────────────────────────────────────┘
```

### 3. Termination

The loop exits when:
- `RALPH_DONE` appears in progress file (success)
- Max iterations reached (limit)
- User presses Ctrl+C (manual)

## Prompt Templates

### PROMPT_plan.md

Used in `plan` mode. Instructs Claude to:

1. Read and analyze the plan file
2. Explore the codebase thoroughly
3. Identify what exists vs. what's needed
4. Create a prioritized task breakdown
5. Update progress file with analysis

**Key rule:** No implementation—planning only.

### PROMPT_build.md

Used in `build` mode. Instructs Claude to:

1. Read plan and progress files
2. Select ONE uncompleted task
3. Search codebase before implementing (verify not already done)
4. Implement the task
5. Run validation (tests, build, lint)
6. Update progress file
7. Commit changes
8. Set `RALPH_DONE` if all tasks complete

**Key rule:** One task per iteration.

## State Management

### Progress File as Shared State

Each Claude invocation starts with **fresh context**—no memory of previous iterations. The progress file is the only persistent state:

```markdown
# Progress: feature-name

## Status
IN_PROGRESS          ← Controls loop continuation

## Task List
- [x] Completed task  ← Tracks what's done
- [ ] Pending task    ← Tracks what's left

## Completed This Iteration
- Task details        ← Audit trail

## Notes
- Discoveries         ← Knowledge transfer between iterations
```

### Why Fresh Context?

1. **Prevents context overflow** - Long sessions don't degrade quality
2. **Clean slate each task** - No accumulated confusion
3. **Explicit state** - Everything important is written down
4. **Debuggable** - Progress file shows exactly what happened

## Variable Substitution

The prompt templates use these variables:

| Variable | Value | Example |
|----------|-------|---------|
| `${PLAN_FILE}` | Absolute path to plan | `/home/user/repo/feature.md` |
| `${PROGRESS_FILE}` | Progress file name | `feature_PROGRESS.md` |
| `${PLAN_NAME}` | Plan basename without .md | `feature` |

Substitution happens via `sed` before passing to Claude:

```bash
PROMPT=$(cat "$PROMPT_TEMPLATE" | \
    sed "s|\${PLAN_FILE}|$PLAN_FILE_ABS|g" | \
    sed "s|\${PROGRESS_FILE}|$PROGRESS_FILE|g" | \
    sed "s|\${PLAN_NAME}|$PLAN_BASENAME|g")
```

## Notifications

### notify.sh

Multi-platform notification dispatcher:

```
┌─────────────────────────────────────────────────────────────┐
│                      notify.sh                               │
│                                                              │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌────────┐        │
│  │  Slack  │  │ Discord │  │ Telegram │  │ Custom │        │
│  └────┬────┘  └────┬────┘  └────┬─────┘  └───┬────┘        │
│       │            │            │             │              │
│       ▼            ▼            ▼             ▼              │
│   Webhook       Webhook       Bot API      Your Script      │
└─────────────────────────────────────────────────────────────┘
```

Messages are sent to **all** configured platforms. Unconfigured platforms are silently skipped.

### Custom Script Interface

```bash
# Your script receives:
$1 = "🚀 Ralph Started\nPlan: feature\nMode: build\nRepo: myproject"

# Your script handles delivery however you need
# Exit code is ignored (notifications don't block Ralph)
```

## Files

```
~/ralph/
├── ralph.sh               # Main orchestration loop
├── notify.sh              # Notification dispatcher
├── setup-notifications.sh # Interactive setup wizard
├── PROMPT_plan.md         # Plan mode instructions for Claude
├── PROMPT_build.md        # Build mode instructions for Claude
├── .env.example           # Configuration template
├── .gitignore             # Protects credentials
├── README.md              # Overview and quick start
└── docs/                  # Detailed documentation
    ├── USAGE.md
    ├── NOTIFICATIONS.md
    ├── WRITING-PLANS.md
    └── HOW-IT-WORKS.md
```

## Security Considerations

### --dangerously-skip-permissions

Ralph uses `claude -p --dangerously-skip-permissions` which:
- Allows Claude to execute any command
- Skips confirmation prompts
- Enables autonomous operation

**Use with caution:**
- Run in isolated environments for untrusted plans
- Review commits before pushing
- Set max-iterations for unattended runs
- Monitor progress file for unexpected changes

### Credential Protection

- `.gitignore` blocks `.env*` files
- Config stored in `~/.ralph.env` (outside repo)
- Wizard sets `chmod 600` on config file
- No credentials in prompt templates

---

Next: [Writing Plans](./WRITING-PLANS.md) | [Usage Guide](./USAGE.md)

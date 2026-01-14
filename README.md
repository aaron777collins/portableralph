# PortableRalph

An autonomous AI development loop that works in **any repo**.

[**View Documentation →**](https://aaron777collins.github.io/portableralph/)

```bash
~/ralph/ralph.sh ./feature-plan.md
```

Ralph reads your plan, breaks it into tasks, and implements them one by one until done.

## Quick Start

**One-liner install:**
```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

**Or manual:**
```bash
git clone https://github.com/aaron777collins/portableralph.git ~/ralph
chmod +x ~/ralph/*.sh
```

**Run:**
```bash
~/ralph/ralph.sh ./my-plan.md
```

## How It Works

```
 Your Plan          Ralph Loop              Progress File
┌──────────┐      ┌─────────────┐         ┌─────────────┐
│ feature  │      │ 1. Read     │         │ - [x] Done  │
│   .md    │ ───► │ 2. Pick task│ ◄─────► │ - [ ] Todo  │
│          │      │ 3. Implement│         │ - [ ] Todo  │
└──────────┘      │ 4. Commit   │         │             │
                  │ 5. Repeat   │         │ RALPH_DONE  │
                  └─────────────┘         └─────────────┘
```

1. **You write** a plan file describing what to build
2. **Ralph breaks it** into discrete tasks (plan mode exits here)
3. **Each iteration**: pick one task → implement → validate → commit
4. **Loop exits** when `RALPH_DONE` appears in progress file (build mode)

## Usage

```bash
~/ralph/ralph.sh <plan-file> [mode] [max-iterations]
```

| Mode | Description |
|------|-------------|
| `build` | Implement tasks until RALPH_DONE (default) |
| `plan` | Analyze and create task list, then exit (runs once) |

```bash
# Examples
~/ralph/ralph.sh ./feature.md           # Build until done
~/ralph/ralph.sh ./feature.md plan      # Plan only (creates task list, exits)
~/ralph/ralph.sh ./feature.md build 20  # Build, max 20 iterations
```

## Plan File Format

```markdown
# Feature: User Authentication

## Goal
Add JWT-based authentication to the API.

## Requirements
- Login endpoint returns JWT token
- Middleware validates tokens on protected routes
- Tokens expire after 24 hours

## Acceptance Criteria
- POST /auth/login with valid credentials returns token
- Protected endpoints return 401 without valid token
```

See [Writing Effective Plans](https://aaron777collins.github.io/portableralph/writing-plans/) for more examples.

## Notifications

Get notified on Slack, Discord, Telegram, or custom integrations:

```bash
~/ralph/setup-notifications.sh  # Interactive setup
~/ralph/ralph.sh --test-notify   # Test your config
```

See [Notifications Guide](https://aaron777collins.github.io/portableralph/notifications/) for setup details.

## Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](https://aaron777collins.github.io/portableralph/usage/) | Complete command reference |
| [Writing Plans](https://aaron777collins.github.io/portableralph/writing-plans/) | How to write effective plans |
| [Notifications](https://aaron777collins.github.io/portableralph/notifications/) | Slack, Discord, Telegram setup |
| [How It Works](https://aaron777collins.github.io/portableralph/how-it-works/) | Technical architecture |

## Requirements

- [Claude Code CLI](https://platform.claude.com/docs/en/get-started) installed and authenticated
- Bash shell
- Git (optional, for auto-commits)

## Files

```
~/ralph/
├── ralph.sh               # Main loop
├── notify.sh              # Notification dispatcher
├── setup-notifications.sh # Setup wizard
├── PROMPT_plan.md         # Plan mode instructions
├── PROMPT_build.md        # Build mode instructions
├── .env.example           # Config template
└── docs/                  # Documentation
```

## For AI Agents

Invoke Ralph from another AI agent:

```bash
# Plan first (analyzes codebase, creates task list, exits after 1 iteration)
~/ralph/ralph.sh /absolute/path/to/plan.md plan

# Then build (implements tasks one by one until completion)
~/ralph/ralph.sh /absolute/path/to/plan.md build
```

**Important:**
- Plan mode runs once then exits automatically (sets status to `IN_PROGRESS`)
- Build mode loops until all tasks are complete, then writes `RALPH_DONE` on its own line in the Status section
- Only build mode should ever write the completion marker
- The marker must be on its own line to be detected (not inline with other text)

## License

MIT

---

Based on [The Ralph Playbook](https://github.com/ghuntley/how-to-ralph-wiggum) by [@GeoffreyHuntley](https://x.com/GeoffreyHuntley).

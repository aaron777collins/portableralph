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
2. **Ralph breaks it** into discrete tasks
3. **Each iteration**: pick one task → implement → validate → commit
4. **Loop exits** when `RALPH_DONE` appears in progress file

## Usage

```bash
~/ralph/ralph.sh <plan-file> [mode] [max-iterations]
```

| Mode | Description |
|------|-------------|
| `build` | Implement tasks (default) |
| `plan` | Analyze and create task list only |

```bash
# Examples
~/ralph/ralph.sh ./feature.md           # Build until done
~/ralph/ralph.sh ./feature.md plan      # Plan only
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
# Run until RALPH_DONE
~/ralph/ralph.sh /absolute/path/to/plan.md build

# Plan only
~/ralph/ralph.sh /absolute/path/to/plan.md plan
```

Exit signal: Add `RALPH_DONE` to `<plan-name>_PROGRESS.md` when complete.

## License

MIT

---

Based on [The Ralph Playbook](https://github.com/ghuntley/how-to-ralph-wiggum) by [@GeoffreyHuntley](https://x.com/GeoffreyHuntley).

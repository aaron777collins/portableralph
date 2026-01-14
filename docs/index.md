# PortableRalph

An autonomous AI development loop that works in **any repo**.

<div class="grid cards" markdown>

-   :rocket: **Quick Start**

    ---

    Get up and running in under a minute with our one-liner installer.

    [:octicons-arrow-right-24: Installation](installation.md)

-   :books: **Write Plans**

    ---

    Learn how to write effective plans that Ralph can execute.

    [:octicons-arrow-right-24: Writing Plans](writing-plans.md)

-   :bell: **Notifications**

    ---

    Get notified on Slack, Discord, Telegram, or custom integrations.

    [:octicons-arrow-right-24: Notifications](notifications.md)

-   :gear: **How It Works**

    ---

    Deep dive into Ralph's architecture and execution model.

    [:octicons-arrow-right-24: How It Works](how-it-works.md)

</div>

## What is PortableRalph?

Ralph reads your plan, breaks it into tasks, and implements them one by one until done.

```bash
~/ralph/ralph.sh ./feature-plan.md
```

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

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/aaron777collins/portableralph.git ~/ralph
chmod +x ~/ralph/*.sh
```

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Bash shell
- Git (optional, for auto-commits)

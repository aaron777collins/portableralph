# PortableRalph

An autonomous AI development loop that works in **any repo**.

---

## :rocket: Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/aaron777collins/portableralph.git ~/ralph
chmod +x ~/ralph/*.sh
```

Then run:

```bash
~/ralph/ralph.sh ./feature-plan.md
```

---

## :gear: How It Works

Ralph reads your plan, breaks it into tasks, and implements them one by one until done.

```text
 Your Plan          Ralph Loop              Progress File
+-----------+      +--------------+         +--------------+
| feature   |      | 1. Read      |         | - [x] Done   |
|   .md     | ---> | 2. Pick task | <-----> | - [ ] Todo   |
|           |      | 3. Implement |         | - [ ] Todo   |
+-----------+      | 4. Commit    |         |              |
                   | 5. Repeat    |         | RALPH_DONE   |
                   +--------------+         +--------------+
```

1. **You write** a plan file describing what to build
2. **Ralph breaks it** into discrete tasks
3. **Each iteration**: pick one task → implement → validate → commit
4. **Loop exits** when `RALPH_DONE` appears in progress file

---

## :books: Documentation

| | Guide | Description |
|:--|:------|:------------|
| :octicons-download-24: | [Installation](installation.md) | Get up and running in under a minute |
| :octicons-terminal-24: | [Usage Guide](usage.md) | Complete command reference |
| :octicons-pencil-24: | [Writing Plans](writing-plans.md) | How to write effective plans |
| :octicons-bell-24: | [Notifications](notifications.md) | Slack, Discord, Telegram setup |
| :octicons-cpu-24: | [How It Works](how-it-works.md) | Technical architecture |

---

## :white_check_mark: Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Bash shell
- Git (optional, for auto-commits)

---

[Get Started :octicons-arrow-right-24:](installation.md){ .md-button .md-button--primary }
[View on GitHub :octicons-mark-github-24:](https://github.com/aaron777collins/portableralph){ .md-button }

# PortableRalph

<p class="subtitle" style="font-size: 1.4em; opacity: 0.8; margin-top: -0.5em;">
An autonomous AI development loop that works in <strong>any repo</strong>.
</p>

<div class="grid cards" markdown>

-   :rocket:{ .lg .middle } **Quick Start**

    ---

    Get up and running in under a minute with our one-liner installer.

    [:octicons-arrow-right-24: Installation](installation.md)

-   :books:{ .lg .middle } **Write Plans**

    ---

    Learn how to write effective plans that Ralph can execute autonomously.

    [:octicons-arrow-right-24: Writing Plans](writing-plans.md)

-   :bell:{ .lg .middle } **Notifications**

    ---

    Get notified on Slack, Discord, Telegram, or custom integrations.

    [:octicons-arrow-right-24: Notifications](notifications.md)

-   :gear:{ .lg .middle } **How It Works**

    ---

    Deep dive into Ralph's architecture and execution model.

    [:octicons-arrow-right-24: How It Works](how-it-works.md)

</div>

---

## :zap: One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

Then run Ralph on any plan:

```bash
ralph ./my-feature.md
```

---

## :sparkles: The Magic

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

<div class="grid" markdown>

:material-file-document-edit:{ .lg } **You write** a plan file describing what to build
{ .card }

:material-scissors-cutting:{ .lg } **Ralph breaks it** into discrete, actionable tasks
{ .card }

:material-autorenew:{ .lg } **Each iteration**: pick task → implement → validate → commit
{ .card }

:material-flag-checkered:{ .lg } **Loop exits** when `RALPH_DONE` appears in progress file
{ .card }

</div>

---

## :white_check_mark: Requirements

<div class="grid cards" markdown>

-   :simple-anthropic:{ .lg .middle } **Claude Code CLI**

    ---

    Install and authenticate the [Claude Code CLI](https://platform.claude.com/docs/en/get-started)

-   :octicons-terminal-24:{ .lg .middle } **Bash Shell**

    ---

    Available on macOS, Linux, and WSL

-   :octicons-git-branch-24:{ .lg .middle } **Git** *(optional)*

    ---

    For automatic commits after each task

</div>

---

<div class="grid" markdown>

[Get Started :octicons-arrow-right-24:](installation.md){ .md-button .md-button--primary .md-button--stretch }

[View on GitHub :octicons-mark-github-24:](https://github.com/aaron777collins/portableralph){ .md-button .md-button--stretch }

</div>

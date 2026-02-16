# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Testing
Run the comprehensive test suite (150+ tests across all platforms):
```bash
cd ~/ralph/tests
./run-all-tests.sh                  # Run all tests
./run-all-tests.sh --unit-only      # Unit tests only
./run-all-tests.sh --integration-only  # Integration tests only
./run-all-tests.sh --security-only  # Security tests only
./run-all-tests.sh --verbose        # Verbose output
./run-all-tests.sh --stop-on-failure  # Stop on first failure
```

PowerShell equivalent:
```powershell
cd ~\ralph\tests
.\run-all-tests.ps1
```

### Running Ralph
```bash
ralph ./plan.md            # Build mode (default) - implements tasks until completion
ralph ./plan.md plan       # Plan mode - analyzes and creates task list, then exits
ralph ./plan.md build 20   # Build mode with max 20 iterations
```

### Notifications
```bash
ralph notify setup   # Interactive setup wizard for Slack/Discord/Telegram/Email
ralph notify test    # Test notification configuration
```

## Architecture

### Core Loop Design
PortableRalph implements an autonomous AI development loop with two distinct modes:

1. **Plan Mode** (`PROMPT_plan.md`): Analyzes the plan file and generates a task list in the progress file. Runs once then exits with status `IN_PROGRESS`.

2. **Build Mode** (`PROMPT_build.md`): Picks one task per iteration, implements it, validates, commits (if auto-commit enabled), and updates progress. Continues until all tasks are complete, then writes `RALPH_DONE` marker.

The loop reads a plan markdown file, creates a progress file (`<plan-name>_PROGRESS.md`), and iteratively works through tasks. Key exit conditions:
- Plan mode: Always exits after 1 iteration
- Build mode: Exits when `RALPH_DONE` appears on its own line in the Status section
- Both: Max iterations reached or Ctrl+C

### Cross-Platform Support
Every script has both Bash (`.sh`) and PowerShell (`.ps1`) versions for true cross-platform compatibility:
- Unix/Linux/macOS: Use `.sh` scripts
- Windows: Use `.ps1` scripts (native) or `.sh` scripts (via Git Bash/WSL)
- Launcher scripts (`launcher.sh`, `launcher.bat`) auto-detect environment

### Configuration System
Configuration is stored in `~/.ralph.env` and loaded at startup. Key settings:
- `RALPH_MODEL`: Claude model to use (default: sonnet)
- `RALPH_AUTO_COMMIT`: Auto-commit after each iteration (default: true)
- `RALPH_NOTIFY_FREQUENCY`: Notification frequency (default: every 5 iterations)
- Notification settings for Slack, Discord, Telegram, Email

### Guardrails System
`RALPH_GUARDRAILS.md` captures project-specific lessons learned:
- Created and maintained by Claude during build mode
- Read by both plan and build modes
- Self-consolidates when exceeding 50 lines
- Prevents repeating the same mistakes across iterations

### Key Libraries
- `lib/constants.sh`: Centralized configuration constants (timeouts, retries, limits)
- `lib/platform-utils.sh/.ps1`: Cross-platform path handling and utilities
- `lib/validation.sh/.ps1`: Input validation functions (URLs, emails, paths, numeric)
- `lib/process-mgmt.sh/.ps1`: Process management utilities

### Notification System
Multi-platform notification support with smart batching:
- Slack/Discord: Webhook-based
- Telegram: Bot API
- Email: SMTP, SendGrid, or AWS SES with HTML templates
- Custom: User-provided scripts
- Email batching reduces spam (configurable delay/max)

### Security Features
- Input validation for all user inputs
- SSRF protection in URL validation
- Token masking in logs
- Secure config file permissions (600)
- No secrets in commits or logs

## Important Notes

- Always run tests after changes: `./tests/run-all-tests.sh`
- Progress files are created in the current working directory, not in ~/ralph
- The completion marker `RALPH_DONE` must be on its own line to be detected
- Plan mode never writes the completion marker - only build mode does
- Each iteration in build mode should implement exactly ONE task
- Auto-commit is controlled by `RALPH_AUTO_COMMIT` environment variable
- Notification frequency is controlled by `RALPH_NOTIFY_FREQUENCY` (default: every 5 iterations)
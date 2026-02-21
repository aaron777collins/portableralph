# PortableRalph

[![Deploy Documentation](https://github.com/aaron777collins/portableralph/actions/workflows/docs.yml/badge.svg)](https://github.com/aaron777collins/portableralph/actions/workflows/docs.yml)
[![Windows Compatibility](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml/badge.svg)](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml)
[![CI Tests](https://github.com/aaron777collins/portableralph/actions/workflows/ci.yml/badge.svg)](https://github.com/aaron777collins/portableralph/actions/workflows/ci.yml)

An autonomous AI development loop that works in **any repo**.

[**View Documentation →**](https://aaron777collins.github.io/portableralph/)

```bash
ralph ./feature-plan.md
```

Ralph reads your plan, breaks it into tasks, and implements them one by one until done.

## Quick Start

### Linux / macOS

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
ralph ./my-plan.md
```

### Windows

**PowerShell install:**
```powershell
irm https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.ps1 | iex
```

**Or manual:**
```powershell
git clone https://github.com/aaron777collins/portableralph.git $env:USERPROFILE\ralph
```

**Run (PowerShell):**
```powershell
ralph .\my-plan.md
```

**Run (Command Prompt):**
```cmd
launcher.bat ralph .\my-plan.md
```

**Note:** Windows users can use either PowerShell (`.ps1` scripts) or Git Bash (`.sh` scripts). The launcher scripts (`launcher.sh` and `launcher.bat`) automatically detect your environment and run the appropriate script version.

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

### Unix/Linux/macOS
```bash
ralph <plan-file> [mode] [max-iterations]
ralph notify <setup|test>
```

### Windows (PowerShell)
```powershell
ralph <plan-file> [mode] [max-iterations]
ralph notify <setup|test>
```

### Windows (Command Prompt)
```cmd
launcher.bat ralph <plan-file> [mode] [max-iterations]
launcher.bat notify <setup|test>
```

| Mode | Description |
|------|-------------|
| `build` | Implement tasks until RALPH_DONE (default) |
| `plan` | Analyze and create task list, then exit (runs once) |

### Examples

**Unix/Linux/macOS:**
```bash
ralph ./feature.md           # Build until done
ralph ./feature.md plan      # Plan only (creates task list, exits)
ralph ./feature.md build 20  # Build, max 20 iterations
```

**Windows (PowerShell):**
```powershell
ralph .\feature.md           # Build until done
ralph .\feature.md plan      # Plan only (creates task list, exits)
ralph .\feature.md build 20  # Build, max 20 iterations
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

Get notified on Slack, Discord, Telegram, Email, or custom integrations:

```bash
ralph notify setup  # Interactive setup wizard
ralph notify test   # Test your config
```

### Supported Platforms

- **Slack** - Webhook integration
- **Discord** - Webhook integration
- **Telegram** - Bot API
- **Email** - SMTP, SendGrid, or AWS SES
- **Custom** - Your own notification scripts

### Email Setup

Ralph supports multiple email delivery methods:

#### SMTP (Gmail, Outlook, etc.)

```bash
export RALPH_EMAIL_TO="you@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"
export RALPH_EMAIL_SMTP_SERVER="smtp.gmail.com"
export RALPH_EMAIL_PORT="587"
export RALPH_EMAIL_USER="your-email@gmail.com"
export RALPH_EMAIL_PASS="your-app-password"
```

**Gmail users:** Use an [App Password](https://support.google.com/accounts/answer/185833), not your regular password.

#### SendGrid API

```bash
export RALPH_EMAIL_TO="you@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"
export RALPH_SENDGRID_API_KEY="SG.your-api-key"
```

#### AWS SES

```bash
export RALPH_EMAIL_TO="you@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"
export RALPH_AWS_SES_REGION="us-east-1"
export RALPH_AWS_ACCESS_KEY_ID="your-access-key"
export RALPH_AWS_SECRET_KEY="your-secret-key"
```

### Email Features

- **HTML Templates** - Beautiful, responsive email layouts
- **Text Fallback** - Plain text version for all emails
- **Smart Batching** - Reduces email spam by batching progress updates
- **Priority Handling** - Errors and warnings always send immediately
- **Multiple Recipients** - Comma-separated email addresses

Configure batching behavior:

```bash
export RALPH_EMAIL_BATCH_DELAY="300"  # Wait 5 minutes before sending batch
export RALPH_EMAIL_BATCH_MAX="10"     # Send when 10 notifications queued
export RALPH_EMAIL_HTML="true"        # Use HTML templates (default)
```

Set `RALPH_EMAIL_BATCH_DELAY="0"` to disable batching and send every notification immediately.

### Notification Frequency

Control how often you receive progress notifications by setting `RALPH_NOTIFY_FREQUENCY` in `~/.ralph.env`:

```bash
# Send notification every 5 iterations (default)
export RALPH_NOTIFY_FREQUENCY=5

# Send notification every iteration
export RALPH_NOTIFY_FREQUENCY=1

# Send notification every 10 iterations
export RALPH_NOTIFY_FREQUENCY=10
```

Ralph always sends notifications for:
- Start
- Completion
- Errors
- First iteration

See [Notifications Guide](https://aaron777collins.github.io/portableralph/notifications/) for setup details.

## Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](https://aaron777collins.github.io/portableralph/usage/) | Complete command reference |
| [Writing Plans](https://aaron777collins.github.io/portableralph/writing-plans/) | How to write effective plans |
| [Notifications](https://aaron777collins.github.io/portableralph/notifications/) | Slack, Discord, Telegram setup |
| [How It Works](https://aaron777collins.github.io/portableralph/how-it-works/) | Technical architecture |
| [Testing Guide](TESTING.md) | Comprehensive testing documentation |

## Testing

Ralph includes a comprehensive test suite with 150+ automated tests covering all platforms:

**Unix/Linux/macOS:**
```bash
cd ~/ralph/tests
./run-all-tests.sh
```

**Windows (PowerShell):**
```powershell
cd ~\ralph\tests
.\run-all-tests.ps1
```

**Test Options:**
```bash
# Run specific test categories
./run-all-tests.sh --unit-only
./run-all-tests.sh --integration-only
./run-all-tests.sh --security-only

# Verbose output
./run-all-tests.sh --verbose

# Stop on first failure
./run-all-tests.sh --stop-on-failure
```

See [TESTING.md](TESTING.md) for complete testing documentation including:
- Test structure and organization
- Writing new tests
- Platform-specific testing
- CI/CD integration
- Troubleshooting

## Updating

Ralph includes a self-update system:

```bash
# Update to latest version
ralph update

# Check for updates
ralph update --check

# List all versions
ralph update --list

# Install specific version
ralph update 1.5.0

# Rollback to previous version
ralph rollback
```

## Requirements

### All Platforms
- [Claude Code CLI](https://platform.claude.com/docs/en/get-started) installed and authenticated
- Git (optional, for auto-commits)

### Unix/Linux/macOS
- Bash shell (usually pre-installed)

### Windows
- **Option 1 (Recommended):** PowerShell 5.1+ (pre-installed on Windows 10/11)
- **Option 2:** Git for Windows (includes Git Bash)
- **Option 3:** WSL (Windows Subsystem for Linux)

**Note:** PowerShell scripts (`.ps1`) are fully native on Windows and require no additional installation. Bash scripts (`.sh`) require Git Bash or WSL.

## Files

```
~/ralph/
├── ralph.sh               # Main loop (Bash)
├── ralph.ps1              # Main loop (PowerShell)
├── update.sh              # Self-update system (Bash)
├── update.ps1             # Self-update system (PowerShell)
├── notify.sh              # Notification dispatcher (Bash)
├── notify.ps1             # Notification dispatcher (PowerShell)
├── setup-notifications.sh # Setup wizard (Bash)
├── setup-notifications.ps1 # Setup wizard (PowerShell)
├── launcher.sh            # Auto-detect launcher (Unix)
├── launcher.bat           # Auto-detect launcher (Windows)
├── lib/
│   ├── platform-utils.sh  # Cross-platform utilities (Bash)
│   ├── platform-utils.ps1 # Cross-platform utilities (PowerShell)
│   ├── process-mgmt.sh    # Process management (Bash)
│   └── process-mgmt.ps1   # Process management (PowerShell)
├── PROMPT_plan.md         # Plan mode instructions
├── PROMPT_build.md        # Build mode instructions
├── CHANGELOG.md           # Version history
├── .env.example           # Config template
├── .gitattributes         # Line ending configuration
└── docs/                  # Documentation
```

### Cross-Platform Support

PortableRalph provides both Bash (`.sh`) and PowerShell (`.ps1`) versions of all scripts:

- **Unix/Linux/macOS:** Use `.sh` scripts directly
- **Windows (PowerShell):** Use `.ps1` scripts or the `ralph` command (if added to PATH)
- **Windows (Git Bash):** Use `.sh` scripts
- **Windows (WSL):** Use `.sh` scripts
- **Auto-detection:** Use `launcher.sh` or `launcher.bat` to automatically select the right script for your environment

The `.gitattributes` file ensures proper line endings across platforms (LF for `.sh`, CRLF for `.ps1` and `.bat`).

## Windows Support

PortableRalph is fully cross-platform with **CI-verified native Windows support**:

> **✅ CI Verified:** Windows compatibility is automatically tested on every push via GitHub Actions. See the [Windows Compatibility](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml) workflow badge above.

### Installation Options

1. **PowerShell (Recommended):** Native Windows support, no dependencies
   ```powershell
   irm https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.ps1 | iex
   ```

2. **Git Bash:** Use Bash scripts on Windows
   ```bash
   curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
   ```

3. **WSL:** Run Linux version in Windows Subsystem for Linux

### Windows Requirements

- **PowerShell 5.1+** (pre-installed on Windows 10/11)
- **Execution Policy:** Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` if scripts are blocked
- **Claude Code CLI:** Must be installed and authenticated
- **Git for Windows:** Recommended for version control features

### Path Handling

PortableRalph automatically handles Windows and Unix path conventions:
- **Windows:** `C:\Users\name\project` or `C:/Users/name/project`
- **Unix:** `/home/name/project`
- **WSL:** `/mnt/c/Users/name/project` (automatically converted)

### Process Management

Windows-specific process management utilities are provided in `lib/process-mgmt.ps1`:
- `Start-BackgroundProcess` - Equivalent to `nohup`
- `Stop-ProcessSafe` - Equivalent to `kill`
- `Get-ProcessList` - Equivalent to `ps`
- `Find-ProcessByPattern` - Equivalent to `pgrep`
- `Stop-ProcessByPattern` - Equivalent to `pkill`

### Configuration

Configuration file location:
- **Windows:** `%USERPROFILE%\.ralph.env` (e.g., `C:\Users\YourName\.ralph.env`)
- **Unix:** `~/.ralph.env` (e.g., `/home/yourname/.ralph.env`)

### Troubleshooting

**PowerShell Execution Policy:**
If you see "running scripts is disabled", run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Line Endings:**
The `.gitattributes` file ensures correct line endings. If you manually edit files:
- `.sh` files must use LF (Unix) line endings
- `.ps1` and `.bat` files must use CRLF (Windows) line endings

## For AI Agents

Invoke Ralph from another AI agent:

**Unix/Linux/macOS:**
```bash
# Plan first (analyzes codebase, creates task list, exits after 1 iteration)
ralph /absolute/path/to/plan.md plan

# Then build (implements tasks one by one until completion)
ralph /absolute/path/to/plan.md build
```

**Windows (PowerShell):**
```powershell
# Plan first
ralph C:\absolute\path\to\plan.md plan

# Then build
ralph C:\absolute\path\to\plan.md build
```

**Important:**
- Plan mode runs once then exits automatically (sets status to `IN_PROGRESS`)
- Build mode loops until all tasks are complete, then writes `RALPH_DONE` on its own line in the Status section
- Only build mode should ever write the completion marker
- The marker must be on its own line to be detected (not inline with other text)

## For Maintainers: CI/CD Workflows

PortableRalph uses GitHub Actions for automated testing and deployment:

### CI Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **Windows Compatibility** | `.github/workflows/windows-test.yml` | Tests PowerShell scripts, batch files, and Windows integration |
| **CI Tests** | `.github/workflows/ci.yml` | General compatibility and linting tests |
| **Test Suite** | `.github/workflows/test.yml` | Full test suite execution |
| **Documentation** | `.github/workflows/docs.yml` | MkDocs documentation deployment |
| **Release** | `.github/workflows/release.yml` | Version releases |

### Windows CI Testing Details

The Windows CI workflow (`windows-test.yml`) automatically verifies:

1. **PowerShell Script Testing**
   - Syntax validation for all `.ps1` files
   - Help/version parameter testing
   - Dependency verification

2. **Batch File Testing**
   - `launcher.bat` functionality
   - Windows CMD environment compatibility

3. **Integration Testing**
   - Batch-to-PowerShell interop
   - End-to-end workflow simulation

4. **Notification System Testing**
   - Dry-run notification tests
   - Status reporting verification

### Running CI Locally

To test Windows changes locally before pushing:

```powershell
# Test PowerShell syntax
$scriptContent = Get-Content "ralph.ps1" -Raw
[System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]@())

# Test basic functionality
.\ralph.ps1 -Help
.\install.ps1 -Help
```

### CI Artifacts

The Windows CI generates a `windows-compatibility-report.md` artifact containing:
- Test results summary
- PowerShell version tested
- Platform information
- Recommendations

## Troubleshooting (Quick Reference)

### Windows Issues

| Problem | Solution |
|---------|----------|
| Scripts blocked | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| Line ending errors (`'\r': command not found`) | `git config core.autocrlf input` and re-clone |
| `claude: command not found` | Install [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) |
| Path issues in WSL | Use `/mnt/c/...` paths, not `C:\...` |

### All Platforms

| Problem | Solution |
|---------|----------|
| Ralph command not found | Add alias: `alias ralph="~/ralph/ralph.sh"` |
| Tasks repeating | Check build/test errors; mark completed tasks manually |
| Notifications failing | Run `ralph notify test` to diagnose |

See [Troubleshooting Guide](docs/TROUBLESHOOTING.md) for detailed solutions.

## License

MIT

---

Based on [The Ralph Playbook](https://github.com/ghuntley/how-to-ralph-wiggum) by [@GeoffreyHuntley](https://x.com/GeoffreyHuntley).

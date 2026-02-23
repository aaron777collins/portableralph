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
# Clone the repository
git clone https://github.com/aaron777collins/portableralph.git ~/ralph

# Make scripts executable
chmod +x ~/ralph/*.sh

# Add to PATH (optional)
echo 'export PATH="$HOME/ralph:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or create alias
echo 'alias ralph="$HOME/ralph/ralph.sh"' >> ~/.bashrc
source ~/.bashrc
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
# Clone the repository
git clone https://github.com/aaron777collins/portableralph.git $env:USERPROFILE\ralph

# Navigate to the directory
cd $env:USERPROFILE\ralph

# Test PowerShell execution policy (may need to adjust)
Get-ExecutionPolicy

# If needed, set execution policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Add to PATH (optional)
$env:PATH += ";$env:USERPROFILE\ralph"

# Or create PowerShell alias (add to $PROFILE)
New-Alias -Name ralph -Value $env:USERPROFILE\ralph\ralph.ps1
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

## Configuration

Ralph is configured via `~/.ralph.env`. Available settings:

```bash
# Claude model to use (default: sonnet)
export RALPH_MODEL="sonnet"
# Other options: claude-opus-4-6, claude-haiku-4-5-20251001, etc.

# Auto-commit after each iteration (default: true)
export RALPH_AUTO_COMMIT="true"

# Stream Claude output to the terminal in real-time (default: true)
# Requires jq. Falls back to non-streaming if jq is not installed.
# Set to false to capture output and display after each iteration completes.
export RALPH_STREAM_OUTPUT="true"
```

You can also override the model per-run via environment variable:

```bash
RALPH_MODEL=claude-opus-4-6 ralph ./plan.md
```

Or use the config command for auto-commit:

```bash
ralph config commit off   # Disable auto-commit
ralph config commit on    # Enable auto-commit
```

### Guardrails (Lessons Learned)

Ralph maintains a `RALPH_GUARDRAILS.md` file in your project directory that captures project-specific lessons learned across iterations. This prevents Claude from repeating the same mistakes (wrong test commands, style violations, broken patterns).

- **Created automatically** — Claude creates and appends to it when discovering project gotchas
- **Persists across iterations** — each new Claude session reads it at startup
- **You can seed it manually** — add your own rules before running Ralph:
  ```markdown
  - Always run `pytest -x` not `python -m pytest`
  - Use tabs for indentation (project convention)
  ```
- **Self-maintaining** — Claude consolidates entries when the file grows past ~50 lines

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

## Configuration

PortableRalph supports extensive configuration through environment variables. Create a configuration file to customize behavior:

**Create Configuration File:**
```bash
# Unix/Linux/macOS
touch ~/.ralph.env
chmod 600 ~/.ralph.env

# Windows (PowerShell)
New-Item -Path $env:USERPROFILE\.ralph.env -ItemType File -Force
```

## Core Settings

### Core Configuration

**API Settings:**
```bash
# Claude API Configuration
export CLAUDE_API_KEY="your-api-key-here"           # Required: Your Claude API key
export CLAUDE_MODEL="claude-3-sonnet-20240229"      # Optional: Default model to use
export CLAUDE_TIMEOUT=30                            # Optional: API timeout in seconds
export CLAUDE_RETRY_COUNT=3                         # Optional: Number of API retries
```

**Execution Settings:**
```bash
# Ralph Behavior Configuration
export RALPH_MAX_ITERATIONS=50                      # Maximum iterations per run
export RALPH_TASK_TIMEOUT=300                       # Task timeout in seconds (5 minutes)
export RALPH_LOG_LEVEL="INFO"                       # Log level: DEBUG, INFO, WARN, ERROR
export RALPH_DEBUG=false                            # Enable debug mode
export RALPH_TRACE=false                            # Enable trace mode (very verbose)
```

**File and Directory Settings:**
```bash
# Path Configuration
export RALPH_TEMP_DIR="/tmp/ralph"                  # Temporary files directory
export RALPH_LOG_DIR="$HOME/.ralph/logs"            # Log files directory
export RALPH_CONFIG_DIR="$HOME/.ralph"              # Configuration directory
export RALPH_BACKUP_DIR="$HOME/.ralph/backups"     # Backup files directory
```

**Git Integration:**
```bash
# Git Configuration
export RALPH_GIT_ENABLED=true                       # Enable automatic git commits
export RALPH_GIT_AUTO_PUSH=false                    # Automatically push commits
export RALPH_GIT_COMMIT_PREFIX="ralph:"             # Prefix for commit messages
export RALPH_GIT_BRANCH="ralph-dev"                 # Branch for Ralph commits
```

## Notification Settings

### Notification Configuration

**Global Notification Settings:**
```bash
# Notification Behavior
export RALPH_NOTIFY_FREQUENCY=5                     # Notify every N iterations
export RALPH_NOTIFY_ENABLED=true                    # Enable notifications
export RALPH_NOTIFY_ON_START=true                   # Notify when Ralph starts
export RALPH_NOTIFY_ON_ERROR=true                   # Notify on errors
export RALPH_NOTIFY_ON_COMPLETION=true              # Notify when Ralph completes
```

**Slack Configuration:**
```bash
# Slack Integration
export RALPH_SLACK_ENABLED=true                     # Enable Slack notifications
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
export RALPH_SLACK_CHANNEL="#general"               # Target channel (optional)
export RALPH_SLACK_USERNAME="Ralph"                 # Bot username
export RALPH_SLACK_EMOJI=":robot_face:"             # Bot emoji
export RALPH_SLACK_MENTION_ON_ERROR="@channel"      # Mention on errors
```

**Discord Configuration:**
```bash
# Discord Integration
export RALPH_DISCORD_ENABLED=true                   # Enable Discord notifications
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR/WEBHOOK/URL"
export RALPH_DISCORD_USERNAME="Ralph"               # Bot username
export RALPH_DISCORD_AVATAR_URL="https://example.com/ralph-avatar.png"
```

**Telegram Configuration:**
```bash
# Telegram Integration
export RALPH_TELEGRAM_ENABLED=true                  # Enable Telegram notifications
export RALPH_TELEGRAM_BOT_TOKEN="your-bot-token"    # Bot token from @BotFather
export RALPH_TELEGRAM_CHAT_ID="your-chat-id"        # Chat ID to send messages to
export RALPH_TELEGRAM_PARSE_MODE="Markdown"         # Message format: Markdown or HTML
```

## Email Settings

### Email Configuration

**SMTP Configuration:**
```bash
# SMTP Settings
export RALPH_EMAIL_ENABLED=true                     # Enable email notifications
export RALPH_EMAIL_TO="you@example.com"             # Recipient email
export RALPH_EMAIL_FROM="ralph@example.com"         # Sender email
export RALPH_EMAIL_SMTP_SERVER="smtp.gmail.com"     # SMTP server
export RALPH_EMAIL_PORT="587"                       # SMTP port
export RALPH_EMAIL_USER="your-email@gmail.com"      # SMTP username
export RALPH_EMAIL_PASS="your-app-password"         # SMTP password (use app password for Gmail)
export RALPH_EMAIL_TLS=true                         # Enable TLS encryption
```

**Email Batching Configuration:**
```bash
# Email Batching Settings
export RALPH_EMAIL_BATCH_ENABLED=true               # Enable email batching
export RALPH_EMAIL_BATCH_DELAY=300                  # Batch delay in seconds (5 minutes)
export RALPH_EMAIL_BATCH_MAX=10                     # Maximum notifications per batch
export RALPH_EMAIL_HTML=true                        # Use HTML email templates
export RALPH_EMAIL_TEMPLATE_DIR="$HOME/.ralph/templates" # Custom template directory
```

**SendGrid Configuration:**
```bash
# SendGrid API Settings
export RALPH_SENDGRID_ENABLED=true                  # Enable SendGrid
export RALPH_SENDGRID_API_KEY="SG.your-api-key"     # SendGrid API key
export RALPH_EMAIL_TO="you@example.com"             # Recipient email
export RALPH_EMAIL_FROM="ralph@yourdomain.com"      # Sender email (must be verified)
```

**AWS SES Configuration:**
```bash
# AWS SES Settings
export RALPH_AWS_SES_ENABLED=true                   # Enable AWS SES
export RALPH_AWS_SES_REGION="us-east-1"             # AWS region
export RALPH_AWS_ACCESS_KEY_ID="your-access-key"    # AWS access key
export RALPH_AWS_SECRET_KEY="your-secret-key"       # AWS secret key
export RALPH_EMAIL_TO="you@example.com"             # Recipient email
export RALPH_EMAIL_FROM="ralph@yourdomain.com"      # Sender email (must be verified in SES)
```

## Advanced Settings

### Advanced Configuration

**Performance Settings:**
```bash
# Performance Optimization
export RALPH_PARALLEL_TASKS=false                   # Enable parallel task processing
export RALPH_MAX_CONCURRENT=4                       # Maximum concurrent operations
export RALPH_MEMORY_LIMIT=1048576                   # Memory limit in KB (1GB)
export RALPH_CPU_LIMIT=200                          # CPU limit as percentage (200% = 2 cores)
export RALPH_IO_TIMEOUT=60                          # I/O operation timeout in seconds
```

**Security Settings:**
```bash
# Security Configuration
export RALPH_SECURE_MODE=true                       # Enable security features
export RALPH_MASK_SECRETS=true                      # Mask secrets in logs
export RALPH_VERIFY_SSL=true                        # Verify SSL certificates
export RALPH_ALLOWED_HOSTS="github.com,api.anthropic.com" # Allowed network hosts
export RALPH_DISABLE_SHELL_EXEC=false               # Disable shell command execution
```

**Development Settings:**
```bash
# Development Configuration
export RALPH_DEV_MODE=false                         # Enable development features
export RALPH_MOCK_API=false                         # Use mock API responses
export RALPH_SAVE_REQUESTS=false                    # Save API requests/responses
export RALPH_VALIDATE_CONFIG=true                   # Validate configuration on startup
export RALPH_PROFILE_PERFORMANCE=false              # Enable performance profiling
```

## Environment-Specific Settings

### Environment-Specific Configurations

**Production Environment:**
```bash
# ~/.ralph.env - Production settings
export RALPH_LOG_LEVEL="WARN"
export RALPH_DEBUG=false
export RALPH_MAX_ITERATIONS=100
export RALPH_NOTIFY_FREQUENCY=10
export RALPH_EMAIL_BATCH_DELAY=600
export RALPH_SECURE_MODE=true
export RALPH_VERIFY_SSL=true
```

**Development Environment:**
```bash
# ~/.ralph.env - Development settings
export RALPH_LOG_LEVEL="DEBUG"
export RALPH_DEBUG=true
export RALPH_MAX_ITERATIONS=10
export RALPH_NOTIFY_FREQUENCY=1
export RALPH_DEV_MODE=true
export RALPH_PROFILE_PERFORMANCE=true
```

**Testing Environment:**
```bash
# ~/.ralph.env - Testing settings
export RALPH_LOG_LEVEL="INFO"
export RALPH_MAX_ITERATIONS=5
export RALPH_NOTIFY_ENABLED=false
export RALPH_GIT_ENABLED=false
export RALPH_MOCK_API=true
```

## Configuration Management

### Configuration Management

**Loading Configuration:**
```bash
# Ralph automatically loads configuration from:
# 1. ~/.ralph.env (user configuration)
# 2. ./.ralph.env (project configuration)
# 3. Environment variables (highest priority)

# Check loaded configuration
ralph --config

# Validate configuration
ralph --validate-config
```

**Configuration Templates:**
```bash
# Generate default configuration
ralph --generate-config > ~/.ralph.env

# Generate specific configuration
ralph --generate-config --template production > ~/.ralph.env
ralph --generate-config --template development > ~/.ralph.env
```

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
| [Security Guide](docs/SECURITY.md) | Security best practices and guidelines |

## Security Best Practices

🔒 **Security is a top priority for PortableRalph.** The project has passed comprehensive security audits and follows industry best practices.

### Quick Security Setup

1. **Secure Configuration:**
   ```bash
   # Create secure config file
   touch ~/.ralph.env
   chmod 600 ~/.ralph.env  # Owner read/write only
   ```

2. **Never Hardcode Secrets:**
   ```bash
   # ✅ Good - use environment variables
   export CLAUDE_API_KEY="your-key-here"
   export RALPH_SLACK_WEBHOOK_URL="your-webhook-here"
   
   # ❌ Bad - don't hardcode in scripts
   CLAUDE_API_KEY="sk-ant-api03-hardcoded"
   ```

3. **Use HTTPS Only:**
   ```bash
   # ✅ Good - secure webhooks
   export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
   
   # ❌ Bad - insecure HTTP
   export RALPH_SLACK_WEBHOOK_URL="http://insecure.example.com/webhook"
   ```

### Security Features ✅

- **✅ Input Validation** - All user inputs sanitized and validated
- **✅ Path Traversal Protection** - Prevents access outside intended directories  
- **✅ Command Injection Prevention** - Parameterized execution prevents malicious code
- **✅ HTTPS-Only Communication** - All network calls use secure TLS connections
- **✅ Credential Masking** - Sensitive tokens hidden in logs and output
- **✅ SSRF Protection** - Webhook URLs validated against private IP ranges
- **✅ Secure File Permissions** - Config files created with 600 permissions
- **✅ No Hardcoded Secrets** - Template-based configuration approach
- **✅ Comprehensive Security Testing** - 26+ security tests validate protection

### Security Audit Results

PortableRalph has passed comprehensive security audits with **0 critical vulnerabilities**:

- **Last Audit:** 2026-02-22
- **Status:** ✅ **PRODUCTION READY**  
- **Coverage:** Input validation, authentication, file permissions, secrets exposure
- **Test Results:** 26/26 security tests PASSED

See [Security Audit Report](security-audit-report.md) for detailed findings.

### Secure Deployment

**Development:**
```bash
# Use limited iterations for testing
ralph ./plan.md build 5

# Review changes before committing
git diff
```

**Production:**
```bash
# Use secrets manager (AWS, HashiCorp Vault, etc.)
# Set strict iteration limits
ralph ./plan.md build 20

# Enable secure logging
export RALPH_LOG_LEVEL="INFO"
```

## Report Security Issues

Found a security vulnerability? **Please report responsibly:**

1. **Do NOT create a public GitHub issue**
2. **Email:** security contact (see SECURITY.md)
3. **Include:** Description, reproduction steps, potential impact
4. **Timeline:** Allow 90 days for fix before public disclosure

For complete security guidance, see [Security Documentation](docs/SECURITY.md).

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

## Installation Verification

After installation, verify Ralph is working correctly:

**Test Installation:**
```bash
# Unix/Linux/macOS
ralph --help

# Windows (PowerShell)
ralph --help

# Windows (Command Prompt)
launcher.bat ralph --help
```

**Test Claude CLI Connection:**
```bash
claude --version
claude auth status
```

**Test Basic Functionality:**
```bash
# Create a simple test plan
echo "# Test Plan" > test-plan.md
echo "Create a hello.txt file with 'Hello World'" >> test-plan.md

# Run Ralph in plan mode (analysis only)
ralph test-plan.md plan

# Clean up
rm test-plan.md progress.md
```

**Verify Configuration:**
```bash
# Check environment variables
env | grep RALPH

# Test notifications (optional)
ralph notify test
```

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

> **✅ CI Verified:** Windows compatibility is automatically tested on every push via GitHub Actions with **31/31 tests passing**. See the [Windows Compatibility](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml) workflow badge above.

### Windows CI Testing

The [`windows-test.yml`](.github/workflows/windows-test.yml) GitHub Actions workflow provides comprehensive Windows validation:

- **PowerShell Script Testing:** Syntax validation, help/version parameters, dependency verification for all `.ps1` files
- **Batch File Testing:** `launcher.bat` functionality and Windows CMD environment compatibility  
- **Integration Testing:** Batch-to-PowerShell interop and end-to-end workflow simulation
- **Notification System:** Dry-run notification tests and status reporting verification
- **Windows-Specific Features:** Registry access, services, environment variables, file system operations

The CI generates a detailed compatibility report artifact documenting test results and platform information.

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
  - Tested on PowerShell 5.1, Windows PowerShell, and PowerShell 7+
  - JSON handling, web requests, and file system operations verified
- **Execution Policy:** Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` if scripts are blocked
- **Claude Code CLI:** Must be installed and authenticated  
- **Git for Windows:** Recommended for version control features
- **Windows Features:** Registry access, services query, and environment variables (automatically tested in CI)

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

## CI Artifacts

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

For comprehensive troubleshooting including:
- **Platform-specific issues** (Windows PowerShell, Unix permissions, macOS Gatekeeper)
- **Installation problems** (dependency issues, network failures, configuration errors)
- **Runtime issues** (task loops, permission errors, performance problems)
- **Advanced debugging** (log analysis, system diagnostics, performance profiling)

## License

MIT

---

Based on [The Ralph Playbook](https://github.com/ghuntley/how-to-ralph-wiggum) by [@GeoffreyHuntley](https://x.com/GeoffreyHuntley).

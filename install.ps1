# PortableRalph Installer
# PowerShell version for Windows support
# https://github.com/aaron777collins/portableralph
#
# Usage:
#   Interactive:  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.ps1" | Invoke-Expression
#   Direct:       .\install.ps1
#
# Options:
#   -Headless                    Non-interactive mode
#   -InstallDir DIR              Install location (default: ~\ralph)
#   -SlackWebhook URL            Slack webhook URL
#   -DiscordWebhook URL          Discord webhook URL
#   -TelegramToken TOKEN         Telegram bot token
#   -TelegramChat ID             Telegram chat ID
#   -CustomScript PATH           Custom notification script path
#   -SkipNotifications           Skip notification setup
#   -SkipShellConfig             Don't modify PowerShell profile
#   -Help                        Show this help

param(
    [switch]$Headless,
    [string]$InstallDir,
    [string]$SlackWebhook,
    [string]$DiscordWebhook,
    [string]$TelegramToken,
    [string]$TelegramChat,
    [string]$CustomScript,
    [switch]$SkipNotifications,
    [switch]$SkipShellConfig,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ============================================
# CONFIGURATION
# ============================================

$VERSION = "1.6.0"

# Load validation library if available (for validation after clone)
$ValidationLib = Join-Path $PSScriptRoot "lib\validation.ps1"
if (Test-Path $ValidationLib) {
    . $ValidationLib
}
$REPO_URL = "https://github.com/aaron777collins/portableralph.git"
$DEFAULT_INSTALL_DIR = Join-Path $env:USERPROFILE "ralph"

if (-not $InstallDir) {
    $InstallDir = $DEFAULT_INSTALL_DIR
}

# ============================================
# UTILITIES
# ============================================

function Write-Log {
    param([string]$Message)
    Write-Host "▸ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Warning2 {
    param([string]$Message)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error2 {
    param([string]$Message)
    Write-Host "✖ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "✔ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Read-PromptYN {
    param(
        [string]$PromptText,
        [string]$Default = "y"
    )

    if ($Headless) {
        return ($Default -match '^[Yy]')
    }

    $hint = if ($Default -match '^[Yy]') { "Y/n" } else { "y/N" }
    $answer = Read-Host "$PromptText [$hint]"

    if (-not $answer) {
        $answer = $Default
    }

    return ($answer -match '^[Yy]')
}

# ============================================
# CHECKS
# ============================================

function Test-Dependencies {
    $missing = @()

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missing += "git"
    }

    $aiTool = if ($env:RALPH_AI_TOOL) { $env:RALPH_AI_TOOL.ToLower().Trim() } else { "claude" }
    if (-not $aiTool) { $aiTool = "claude" }
    switch ($aiTool) {
        "claude" {
            if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
                Write-Warning2 "Claude Code CLI not found. Install from: https://docs.anthropic.com/en/docs/claude-code"
                Write-Warning2 "Ralph requires an AI CLI tool to run. Currently configured: claude"
            }
        }
        "codex" {
            if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
                Write-Warning2 "OpenAI Codex CLI not found. Install it and ensure 'codex' is on your PATH."
                Write-Warning2 "Ralph requires an AI CLI tool to run. Currently configured: codex"
            }
        }
        "opencode" {
            if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
                Write-Warning2 "OpenCode CLI not found. Install it and ensure 'opencode' is on your PATH."
                Write-Warning2 "Ralph requires an AI CLI tool to run. Currently configured: opencode"
            }
        }
        "custom" {
            if (-not $env:RALPH_AI_COMMAND) {
                Write-Warning2 "RALPH_AI_TOOL is 'custom' but RALPH_AI_COMMAND is not set."
            }
        }
        default {
            Write-Warning2 "No AI CLI tool configured. Set RALPH_AI_TOOL to: claude, codex, opencode, or custom."
        }
    }

    if ($missing.Count -gt 0) {
        Write-Error2 "Missing required dependencies: $($missing -join ', ')"
        Write-Error2 "Please install them and try again."
        exit 1
    }
}

function Test-ExistingInstall {
    if (Test-Path $InstallDir) {
        if (Test-Path (Join-Path $InstallDir "ralph.ps1")) {
            Write-Warning2 "Existing installation found at $InstallDir"
            if (Read-PromptYN "Update existing installation?") {
                Write-Log "Updating existing installation..."
                return $true
            } else {
                Write-Error2 "Installation cancelled."
                exit 1
            }
        }
    }
    return $false
}

# ============================================
# INSTALLATION
# ============================================

function Show-Banner {
    if ($Headless) {
        Write-Host "PortableRalph Installer v$VERSION"
        return
    }

    Write-Host ""
    Write-Host @"
    ____             __        __    __     ____        __      __
   / __ \____  _____/ /_____ _/ /_  / /__  / __ \____ _/ /___  / /_
  / /_/ / __ \/ ___/ __/ __ `/ __ \/ / _ \/ /_/ / __ `/ / __ \/ __ \
 / ____/ /_/ / /  / /_/ /_/ / /_/ / /  __/ _, _/ /_/ / / /_/ / / / /
/_/    \____/_/   \__/\__,_/_.___/_/\___/_/ |_|\__,_/_/ .___/_/ /_/
                                                     /_/
"@ -ForegroundColor Magenta
    Write-Host "An autonomous AI development loop that works in any repo" -ForegroundColor DarkGray
    Write-Host "v$VERSION" -ForegroundColor DarkGray
    Write-Host ""
}

function Install-Ralph {
    Write-Log "Installing PortableRalph to $InstallDir"

    if (Test-Path (Join-Path $InstallDir ".git")) {
        # Update existing
        Write-Host "Updating from git..." -NoNewline
        Push-Location $InstallDir
        git pull --quiet origin master 2>$null
        Pop-Location
        Write-Host " Done" -ForegroundColor Green
        Write-Success "Updated to latest version"
    } else {
        # Fresh install
        Write-Host "Cloning repository..." -NoNewline
        if (Test-Path $InstallDir) {
            Remove-Item -Path $InstallDir -Recurse -Force
        }
        git clone --quiet $REPO_URL $InstallDir 2>$null
        Write-Host " Done" -ForegroundColor Green
        Write-Success "Cloned repository"
    }
}

# ============================================
# SHELL CONFIGURATION
# ============================================

function Set-ShellConfig {
    if ($SkipShellConfig) {
        Write-Info "Skipping shell configuration (--SkipShellConfig)"
        return
    }

    Write-Log "Configuring PowerShell profile..."

    # Check if profile exists
    if (-not (Test-Path $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }

    # Check if already configured
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -match "ralph\.env") {
        Write-Info "PowerShell profile already configured"
        return
    }

    # Add configuration
    if ($Headless -or (Read-PromptYN "Add Ralph to your PowerShell profile?")) {
        $configBlock = @"

# PortableRalph
if (Test-Path "$env:USERPROFILE\.ralph.env") {
    Get-Content "$env:USERPROFILE\.ralph.env" | ForEach-Object {
        if (`$_ -match '^(?:export\s+)?(\w+)="?([^"]*)"?$') {
            Set-Item -Path "env:`$(`$matches[1])" -Value `$matches[2] -ErrorAction SilentlyContinue
        }
    }
}
function ralph { & "$InstallDir\ralph.ps1" @args }
"@
        Add-Content -Path $PROFILE -Value $configBlock -Encoding UTF8
        Write-Success "Added to PowerShell profile"
        Write-Info "Run '. `$PROFILE' or restart PowerShell to use 'ralph' command"
    }
}

# ============================================
# NOTIFICATIONS
# ============================================

function Set-Notifications {
    if ($SkipNotifications) {
        Write-Info "Skipping notification setup (--SkipNotifications)"
        return
    }

    # Check if any credentials provided via args
    if ($SlackWebhook -or $DiscordWebhook -or $TelegramToken -or $CustomScript) {
        Write-NotificationConfig
        return
    }

    # Interactive setup
    if ($Headless) {
        Write-Info "No notification credentials provided. Skipping setup."
        return
    }

    Write-Host ""
    Write-Log "Notification Setup"
    Write-Host ""
    Write-Host "Ralph can notify you on Slack, Discord, Telegram, or custom integrations."
    Write-Host ""

    if (-not (Read-PromptYN "Would you like to set up notifications?")) {
        Write-Info "Skipping notification setup. Run '.\ralph.ps1 notify setup' later."
        return
    }

    Write-Host ""
    Write-Host "Which platform(s) would you like to configure?"
    Write-Host ""
    Write-Host "  1) Slack" -ForegroundColor Cyan
    Write-Host "  2) Discord" -ForegroundColor Cyan
    Write-Host "  3) Telegram" -ForegroundColor Cyan
    Write-Host "  4) Custom script" -ForegroundColor Cyan
    Write-Host "  5) Skip for now" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-Host "Enter choice (1-5)"

    switch ($choice) {
        "1" { Setup-SlackInteractive }
        "2" { Setup-DiscordInteractive }
        "3" { Setup-TelegramInteractive }
        "4" { Setup-CustomInteractive }
        default { Write-Info "Skipping notification setup."; return }
    }

    Write-NotificationConfig
}

function Setup-SlackInteractive {
    Write-Host ""
    Write-Host "Slack Setup" -ForegroundColor White
    Write-Host ""
    Write-Host "To get a webhook URL:"
    Write-Host "  1. Go to https://api.slack.com/apps" -ForegroundColor Cyan
    Write-Host "  2. Create New App → From scratch"
    Write-Host "  3. Enable Incoming Webhooks"
    Write-Host "  4. Add webhook to workspace"
    Write-Host "  5. Copy the URL"
    Write-Host ""
    $script:SlackWebhook = Read-Host "Paste your Slack webhook URL"
}

function Setup-DiscordInteractive {
    Write-Host ""
    Write-Host "Discord Setup" -ForegroundColor White
    Write-Host ""
    Write-Host "To get a webhook URL:"
    Write-Host "  1. Right-click channel → Edit Channel"
    Write-Host "  2. Integrations → Webhooks → New Webhook"
    Write-Host "  3. Copy Webhook URL"
    Write-Host ""
    $script:DiscordWebhook = Read-Host "Paste your Discord webhook URL"
}

function Setup-TelegramInteractive {
    Write-Host ""
    Write-Host "Telegram Setup" -ForegroundColor White
    Write-Host ""
    Write-Host "Step 1: Create a bot"
    Write-Host "  1. Message @BotFather on Telegram" -ForegroundColor Cyan
    Write-Host "  2. Send /newbot and follow prompts"
    Write-Host "  3. Copy the bot token"
    Write-Host ""
    $script:TelegramToken = Read-Host "Paste your bot token"

    if ($TelegramToken) {
        Write-Host ""
        Write-Host "Step 2: Get your chat ID"
        Write-Host "  1. Start a chat with your bot"
        Write-Host "  2. Send any message"
        Write-Host "  3. Visit: https://api.telegram.org/bot$TelegramToken/getUpdates" -ForegroundColor Cyan
        Write-Host "  4. Find your chat ID in the response"
        Write-Host ""
        $script:TelegramChat = Read-Host "Paste your chat ID"
    }
}

function Setup-CustomInteractive {
    Write-Host ""
    Write-Host "Custom Script Setup" -ForegroundColor White
    Write-Host ""
    Write-Host "Your script receives the notification message as `$args[0]"
    Write-Host ""
    $script:CustomScript = Read-Host "Path to your notification script"
}

function Write-NotificationConfig {
    $configFile = Join-Path $env:USERPROFILE ".ralph.env"

    Write-Log "Writing notification configuration..."

    $configContent = @"
# PortableRalph Configuration
# Generated by installer on $(Get-Date)

# Auto-commit setting (default: true)
export RALPH_AUTO_COMMIT="true"

"@

    if ($SlackWebhook) {
        $configContent += "export RALPH_SLACK_WEBHOOK_URL=`"$SlackWebhook`"`n"
    }

    if ($DiscordWebhook) {
        $configContent += "export RALPH_DISCORD_WEBHOOK_URL=`"$DiscordWebhook`"`n"
    }

    if ($TelegramToken) {
        $configContent += "export RALPH_TELEGRAM_BOT_TOKEN=`"$TelegramToken`"`n"
        $configContent += "export RALPH_TELEGRAM_CHAT_ID=`"$TelegramChat`"`n"
    }

    if ($CustomScript) {
        $configContent += "export RALPH_CUSTOM_NOTIFY_SCRIPT=`"$CustomScript`"`n"
    }

    Set-Content -Path $configFile -Value $configContent -Encoding UTF8
    Write-Success "Configuration saved to $configFile"
}

# ============================================
# VERIFICATION
# ============================================

function Test-Installation {
    Write-Log "Verifying installation..."

    $errors = 0

    if (-not (Test-Path (Join-Path $InstallDir "ralph.ps1"))) {
        Write-Error2 "ralph.ps1 not found"
        $errors++
    }

    if (-not (Test-Path (Join-Path $InstallDir "notify.ps1"))) {
        Write-Error2 "notify.ps1 not found"
        $errors++
    }

    if (-not (Test-Path (Join-Path $InstallDir "PROMPT_build.md"))) {
        Write-Error2 "PROMPT_build.md not found"
        $errors++
    }

    if ($errors -gt 0) {
        Write-Error2 "Installation verification failed with $errors error(s)"
        exit 1
    }

    Write-Success "Installation verified"
}

# ============================================
# COMPLETION
# ============================================

function Show-Success {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Quick Start:" -ForegroundColor White
    Write-Host ""
    Write-Host "    # Reload your PowerShell profile" -ForegroundColor Cyan
    Write-Host "    . `$PROFILE" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    # Run Ralph on a plan file" -ForegroundColor Cyan
    Write-Host "    ralph .\my-plan.md" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    # Or use the full path" -ForegroundColor Cyan
    Write-Host "    & `"$InstallDir\ralph.ps1`" .\my-plan.md" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Documentation:" -ForegroundColor White
    Write-Host "    https://aaron777collins.github.io/portableralph/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Need help?" -ForegroundColor White
    Write-Host "    ralph -Help" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Help {
    Write-Host @"
PortableRalph Installer

Usage:
  .\install.ps1 [options]

Options:
  -Headless                Non-interactive mode (for scripts/CI)
  -InstallDir DIR          Install location (default: ~\ralph)
  -SlackWebhook URL        Slack webhook URL
  -DiscordWebhook URL      Discord webhook URL
  -TelegramToken TOKEN     Telegram bot token
  -TelegramChat ID         Telegram chat ID
  -CustomScript PATH       Custom notification script
  -SkipNotifications       Skip notification setup
  -SkipShellConfig         Don't modify PowerShell profile
  -Help                    Show this help

Examples:
  # Interactive install
  .\install.ps1

  # Headless with Slack
  .\install.ps1 -Headless -SlackWebhook "https://hooks.slack.com/..."

  # Custom install location
  .\install.ps1 -InstallDir "C:\tools\ralph"
"@
}

# ============================================
# MAIN
# ============================================

if ($Help) {
    Show-Help
    exit 0
}

Show-Banner

Write-Log "Starting installation..."
Write-Host ""

Test-Dependencies
Test-ExistingInstall | Out-Null
Install-Ralph
Set-ShellConfig
Set-Notifications
Test-Installation

Show-Success

# Exit with success code
exit 0

# Ralph - Autonomous AI Development Loop
# PowerShell version for Windows support
# Usage: .\ralph.ps1 <plan-file> [plan|build] [max-iterations]
#
# Examples:
#   .\ralph.ps1 .\my-feature-plan.md           # Build mode (default), runs until RALPH_DONE
#   .\ralph.ps1 .\my-feature-plan.md plan      # Plan mode, generates implementation tasks
#   .\ralph.ps1 .\my-feature-plan.md build 20  # Build mode, max 20 iterations
#
# Exit conditions:
#   - Plan mode: Exits after 1 iteration (planning complete)
#   - Build mode: "RALPH_DONE" appears in progress file
#   - Max iterations reached (if specified)
#   - Ctrl+C
#
# Progress is tracked in: <plan-name>_PROGRESS.md (in current directory)

param(
    [Parameter(Position=0)]
    [string]$PlanFile,

    [Parameter(Position=1)]
    [string]$Mode = "build",

    [Parameter(Position=2)]
    [int]$MaxIterations = 0,

    [switch]$Help,
    [switch]$Version,
    [switch]$TestNotify,
    [switch]$TestNotifications
)

$ErrorActionPreference = "Stop"

$RALPH_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$VERSION = "1.6.0"

# Load validation library
$ValidationLib = Join-Path $RALPH_DIR "lib\validation.ps1"
if (Test-Path $ValidationLib) {
    . $ValidationLib
}

# Log directory for errors
$LOG_DIR = Join-Path $env:USERPROFILE ".portableralph\logs"
if (-not (Test-Path $LOG_DIR)) {
    try {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    } catch {
        Write-Warning "Could not create log directory: $LOG_DIR"
        $LOG_DIR = Join-Path $env:TEMP "ralph_logs"
        try {
            New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
        } catch {
            $LOG_DIR = $null
        }
    }
}

# Error logging function
function Write-RalphError {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Log to file if LOG_DIR is available
    if ($LOG_DIR) {
        $logfile = Join-Path $LOG_DIR "ralph_$(Get-Date -Format 'yyyyMMdd').log"
        try {
            "[$timestamp] ERROR: $Message" | Out-File -FilePath $logfile -Append -ErrorAction SilentlyContinue
        } catch {
            # If logging to file fails, at least note it on stderr
            Write-Warning "Failed to write to log file: $logfile"
        }
    }

    # Always log to stderr
    Write-Host "Error: $Message" -ForegroundColor Red
}

# Load configuration
$CONFIG_FILE = Join-Path $env:USERPROFILE ".ralph.env"

function Load-Config {
    if (Test-Path $CONFIG_FILE) {
        Get-Content $CONFIG_FILE | ForEach-Object {
            $line = $_.Trim()
            if ($line -and !$line.StartsWith('#')) {
                # Parse environment variables (export VAR="value" or VAR="value")
                if ($line -match '^(?:export\s+)?(\w+)="?([^"]*)"?$') {
                    $varName = $matches[1]
                    $varValue = $matches[2]
                    Set-Item -Path "env:$varName" -Value $varValue -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

Load-Config

# Auto-commit setting (default: true)
if (-not $env:RALPH_AUTO_COMMIT) {
    $env:RALPH_AUTO_COMMIT = "true"
}

# Check if plan file contains DO_NOT_COMMIT directive
function Should-SkipCommitFromPlan {
    param([string]$PlanFile)

    if (-not (Test-Path $PlanFile)) {
        return $false
    }

    $inCodeBlock = $false
    foreach ($line in Get-Content $PlanFile) {
        if ($line -match '^```') {
            $inCodeBlock = -not $inCodeBlock
            continue
        }
        if (-not $inCodeBlock -and $line -match '^\s*DO_NOT_COMMIT\s*$') {
            return $true
        }
    }
    return $false
}

# Notification helper
function Send-Notification {
    param([string]$Message)

    $notifyScript = Join-Path $RALPH_DIR "notify.ps1"
    if (Test-Path $notifyScript) {
        & $notifyScript $Message 2>$null
    }
}

# Check if any notification platform is configured
function Test-NotificationsEnabled {
    return ($env:RALPH_SLACK_WEBHOOK_URL -or
            $env:RALPH_DISCORD_WEBHOOK_URL -or
            ($env:RALPH_TELEGRAM_BOT_TOKEN -and $env:RALPH_TELEGRAM_CHAT_ID) -or
            $env:RALPH_CUSTOM_NOTIFY_SCRIPT -or
            ($env:RALPH_EMAIL_TO -and $env:RALPH_EMAIL_FROM))
}

function Show-Usage {
    Write-Host "PortableRalph v$VERSION - Autonomous AI Development Loop" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\ralph.ps1 <plan-file> [mode] [max-iterations]"
    Write-Host "  .\ralph.ps1 -Help"
    Write-Host "  .\ralph.ps1 -Version"
    Write-Host ""
    Write-Host "Arguments:" -ForegroundColor Yellow
    Write-Host "  plan-file       Path to your plan/spec file (required)"
    Write-Host "  mode            'plan' or 'build' (default: build)"
    Write-Host "  max-iterations  Maximum loop iterations (default: unlimited)"
    Write-Host ""
    Write-Host "Modes:" -ForegroundColor Yellow
    Write-Host "  plan   Analyze codebase, create task list (runs once, then exits)"
    Write-Host "  build  Implement tasks one at a time until RALPH_DONE"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\ralph.ps1 .\feature.md              # Build until done"
    Write-Host "  .\ralph.ps1 .\feature.md plan         # Plan only (creates task list, exits)"
    Write-Host "  .\ralph.ps1 .\feature.md build 20     # Build, max 20 iterations"
    Write-Host ""
    Write-Host "Exit Conditions:" -ForegroundColor Yellow
    Write-Host "  - Plan mode: Exits after 1 iteration when task list is created"
    Write-Host "  - Build mode: RALPH_DONE appears in <plan-name>_PROGRESS.md"
    Write-Host "  - Max iterations reached (if specified)"
    Write-Host "  - Ctrl+C"
    Write-Host ""
    Write-Host "Progress File:" -ForegroundColor Yellow
    Write-Host "  Created as <plan-name>_PROGRESS.md in current directory"
    Write-Host ""
    Write-Host "More info: https://github.com/aaron777collins/portableralph"
    exit 0
}

function Show-Version {
    Write-Host "PortableRalph v$VERSION"
    exit 0
}

# Handle flags
if ($Help) { Show-Usage }
if ($Version) { Show-Version }
if ($TestNotify -or $TestNotifications) {
    & (Join-Path $RALPH_DIR "notify.ps1") --test
    exit 0
}

# Handle subcommands
if ($PlanFile -eq "update") {
    & (Join-Path $RALPH_DIR "update.ps1") @args
    exit $LASTEXITCODE
}

if ($PlanFile -eq "rollback") {
    & (Join-Path $RALPH_DIR "update.ps1") --rollback
    exit $LASTEXITCODE
}

if ($PlanFile -eq "notify") {
    switch ($Mode) {
        "setup" {
            & (Join-Path $RALPH_DIR "setup-notifications.ps1")
            exit $LASTEXITCODE
        }
        "test" {
            & (Join-Path $RALPH_DIR "notify.ps1") --test
            exit $LASTEXITCODE
        }
        default {
            Write-Host "Usage: .\ralph.ps1 notify <command>" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Commands:" -ForegroundColor Yellow
            Write-Host "  setup    Configure Slack, Discord, Telegram, or custom notifications"
            Write-Host "  test     Send a test notification to all configured platforms"
            exit 1
        }
    }
}

if ($PlanFile -eq "config") {
    $CONFIG_FILE = Join-Path $env:USERPROFILE ".ralph.env"

    # Helper to set a config value (handles both export and non-export patterns)
    function Set-ConfigValue {
        param([string]$Key, [string]$Value)

        if (Test-Path $CONFIG_FILE) {
            # Read all lines
            $lines = Get-Content $CONFIG_FILE
            $found = $false
            $newLines = @()

            foreach ($line in $lines) {
                if ($line -match "^(export\s+)?$Key=") {
                    # Update existing
                    $newLines += "export $Key=`"$Value`""
                    $found = $true
                } else {
                    $newLines += $line
                }
            }

            if (-not $found) {
                # Append to existing file
                $newLines += ""
                $newLines += "# Auto-commit setting"
                $newLines += "export $Key=`"$Value`""
            }

            Set-Content -Path $CONFIG_FILE -Value $newLines
        } else {
            # Create new file
            $content = @"
# PortableRalph Configuration
# Generated on $(Get-Date)

export $Key="$Value"
"@
            Set-Content -Path $CONFIG_FILE -Value $content
        }
    }

    switch ($Mode) {
        "commit" {
            switch ($MaxIterations) {
                { $_ -in @("on", "true", "yes", "1") } {
                    Set-ConfigValue "RALPH_AUTO_COMMIT" "true"
                    Write-Host "Auto-commit enabled" -ForegroundColor Green
                    Write-Host "Ralph will commit after each iteration."
                }
                { $_ -in @("off", "false", "no", "0") } {
                    Set-ConfigValue "RALPH_AUTO_COMMIT" "false"
                    Write-Host "Auto-commit disabled" -ForegroundColor Yellow
                    Write-Host "Ralph will NOT commit after each iteration."
                    Write-Host "You can also add DO_NOT_COMMIT on its own line in your plan file."
                }
                { $_ -in @("status", "") } {
                    Write-Host "Auto-commit setting:" -ForegroundColor Yellow
                    if ($env:RALPH_AUTO_COMMIT -eq "true") {
                        Write-Host "  Current: " -NoNewline
                        Write-Host "enabled" -ForegroundColor Green -NoNewline
                        Write-Host " (commits after each iteration)"
                    } else {
                        Write-Host "  Current: " -NoNewline
                        Write-Host "disabled" -ForegroundColor Yellow -NoNewline
                        Write-Host " (no automatic commits)"
                    }
                    Write-Host ""
                    Write-Host "Usage:" -ForegroundColor Yellow
                    Write-Host "  .\ralph.ps1 config commit on     Enable auto-commit (default)"
                    Write-Host "  .\ralph.ps1 config commit off    Disable auto-commit"
                    Write-Host ""
                    Write-Host "Plan file override:" -ForegroundColor Yellow
                    Write-Host "  Add DO_NOT_COMMIT on its own line to disable commits for that plan"
                }
                default {
                    Write-Host "Unknown option: $MaxIterations" -ForegroundColor Red
                    Write-Host "Usage: .\ralph.ps1 config commit <on|off|status>"
                    exit 1
                }
            }
            exit 0
        }
        "" {
            Write-Host "Usage: .\ralph.ps1 config <setting>" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Settings:" -ForegroundColor Yellow
            Write-Host "  commit <on|off|status>    Configure auto-commit behavior"
            exit 1
        }
        default {
            Write-Host "Unknown config setting: $Mode" -ForegroundColor Red
            Write-Host "Run '.\ralph.ps1 config' for available settings."
            exit 1
        }
    }
}

# Validate arguments
if (-not $PlanFile) {
    Show-Usage
}

# Validate plan file path (security check)
if (Get-Command Test-FilePath -ErrorAction SilentlyContinue) {
    if (-not (Test-FilePath -Path $PlanFile -Name "Plan file")) {
        exit 1
    }
}

# Validate plan file exists
if (-not (Test-Path $PlanFile)) {
    Write-RalphError "Plan file not found: $PlanFile"
    exit 1
}

# Validate mode
if ($Mode -ne "plan" -and $Mode -ne "build") {
    Write-RalphError "Mode must be 'plan' or 'build', got: $Mode"
    Show-Usage
}

# Validate max iterations
if ($MaxIterations -ne 0) {
    if (Get-Command Test-NumericValue -ErrorAction SilentlyContinue) {
        if (-not (Test-NumericValue -Value $MaxIterations.ToString() -Name "Max iterations" -Min 1 -Max 10000)) {
            exit 1
        }
    } elseif ($MaxIterations -lt 1 -or $MaxIterations -gt 10000) {
        Write-RalphError "Max iterations must be between 1 and 10000: $MaxIterations"
        exit 1
    }
}

# Derive progress file name from plan file
$PLAN_BASENAME = [System.IO.Path]::GetFileNameWithoutExtension($PlanFile)
$PROGRESS_FILE = "${PLAN_BASENAME}_PROGRESS.md"
$PLAN_FILE_ABS = (Resolve-Path $PlanFile).Path

# Select prompt template
if ($Mode -eq "plan") {
    $PROMPT_TEMPLATE = Join-Path $RALPH_DIR "PROMPT_plan.md"
} else {
    $PROMPT_TEMPLATE = Join-Path $RALPH_DIR "PROMPT_build.md"
}

# Verify prompt template exists
if (-not (Test-Path $PROMPT_TEMPLATE)) {
    Write-Host "Error: Prompt template not found: $PROMPT_TEMPLATE" -ForegroundColor Red
    Write-Host "Run the setup script or create the template manually."
    exit 1
}

# Compute commit setting
$SHOULD_COMMIT = $true
$COMMIT_DISABLED_REASON = ""
if ($env:RALPH_AUTO_COMMIT -ne "true") {
    $SHOULD_COMMIT = $false
    $COMMIT_DISABLED_REASON = "(disabled via config)"
} elseif (Should-SkipCommitFromPlan $PlanFile) {
    $SHOULD_COMMIT = $false
    $COMMIT_DISABLED_REASON = "(DO_NOT_COMMIT in plan)"
}

# Print banner
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "  RALPH - Autonomous AI Development Loop" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host "  Plan:      " -NoNewline
Write-Host $PlanFile -ForegroundColor Yellow
Write-Host "  Mode:      " -NoNewline
Write-Host $Mode -ForegroundColor Yellow
Write-Host "  Progress:  " -NoNewline
Write-Host $PROGRESS_FILE -ForegroundColor Yellow
if ($MaxIterations -gt 0) {
    Write-Host "  Max Iter:  " -NoNewline
    Write-Host $MaxIterations -ForegroundColor Yellow
}
if ($SHOULD_COMMIT) {
    Write-Host "  Commit:    " -NoNewline
    Write-Host "enabled" -ForegroundColor Green
} else {
    Write-Host "  Commit:    " -NoNewline
    Write-Host "disabled $COMMIT_DISABLED_REASON" -ForegroundColor Yellow
}

if (Test-NotificationsEnabled) {
    $platforms = @()
    if ($env:RALPH_SLACK_WEBHOOK_URL) { $platforms += "Slack" }
    if ($env:RALPH_DISCORD_WEBHOOK_URL) { $platforms += "Discord" }
    if ($env:RALPH_TELEGRAM_BOT_TOKEN -and $env:RALPH_TELEGRAM_CHAT_ID) { $platforms += "Telegram" }
    if ($env:RALPH_CUSTOM_NOTIFY_SCRIPT) { $platforms += "Custom" }
    if ($env:RALPH_EMAIL_TO -and $env:RALPH_EMAIL_FROM) { $platforms += "Email" }
    Write-Host "  Notify:    " -NoNewline
    Write-Host ($platforms -join " ") -ForegroundColor Green
} else {
    Write-Host "  Notify:    " -NoNewline
    Write-Host "disabled (run '.\ralph.ps1 notify setup')" -ForegroundColor Yellow
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
Write-Host ""
Write-Host "Exit conditions:" -ForegroundColor Yellow
if ($Mode -eq "plan") {
    Write-Host "  - Planning completes when task list is created (Status: IN_PROGRESS)"
    Write-Host "  - Plan mode runs once then exits automatically"
} else {
    Write-Host "  - RALPH_DONE in $PROGRESS_FILE signals all tasks complete (set by AI)"
}
Write-Host "  - Press Ctrl+C to stop manually"
Write-Host ""

# Send start notification
$REPO_NAME = Split-Path -Leaf (Get-Location)
Send-Notification ":rocket: *Ralph Started*\n\`\`\`Plan: $PLAN_BASENAME\nMode: $Mode\nRepo: $REPO_NAME\`\`\`"

# Initialize progress file if it doesn't exist
if (-not (Test-Path $PROGRESS_FILE)) {
    $progressContent = @"
# Progress: $PLAN_BASENAME

Started: $(Get-Date)

## Status

IN_PROGRESS

## Tasks Completed

"@
    Set-Content -Path $PROGRESS_FILE -Value $progressContent
}

$ITERATION = 0

# Check for completion
function Test-Done {
    if (Test-Path $PROGRESS_FILE) {
        $content = Get-Content $PROGRESS_FILE
        foreach ($line in $content) {
            if ($line -eq "RALPH_DONE") {
                return $true
            }
        }
    }
    return $false
}

# Main loop
while ($true) {
    # Check exit conditions
    if (Test-Done) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host "  RALPH_DONE - Work complete!" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Send-Notification ":white_check_mark: *Ralph Complete!*\n\`\`\`Plan: $PLAN_BASENAME\nIterations: $ITERATION\nRepo: $REPO_NAME\`\`\`"
        break
    }

    if ($MaxIterations -gt 0 -and $ITERATION -ge $MaxIterations) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
        Write-Host "  Max iterations reached: $MaxIterations" -ForegroundColor Yellow
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
        Send-Notification ":warning: *Ralph Stopped*\n\`\`\`Plan: $PLAN_BASENAME\nReason: Max iterations reached ($MaxIterations)\nRepo: $REPO_NAME\`\`\`"
        break
    }

    $ITERATION++
    Write-Host ""
    Write-Host "══════════════════ ITERATION $ITERATION ══════════════════" -ForegroundColor Blue
    Write-Host ""

    # Build the prompt with substitutions
    $promptContent = Get-Content $PROMPT_TEMPLATE -Raw
    $promptContent = $promptContent -replace '\$\{PLAN_FILE\}', $PLAN_FILE_ABS
    $promptContent = $promptContent -replace '\$\{PROGRESS_FILE\}', $PROGRESS_FILE
    $promptContent = $promptContent -replace '\$\{PLAN_NAME\}', $PLAN_BASENAME
    $promptContent = $promptContent -replace '\$\{AUTO_COMMIT\}', $SHOULD_COMMIT

    # Run Claude
    try {
        $promptContent | claude -p --dangerously-skip-permissions --model sonnet --verbose
    } catch {
        Write-Host "Claude exited with error, continuing..." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Iteration $ITERATION complete" -ForegroundColor Green

    # Plan mode: exit after one iteration
    if ($Mode -eq "plan") {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host "  Planning complete! Task list created in $PROGRESS_FILE" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next step: Run " -NoNewline
        Write-Host ".\ralph.ps1 $PlanFile build" -ForegroundColor Yellow -NoNewline
        Write-Host " to implement tasks"
        Send-Notification ":clipboard: *Ralph Planning Complete!*\n\`\`\`Plan: $PLAN_BASENAME\nTask list created in: $PROGRESS_FILE\nRepo: $REPO_NAME\`\`\`"
        break
    }

    # Send iteration notification (configurable frequency)
    $NOTIFY_FREQ = if ($env:RALPH_NOTIFY_FREQUENCY) { [int]$env:RALPH_NOTIFY_FREQUENCY } else { 5 }
    if ($ITERATION -eq 1 -or ($ITERATION % $NOTIFY_FREQ) -eq 0) {
        Send-Notification ":gear: *Ralph Progress*: Iteration $ITERATION completed\n\`Plan: $PLAN_BASENAME\`"
    }

    # Small delay between iterations
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Total iterations: $ITERATION"
Write-Host "Progress file: $PROGRESS_FILE"

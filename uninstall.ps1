# PortableRalph Uninstaller
# PowerShell version for Windows support
# https://github.com/aaron777collins/portableralph
#
# Usage:
#   .\uninstall.ps1 [-Force] [-KeepConfig]
#
# Options:
#   -Force         Skip confirmation prompts
#   -KeepConfig    Keep ~/.ralph.env configuration file
#   -InstallDir    Custom install directory (default: ~\ralph)
#   -Help          Show this help

param(
    [switch]$Force,
    [switch]$KeepConfig,
    [string]$InstallDir,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ============================================
# CONFIGURATION
# ============================================

$VERSION = "1.6.0"
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
        [string]$Default = "n"
    )

    if ($Force) {
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
# HELP
# ============================================

function Show-Help {
    Write-Host @"
PortableRalph Uninstaller

Usage:
  .\uninstall.ps1 [options]

Options:
  -Force           Skip confirmation prompts
  -KeepConfig      Keep ~/.ralph.env configuration file
  -InstallDir      Custom install directory (default: ~\ralph)
  -Help            Show this help

Examples:
  # Interactive uninstall with confirmation
  .\uninstall.ps1

  # Force uninstall without prompts
  .\uninstall.ps1 -Force

  # Uninstall but keep configuration
  .\uninstall.ps1 -KeepConfig
"@
    exit 0
}

# ============================================
# UNINSTALLATION
# ============================================

function Show-Banner {
    Write-Host ""
    Write-Host @"
    ____             __        __    __     ____        __      __
   / __ \____  _____/ /_____ _/ /_  / /__  / __ \____ _/ /___  / /_
  / /_/ / __ \/ ___/ __/ __ `/ __ \/ / _ \/ /_/ / __ `/ / __ \/ __ \
 / ____/ /_/ / /  / /_/ /_/ / /_/ / /  __/ _, _/ /_/ / / /_/ / / / /
/_/    \____/_/   \__/\__,_/_.___/_/\___/_/ |_|\__,_/_/ .___/_/ /_/
                                                      /_/
                        UNINSTALLER
"@ -ForegroundColor Red
    Write-Host "  Version $VERSION"
    Write-Host ""
}

function Confirm-Uninstall {
    if ($Force) {
        return
    }

    Write-Warning2 "This will remove PortableRalph from your system."
    Write-Host ""
    Write-Host "The following will be removed:"
    Write-Host "  - Installation directory: $InstallDir"
    if (-not $KeepConfig) {
        Write-Host "  - Configuration file: $env:USERPROFILE\.ralph.env"
    }
    Write-Host "  - PowerShell profile configuration (aliases)"
    Write-Host "  - Running monitor processes"
    Write-Host ""

    if (-not (Read-PromptYN "Are you sure you want to uninstall PortableRalph?")) {
        Write-Error2 "Uninstallation cancelled."
        exit 0
    }
}

function Stop-RunningProcesses {
    Write-Log "Stopping running Ralph monitor processes..."

    $processes = Get-Process | Where-Object {
        $_.ProcessName -match "pwsh|powershell" -and
        $_.CommandLine -match "ralph.*monitor"
    }

    if ($processes) {
        Write-Info "Found running monitor processes: $($processes.Id -join ', ')"
        foreach ($proc in $processes) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                Write-Success "Stopped process $($proc.Id)"
            } catch {
                Write-Warning2 "Could not stop process $($proc.Id): $_"
            }
        }
    } else {
        Write-Info "No running monitor processes found"
    }

    # Also check for background jobs
    $jobs = Get-Job | Where-Object { $_.Command -match "ralph" }
    if ($jobs) {
        Write-Info "Stopping background jobs..."
        $jobs | Stop-Job
        $jobs | Remove-Job
    }
}

function Remove-ShellConfig {
    Write-Log "Removing PowerShell profile configuration..."

    $profiles = @(
        $PROFILE.CurrentUserAllHosts,
        $PROFILE.CurrentUserCurrentHost,
        $PROFILE.AllUsersAllHosts,
        $PROFILE.AllUsersCurrentHost
    )

    $modified = $false

    foreach ($profilePath in $profiles) {
        if (Test-Path $profilePath) {
            $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

            if ($content -match "PortableRalph|ralph\.env|function ralph") {
                # Create backup
                $backupPath = "$profilePath.ralph-backup"
                Copy-Item $profilePath $backupPath -Force
                Write-Info "Created backup: $backupPath"

                # Remove PortableRalph configuration
                $lines = Get-Content $profilePath
                $newLines = @()
                $skipNext = $false
                $inRalphBlock = $false

                for ($i = 0; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]

                    # Detect start of Ralph block
                    if ($line -match "# PortableRalph") {
                        $inRalphBlock = $true
                        continue
                    }

                    # Detect end of Ralph block
                    if ($inRalphBlock -and ($line -match "^function ralph" -or $line -match "^Set-Alias ralph")) {
                        $inRalphBlock = $false
                        continue
                    }

                    # Skip lines in Ralph block
                    if ($inRalphBlock) {
                        continue
                    }

                    $newLines += $line
                }

                $newLines | Set-Content $profilePath -Encoding UTF8
                Write-Success "Removed configuration from $profilePath"
                $modified = $true
            }
        }
    }

    if (-not $modified) {
        Write-Info "No PowerShell profile configuration found"
    }
}

function Remove-ConfigFile {
    if ($KeepConfig) {
        Write-Info "Keeping configuration file: $env:USERPROFILE\.ralph.env"
        return
    }

    $configFile = Join-Path $env:USERPROFILE ".ralph.env"

    if (Test-Path $configFile) {
        Write-Log "Removing configuration file..."
        try {
            Remove-Item $configFile -Force
            Write-Success "Removed $configFile"
        } catch {
            Write-Warning2 "Could not remove $configFile : $_"
        }
    } else {
        Write-Info "No configuration file found"
    }
}

function Remove-InstallationDir {
    if (-not (Test-Path $InstallDir)) {
        Write-Info "Installation directory not found: $InstallDir"
        return
    }

    Write-Log "Removing installation directory: $InstallDir"

    try {
        Remove-Item $InstallDir -Recurse -Force
        Write-Success "Removed $InstallDir"
    } catch {
        Write-Error2 "Could not remove $InstallDir : $_"
        Write-Error2 "You may need to close any open files or run as Administrator"
        exit 1
    }
}

function Remove-PortableRalphDir {
    $prDir = Join-Path $env:USERPROFILE ".portableralph"

    if (Test-Path $prDir) {
        Write-Log "Removing PortableRalph data directory..."

        if ($Force -or (Read-PromptYN "Remove $prDir (contains logs and state)?" "y")) {
            try {
                Remove-Item $prDir -Recurse -Force
                Write-Success "Removed $prDir"
            } catch {
                Write-Warning2 "Could not remove $prDir : $_"
            }
        } else {
            Write-Info "Keeping $prDir"
        }
    } else {
        Write-Info "No data directory found"
    }
}

function Show-CompletionMessage {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  PortableRalph has been uninstalled" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""

    if ($KeepConfig) {
        Write-Info "Your configuration was preserved at: $env:USERPROFILE\.ralph.env"
    }

    Write-Host "  Next steps:"
    Write-Host ""
    Write-Host "    # Reload your PowerShell profile to remove ralph alias" -ForegroundColor Cyan
    Write-Host "    . `$PROFILE"
    Write-Host ""

    $backupProfiles = Get-ChildItem "$env:USERPROFILE\Documents\PowerShell\*ralph-backup*" -ErrorAction SilentlyContinue
    $backupProfiles += Get-ChildItem "$env:USERPROFILE\Documents\WindowsPowerShell\*ralph-backup*" -ErrorAction SilentlyContinue

    if ($backupProfiles) {
        Write-Info "PowerShell profile backups created:"
        foreach ($backup in $backupProfiles) {
            Write-Host "  - $($backup.FullName)"
        }
        Write-Host ""
    }

    Write-Host "  To reinstall PortableRalph:"
    Write-Host "    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.ps1' | Invoke-Expression" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Thanks for using PortableRalph!"
    Write-Host ""
}

# ============================================
# MAIN
# ============================================

function Main {
    if ($Help) {
        Show-Help
    }

    Show-Banner
    Confirm-Uninstall

    Write-Host ""
    Stop-RunningProcesses
    Remove-ShellConfig
    Remove-ConfigFile
    Remove-InstallationDir
    Remove-PortableRalphDir

    Show-CompletionMessage
}

Main

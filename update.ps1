# PortableRalph Update Script
# PowerShell version for Windows support
# Handles self-updating, version management, and rollback
#
# Usage:
#   .\update.ps1              Update to latest version
#   .\update.ps1 --check      Check for updates without installing
#   .\update.ps1 --list       List all available versions
#   .\update.ps1 <version>    Install specific version
#   .\update.ps1 --rollback   Rollback to previous version

param(
    [Parameter(Position=0)]
    [string]$Action,

    [switch]$Check,
    [switch]$List,
    [switch]$Rollback,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load validation library
$ValidationLib = Join-Path $SCRIPT_DIR "lib\validation.ps1"
if (Test-Path $ValidationLib) {
    . $ValidationLib
}

$GITHUB_REPO = "aaron777collins/portableralph"
$API_URL = "https://api.github.com/repos/$GITHUB_REPO"
$VERSION_HISTORY = Join-Path $env:USERPROFILE ".ralph_version_history"
$BACKUP_DIR = Join-Path $env:USERPROFILE ".ralph_backup"

# Get current version from ralph.sh or ralph.ps1
function Get-CurrentVersion {
    $ralphScript = Join-Path $SCRIPT_DIR "ralph.sh"
    if (Test-Path $ralphScript) {
        $content = Get-Content $ralphScript
        foreach ($line in $content) {
            if ($line -match '^VERSION="([^"]+)"') {
                return $matches[1]
            }
        }
    }

    $ralphPS = Join-Path $SCRIPT_DIR "ralph.ps1"
    if (Test-Path $ralphPS) {
        $content = Get-Content $ralphPS
        foreach ($line in $content) {
            if ($line -match '^\$VERSION\s*=\s*"([^"]+)"') {
                return $matches[1]
            }
        }
    }

    return "unknown"
}

$CURRENT_VERSION = Get-CurrentVersion

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

function Write-Warning {
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

# ============================================
# API FUNCTIONS
# ============================================

function Get-LatestVersion {
    try {
        $releases = Invoke-RestMethod -Uri "$API_URL/releases" -TimeoutSec 10
        if ($releases -and $releases.Count -gt 0) {
            $version = $releases[0].tag_name -replace '^v', ''
            return $version
        }

        # Fallback to tags
        $tags = Invoke-RestMethod -Uri "$API_URL/tags" -TimeoutSec 10
        if ($tags -and $tags.Count -gt 0) {
            $version = $tags[0].name -replace '^v', ''
            return $version
        }

        throw "No versions found"
    } catch {
        Write-Error2 "Failed to connect to GitHub: $_"
        exit 1
    }
}

function Get-AllVersions {
    try {
        $releases = Invoke-RestMethod -Uri "$API_URL/releases" -TimeoutSec 10
        $versions = @()

        if ($releases -and $releases.Count -gt 0) {
            $versions = $releases | ForEach-Object { $_.tag_name -replace '^v', '' }
        } else {
            # Fallback to tags
            $tags = Invoke-RestMethod -Uri "$API_URL/tags" -TimeoutSec 10
            $versions = $tags | ForEach-Object { $_.name -replace '^v', '' }
        }

        return $versions
    } catch {
        Write-Error2 "Failed to fetch versions from GitHub: $_"
        exit 1
    }
}

function Compare-Versions {
    param(
        [string]$Version1,
        [string]$Version2
    )

    $v1 = $Version1 -replace '^v', ''
    $v2 = $Version2 -replace '^v', ''

    if ($v1 -eq $v2) {
        return 0
    }

    $v1Parts = $v1 -split '\.'
    $v2Parts = $v2 -split '\.'

    for ($i = 0; $i -lt [Math]::Max($v1Parts.Length, $v2Parts.Length); $i++) {
        $part1 = if ($i -lt $v1Parts.Length) { [int]$v1Parts[$i] } else { 0 }
        $part2 = if ($i -lt $v2Parts.Length) { [int]$v2Parts[$i] } else { 0 }

        if ($part1 -lt $part2) {
            return -1
        } elseif ($part1 -gt $part2) {
            return 1
        }
    }

    return 0
}

# ============================================
# VERSION HISTORY
# ============================================

function Save-VersionHistory {
    param(
        [string]$NewVersion,
        [string]$OldVersion
    )

    $timestamp = Get-Date -Format "o"

    if (-not (Test-Path $VERSION_HISTORY)) {
        $header = @"
# Ralph Version History
# Format: VERSION|DATE|PREVIOUS_VERSION
"@
        Set-Content -Path $VERSION_HISTORY -Value $header -Encoding UTF8
    }

    Add-Content -Path $VERSION_HISTORY -Value "$NewVersion|$timestamp|$OldVersion" -Encoding UTF8
}

function Get-PreviousVersion {
    if (Test-Path $VERSION_HISTORY) {
        $lines = Get-Content $VERSION_HISTORY | Where-Object { $_ -notmatch '^#' }
        if ($lines.Count -ge 2) {
            $secondLast = $lines[-2]
            $parts = $secondLast -split '\|'
            return $parts[0]
        }
    }

    if (Test-Path (Join-Path $BACKUP_DIR ".version")) {
        return Get-Content (Join-Path $BACKUP_DIR ".version")
    }

    return ""
}

# ============================================
# BACKUP AND RESTORE
# ============================================

function Backup-Current {
    Write-Log "Backing up current installation..."

    # Remove old backup
    if (Test-Path $BACKUP_DIR) {
        Remove-Item -Path $BACKUP_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null

    # Copy essential files
    $filesToBackup = @(
        "ralph.sh",
        "ralph.ps1",
        "install.sh",
        "install.ps1",
        "notify.sh",
        "notify.ps1",
        "setup-notifications.sh",
        "setup-notifications.ps1",
        "update.sh",
        "update.ps1",
        "monitor-progress.sh",
        "monitor-progress.ps1",
        "start-monitor.sh",
        "start-monitor.ps1",
        "PROMPT_plan.md",
        "PROMPT_build.md"
    )

    foreach ($file in $filesToBackup) {
        $sourcePath = Join-Path $SCRIPT_DIR $file
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $BACKUP_DIR
        }
    }

    # Record backup version
    Set-Content -Path (Join-Path $BACKUP_DIR ".version") -Value $CURRENT_VERSION -Encoding UTF8

    Write-Success "Backup complete"
}

function Restore-Backup {
    if (-not (Test-Path $BACKUP_DIR) -or -not (Test-Path (Join-Path $BACKUP_DIR ".version"))) {
        Write-Error2 "No backup found. Cannot rollback."
        Write-Host ""
        Write-Host "Rollback is only available after an update."
        exit 1
    }

    $backupVersion = Get-Content (Join-Path $BACKUP_DIR ".version")

    Write-Log "Restoring backup (v$backupVersion)..."

    # Restore files
    Get-ChildItem -Path $BACKUP_DIR -Filter "*.sh" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $SCRIPT_DIR -Force
    }
    Get-ChildItem -Path $BACKUP_DIR -Filter "*.ps1" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $SCRIPT_DIR -Force
    }
    Get-ChildItem -Path $BACKUP_DIR -Filter "*.md" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $SCRIPT_DIR -Force
    }

    Write-Success "Restored v$backupVersion"

    return $backupVersion
}

# ============================================
# UPDATE FUNCTIONS
# ============================================

function Test-ForUpdates {
    Write-Host "PortableRalph" -ForegroundColor White -NoNewline
    Write-Host " v$CURRENT_VERSION"
    Write-Host ""
    Write-Log "Checking for updates..."

    $latest = Get-LatestVersion

    Write-Host "  Current version: " -NoNewline
    Write-Host $CURRENT_VERSION -ForegroundColor Yellow
    Write-Host "  Latest version:  " -NoNewline
    Write-Host $latest -ForegroundColor Green
    Write-Host ""

    $cmp = Compare-Versions $CURRENT_VERSION $latest

    if ($cmp -eq 0) {
        Write-Success "You're on the latest version!"
    } elseif ($cmp -lt 0) {
        Write-Host "A new version is available!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Run " -NoNewline
        Write-Host ".\update.ps1" -ForegroundColor Cyan -NoNewline
        Write-Host " to upgrade."
    } else {
        Write-Info "You're ahead of the latest release (development version?)"
    }
}

function Show-Versions {
    Write-Host "Available PortableRalph versions:" -ForegroundColor White
    Write-Host ""

    $versions = Get-AllVersions
    $latest = $versions[0]

    foreach ($ver in $versions) {
        $prefix = "   "
        $suffix = ""

        if ($ver -eq $latest) {
            $suffix = " (latest)"
            Write-Host "$prefix" -NoNewline
            Write-Host "v$ver" -NoNewline
            Write-Host $suffix -ForegroundColor Green
        } elseif ($ver -eq $CURRENT_VERSION) {
            $prefix = " * "
            $suffix = " (installed)"
            Write-Host $prefix -ForegroundColor Green -NoNewline
            Write-Host "v$ver" -NoNewline
            Write-Host $suffix -ForegroundColor Blue
        } else {
            Write-Host "${prefix}v$ver"
        }
    }

    Write-Host ""
    Write-Host "Use " -NoNewline
    Write-Host ".\update.ps1 <version>" -ForegroundColor Cyan -NoNewline
    Write-Host " to install a specific version."
}

function Install-Version {
    param([string]$TargetVersion)

    $TargetVersion = $TargetVersion -replace '^v', ''
    $tag = "v$TargetVersion"

    # Verify version exists
    $versions = Get-AllVersions
    if ($TargetVersion -notin $versions) {
        Write-Error2 "Version '$TargetVersion' not found"
        Write-Host ""
        Write-Host "Available versions:"
        Show-Versions
        exit 1
    }

    # Check if already on this version
    if ($TargetVersion -eq $CURRENT_VERSION) {
        Write-Info "Already on version $TargetVersion"
        exit 0
    }

    Write-Log "Installing version $tag..."

    # Backup current version
    Backup-Current

    # Check if we have git
    $hasGit = Get-Command git -ErrorAction SilentlyContinue

    if ($hasGit -and (Test-Path (Join-Path $SCRIPT_DIR ".git"))) {
        # Git method (preferred)
        Write-Log "Fetching version $tag..."
        try {
            Push-Location $SCRIPT_DIR
            git fetch --tags --quiet 2>$null
            git checkout $tag --quiet 2>$null
            Pop-Location
        } catch {
            Write-Error2 "Failed to checkout version $tag"
            Write-Warning "Restoring backup..."
            Restore-Backup | Out-Null
            Pop-Location
            exit 1
        }
    } else {
        # Tarball method (fallback)
        Write-Log "Downloading version $tag..."
        $tarballUrl = "https://github.com/$GITHUB_REPO/archive/refs/tags/${tag}.tar.gz"
        $tempFile = Join-Path $env:TEMP "ralph-${tag}.tar.gz"
        $tempDir = Join-Path $env:TEMP "ralph-extract"

        try {
            # Download
            Invoke-WebRequest -Uri $tarballUrl -OutFile $tempFile -TimeoutSec 60

            # Extract (requires tar on Windows 10+)
            if (Test-Path $tempDir) {
                Remove-Item -Path $tempDir -Recurse -Force
            }
            New-Item -ItemType Directory -Path $tempDir | Out-Null

            # Use tar if available (Windows 10+), otherwise use Expand-Archive for zip
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                tar -xzf $tempFile -C $tempDir
            } else {
                Write-Warning "tar command not found. Trying alternative download method..."
                $zipUrl = "https://github.com/$GITHUB_REPO/archive/refs/tags/${tag}.zip"
                $zipFile = Join-Path $env:TEMP "ralph-${tag}.zip"
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -TimeoutSec 60
                Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
                Remove-Item $zipFile
            }

            # Copy files
            $extractedDir = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
            Copy-Item -Path "$($extractedDir.FullName)\*" -Destination $SCRIPT_DIR -Recurse -Force

            # Cleanup
            Remove-Item $tempFile -Force
            Remove-Item $tempDir -Recurse -Force
        } catch {
            Write-Error2 "Failed to download version $tag"
            Write-Warning "Restoring backup..."
            Restore-Backup | Out-Null
            exit 1
        }
    }

    # Record in history
    Save-VersionHistory $TargetVersion $CURRENT_VERSION

    Write-Success "Successfully installed v$TargetVersion"
    Write-Host ""
    Write-Host "Run " -NoNewline
    Write-Host ".\update.ps1 --rollback" -ForegroundColor Cyan -NoNewline
    Write-Host " to revert to v$CURRENT_VERSION"
}

function Update-ToLatest {
    Write-Host "PortableRalph" -ForegroundColor White -NoNewline
    Write-Host " v$CURRENT_VERSION"
    Write-Host ""

    Write-Log "Checking for updates..."

    $latest = Get-LatestVersion
    $cmp = Compare-Versions $CURRENT_VERSION $latest

    if ($cmp -eq 0) {
        Write-Success "You're already on the latest version (v$CURRENT_VERSION)"
        exit 0
    } elseif ($cmp -gt 0) {
        Write-Info "You're ahead of the latest release (v$CURRENT_VERSION > v$latest)"
        Write-Host ""
        Write-Host "Use '.\update.ps1 $latest' to downgrade to the latest release."
        exit 0
    }

    Write-Host "  Updating: " -NoNewline
    Write-Host "v$CURRENT_VERSION" -ForegroundColor Yellow -NoNewline
    Write-Host " → " -NoNewline
    Write-Host "v$latest" -ForegroundColor Green
    Write-Host ""

    Install-Version $latest
}

function Invoke-Rollback {
    Write-Host "PortableRalph" -ForegroundColor White -NoNewline
    Write-Host " Rollback"
    Write-Host ""

    $backupVersion = Restore-Backup

    if ($backupVersion) {
        # Record in history
        Save-VersionHistory $backupVersion $CURRENT_VERSION

        Write-Host ""
        Write-Success "Successfully rolled back to v$backupVersion"
    }
}

# ============================================
# USAGE
# ============================================

function Show-Help {
    Write-Host "PortableRalph Update" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\update.ps1              Update to latest version"
    Write-Host "  .\update.ps1 --check      Check for updates without installing"
    Write-Host "  .\update.ps1 --list       List all available versions"
    Write-Host "  .\update.ps1 <version>    Install specific version (e.g., 1.4.0)"
    Write-Host "  .\update.ps1 --rollback   Rollback to previous version"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\update.ps1              # Update to latest"
    Write-Host "  .\update.ps1 --check      # Check if updates available"
    Write-Host "  .\update.ps1 1.4.0        # Install version 1.4.0"
    Write-Host "  .\update.ps1 v1.4.0       # Also works with 'v' prefix"
    Write-Host "  .\update.ps1 --rollback   # Revert to previous version"
}

# ============================================
# MAIN
# ============================================

if ($Help) {
    Show-Help
    exit 0
}

if ($Check) {
    Test-ForUpdates
    exit 0
}

if ($List) {
    Show-Versions
    exit 0
}

if ($Rollback) {
    Invoke-Rollback
    exit 0
}

if ($Action) {
    # Assume it's a version number
    Install-Version $Action
} else {
    # No arguments, update to latest
    Update-ToLatest
}

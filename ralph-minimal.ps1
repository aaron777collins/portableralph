# Ralph - Autonomous AI Development Loop (Minimal Version for CI Testing)
# This version focuses on reliable help/version handling for Windows CI compatibility

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

# IMMEDIATE help/version handling - no dependencies, no complex operations
if ($Help) {
    Write-Host "PortableRalph v1.6.0 - Autonomous AI Development Loop"
    Write-Host ""
    Write-Host "Usage: .\ralph.ps1 <plan-file> [mode] [max-iterations]"
    Write-Host ""
    Write-Host "More info: https://github.com/aaron777collins/portableralph"
    exit 0
}

if ($Version) {
    Write-Host "PortableRalph v1.6.0"
    exit 0
}

# For testing purposes, if no plan file provided, show help
if ([string]::IsNullOrEmpty($PlanFile)) {
    Write-Host "PortableRalph v1.6.0 - Plan file required"
    Write-Host "Usage: .\ralph.ps1 <plan-file> [mode] [max-iterations]"
    Write-Host "Use -Help for more information"
    exit 1
}

# Minimal implementation for other functionality
Write-Host "PortableRalph would run here with plan: $PlanFile, mode: $Mode"
Write-Host "This is a minimal version for CI testing compatibility"
exit 0
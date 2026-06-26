# Start the progress monitor in the background
# PowerShell version for Windows support
# Usage: .\start-monitor.ps1 [interval_seconds]

param(
    [int]$Interval = 300  # Default: 5 minutes
)

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$monitorScript = Join-Path $SCRIPT_DIR "monitor-progress.ps1"

Write-Host "Starting Ralph Progress Monitor..."
Write-Host "Interval: ${Interval}s"
Write-Host ""

# Start the monitor script in a new PowerShell window (background)
# On Windows, we use Start-Process with -WindowStyle Hidden for true background execution
$logFile = Join-Path $SCRIPT_DIR "monitor.log"

# Start in background with output redirected to log file
$process = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$monitorScript`"", $Interval `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $logFile `
    -PassThru

$PID_VALUE = $process.Id

Write-Host "✅ Monitor started with PID: $PID_VALUE" -ForegroundColor Green
Write-Host "Log file: $logFile"
Write-Host ""
Write-Host "To view logs: Get-Content $logFile -Wait"
Write-Host "To stop: Stop-Process -Id $PID_VALUE"
Write-Host ""

# Save PID to file
$pidFile = Join-Path $SCRIPT_DIR "monitor.pid"
Set-Content -Path $pidFile -Value $PID_VALUE -Encoding UTF8
Write-Host "PID saved to: $pidFile"

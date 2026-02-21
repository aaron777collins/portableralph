@echo off
REM Minimal test version of launcher.bat to isolate syntax issues

setlocal enabledelayedexpansion

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Get command to run
set "COMMAND=%~1"

REM Handle test mode
if "%COMMAND%"=="--test" goto :run_test
if "%COMMAND%"=="" goto :show_help

:show_help
echo Usage: test-launcher.bat --test
exit /b 0

:run_test
echo Running minimal system test...

REM Test PowerShell availability
echo Testing PowerShell availability...
where powershell.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] PowerShell is available
) else (
    echo [FAIL] PowerShell is not available
    set "TEST_FAILED=1"
)

REM Test ralph.ps1 exists
echo Testing ralph.ps1 file...
if exist "%SCRIPT_DIR%\ralph.ps1" (
    echo [OK] ralph.ps1 found
) else (
    echo [FAIL] ralph.ps1 not found
    set "TEST_FAILED=1"
)

echo.
if defined TEST_FAILED (
    echo [FAIL] MINIMAL TEST FAILED
    exit /b 1
) else (
    echo [PASS] MINIMAL TEST PASSED
    exit /b 0
)
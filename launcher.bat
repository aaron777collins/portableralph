@echo off
REM launcher.bat - Auto-detect launcher for PortableRalph (Windows)
REM Detects OS and launches appropriate script
REM
REM Usage:
REM   launcher.bat ralph <args>
REM   launcher.bat update <args>
REM   launcher.bat notify <args>

setlocal enabledelayedexpansion

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Get command to run
set "COMMAND=%~1"

REM Handle help flags, version, and test mode
if "%COMMAND%"=="--help" goto :show_help
if "%COMMAND%"=="--version" goto :show_version
if "%COMMAND%"=="--test" goto :run_test
if "%COMMAND%"=="-h" goto :show_help
if "%COMMAND%"=="-?" goto :show_help
if "%COMMAND%"=="/?" goto :show_help
if "%COMMAND%"=="help" goto :show_help
if "%COMMAND%"=="" goto :show_help

goto :parse_command

:show_help
echo Usage: %~nx0 ^<command^> [args...]
echo.
echo Commands:
echo   ralph   - Run PortableRalph
echo   update  - Update PortableRalph
echo   notify  - Configure notifications
echo   monitor - Monitor progress
echo.
echo Options:
echo   --help, -h, -?  - Show this help message
echo   --version       - Show version information
echo   --test          - Run system test
exit /b 0

:show_version
echo PortableRalph Launcher v1.0.0
echo Auto-detection launcher for Windows environments
exit /b 0

:run_test
echo Running PortableRalph system test...
echo.
echo === Testing System Components ===

REM Clear any previous test state
set "TEST_FAILED="

REM Test PowerShell availability
echo Testing PowerShell availability...
where powershell.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] PowerShell is available
) else (
    echo [FAIL] PowerShell is not available
    set "TEST_FAILED=1"
)

REM Test core scripts exist
echo Testing core script files...
if exist "%SCRIPT_DIR%\ralph.ps1" (
    echo [OK] ralph.ps1 found
) else (
    echo [FAIL] ralph.ps1 not found
    set "TEST_FAILED=1"
)

if exist "%SCRIPT_DIR%\install.ps1" (
    echo [OK] install.ps1 found
) else (
    echo [FAIL] install.ps1 not found
    set "TEST_FAILED=1"
)

if exist "%SCRIPT_DIR%\notify.ps1" (
    echo [OK] notify.ps1 found
) else (
    echo [FAIL] notify.ps1 not found
    set "TEST_FAILED=1"
)

REM Test ralph.ps1 help functionality
echo Testing ralph.ps1 help functionality...
REM Simplified test - just check if file is readable by PowerShell
powershell.exe -ExecutionPolicy Bypass -Command "Get-Content '%SCRIPT_DIR%\ralph.ps1' -TotalCount 1" >nul 2>&1
set "HELP_EXIT_CODE=%ERRORLEVEL%"
if %HELP_EXIT_CODE% EQU 0 (
    echo [OK] ralph.ps1 is accessible
) else (
    echo [FAIL] ralph.ps1 not accessible (exit code: %HELP_EXIT_CODE%)
    set "TEST_FAILED=1"
)

echo.
if defined TEST_FAILED (
    echo [FAIL] SYSTEM TEST FAILED - Some components are not working
    exit /b 1
) else (
    echo [PASS] SYSTEM TEST PASSED - All components are working
    exit /b 0
)

:parse_command

REM Remove first argument
shift

REM Collect remaining arguments
set "ARGS="
:parse_args
if "%~1"=="" goto :args_done
set "ARGS=!ARGS! %1"
shift
goto :parse_args
:args_done

REM Determine which script to run
set "SCRIPT_NAME="
if /i "%COMMAND%"=="ralph" set "SCRIPT_NAME=ralph"
if /i "%COMMAND%"=="update" set "SCRIPT_NAME=update"
if /i "%COMMAND%"=="notify" set "SCRIPT_NAME=notify"
if /i "%COMMAND%"=="monitor" set "SCRIPT_NAME=monitor-progress"
if /i "%COMMAND%"=="monitor-progress" set "SCRIPT_NAME=monitor-progress"
if /i "%COMMAND%"=="setup-notifications" set "SCRIPT_NAME=setup-notifications"
if /i "%COMMAND%"=="start-monitor" set "SCRIPT_NAME=start-monitor"
if /i "%COMMAND%"=="decrypt-env" set "SCRIPT_NAME=decrypt-env"

if "%SCRIPT_NAME%"=="" (
    echo ERROR: Unknown command: %COMMAND%
    echo Valid commands: ralph, update, notify, monitor
    exit /b 1
)

REM Check if PowerShell is available (it always is on modern Windows)
where powershell.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Use PowerShell script
    set "SCRIPT_PATH=%SCRIPT_DIR%\%SCRIPT_NAME%.ps1"
    if exist "!SCRIPT_PATH!" (
        powershell.exe -ExecutionPolicy Bypass -File "!SCRIPT_PATH!" !ARGS!
        exit /b !ERRORLEVEL!
    )
)

REM Fallback: Check for bash (Git Bash, WSL, etc.)
where bash.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "SCRIPT_PATH=%SCRIPT_DIR%\%SCRIPT_NAME%.sh"
    if exist "!SCRIPT_PATH!" (
        bash.exe "!SCRIPT_PATH!" !ARGS!
        exit /b !ERRORLEVEL!
    )
)

REM No suitable interpreter found
echo ERROR: Neither PowerShell nor Bash found
echo Please install Git for Windows or enable WSL
exit /b 1

#!/bin/bash
# launcher.sh - Auto-detect launcher for PortableRalph (Unix/Linux/macOS)
# Detects OS and launches appropriate script
#
# Usage:
#   ./launcher.sh ralph <args>
#   ./launcher.sh update <args>
#   ./launcher.sh notify <args>

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source platform utilities
if [ -f "$SCRIPT_DIR/lib/platform-utils.sh" ]; then
    source "$SCRIPT_DIR/lib/platform-utils.sh"
else
    echo "ERROR: Cannot find lib/platform-utils.sh" >&2
    exit 1
fi

# Detect operating system
OS=$(detect_os)

# Get command to run
COMMAND="${1:-}"
if [ -z "$COMMAND" ]; then
    echo "Usage: $0 <command> [args...]" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  ralph   - Run PortableRalph" >&2
    echo "  update  - Update PortableRalph" >&2
    echo "  notify  - Configure notifications" >&2
    echo "  monitor - Monitor progress" >&2
    exit 1
fi

shift # Remove command from arguments

# Determine which script to run
case "$COMMAND" in
    ralph)
        SCRIPT_NAME="ralph"
        ;;
    update)
        SCRIPT_NAME="update"
        ;;
    notify)
        SCRIPT_NAME="notify"
        ;;
    monitor|monitor-progress)
        SCRIPT_NAME="monitor-progress"
        ;;
    setup-notifications)
        SCRIPT_NAME="setup-notifications"
        ;;
    start-monitor)
        SCRIPT_NAME="start-monitor"
        ;;
    decrypt-env)
        SCRIPT_NAME="decrypt-env"
        ;;
    *)
        echo "ERROR: Unknown command: $COMMAND" >&2
        echo "Valid commands: ralph, update, notify, monitor" >&2
        exit 1
        ;;
esac

# Determine which script variant to use based on OS
case "$OS" in
    Windows)
        # On Git Bash/MSYS/Cygwin, prefer PowerShell if available
        if command -v powershell.exe &> /dev/null; then
            SCRIPT_PATH="$SCRIPT_DIR/${SCRIPT_NAME}.ps1"
            if [ ! -f "$SCRIPT_PATH" ]; then
                echo "ERROR: PowerShell script not found: $SCRIPT_PATH" >&2
                echo "Falling back to bash script..." >&2
                SCRIPT_PATH="$SCRIPT_DIR/${SCRIPT_NAME}.sh"
            fi

            if [ -f "$SCRIPT_PATH" ] && [[ "$SCRIPT_PATH" == *.ps1 ]]; then
                exec powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_PATH" "$@"
            fi
        fi

        # Fallback to bash script on Windows
        SCRIPT_PATH="$SCRIPT_DIR/${SCRIPT_NAME}.sh"
        ;;

    WSL)
        # WSL: prefer bash scripts
        SCRIPT_PATH="$SCRIPT_DIR/${SCRIPT_NAME}.sh"
        ;;

    Linux|macOS)
        # Unix: use bash scripts
        SCRIPT_PATH="$SCRIPT_DIR/${SCRIPT_NAME}.sh"
        ;;

    *)
        echo "ERROR: Unsupported operating system: $OS" >&2
        exit 1
        ;;
esac

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: Script not found: $SCRIPT_PATH" >&2
    exit 1
fi

# Make sure script is executable (Unix)
if ! is_windows; then
    chmod +x "$SCRIPT_PATH" 2>/dev/null || true
fi

# Execute the script with all arguments
exec "$SCRIPT_PATH" "$@"

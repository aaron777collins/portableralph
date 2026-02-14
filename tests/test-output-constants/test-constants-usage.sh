#!/bin/bash
set -euo pipefail

# Load constants
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
source "$RALPH_DIR/lib/constants.sh"

# Use a constant
echo "HTTP_MAX_TIME=$HTTP_MAX_TIME"
echo "NOTIFY_MAX_RETRIES=$NOTIFY_MAX_RETRIES"
echo "CONFIG_FILE_MODE=$CONFIG_FILE_MODE"

exit 0

#!/bin/bash
# start-monitor.sh - Start the progress monitor in background
# Launches monitor-progress.sh as a daemon
#
# Usage: ./start-monitor.sh [interval] [repo_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor-progress.sh"

# Default interval: 5 minutes (300 seconds)
INTERVAL="${1:-300}"
REPO_DIR="${2:-$PWD}"

# Check if monitor script exists
if [ ! -f "$MONITOR_SCRIPT" ]; then
    echo "Error: monitor-progress.sh not found at $MONITOR_SCRIPT" >&2
    exit 1
fi

# Check if already running
PID_FILE="/tmp/ralph-monitor.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Monitor already running (PID: $OLD_PID)"
        echo "Stop with: kill $OLD_PID"
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

# Start monitor in background
echo "Starting Ralph Progress Monitor..."
echo "  Interval: ${INTERVAL}s"
echo "  Repo: $REPO_DIR"

nohup "$MONITOR_SCRIPT" "$INTERVAL" "$REPO_DIR" > /tmp/ralph-monitor.log 2>&1 &
echo $! > "$PID_FILE"

echo "Monitor started (PID: $(cat "$PID_FILE"))"
echo "Logs: /tmp/ralph-monitor.log"
echo "Stop with: kill $(cat "$PID_FILE")"

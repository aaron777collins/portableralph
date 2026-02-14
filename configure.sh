#!/bin/bash
# configure.sh - Wrapper for setup-notifications.sh
# Alias for consistency with naming convention
#
# Usage: ./configure.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/setup-notifications.sh" "$@"

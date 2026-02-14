#!/usr/bin/env bash
# validation.sh - Shared validation functions for Ralph
# This library provides common validation utilities used across Ralph scripts
# to reduce code duplication and ensure consistent validation logic.
#
# Functions:
#   - validate_numeric()      Validate numeric values with optional range checking
#   - validate_url()          Validate webhook URLs (basic format check)
#   - validate_email()        Validate email addresses
#   - validate_path()         Validate file paths
#   - json_escape()           Escape strings for JSON
#   - mask_token()            Mask sensitive tokens in output
#
# Usage:
#   source "$(dirname "$0")/lib/validation.sh"
#   or
#   source "${RALPH_DIR}/lib/validation.sh"

# Validate numeric value (positive integers)
# Args:
#   $1 - value to validate
#   $2 - optional: name of field (for error messages)
#   $3 - optional: minimum value (default: 0)
#   $4 - optional: maximum value (default: 999999)
# Returns:
#   0 if valid, 1 if invalid
validate_numeric() {
    local value="$1"
    local name="${2:-value}"
    local min="${3:-0}"
    local max="${4:-999999}"

    # Check if it's a number
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        # Only log error if a logging function exists (e.g., in ralph.sh)
        if type log_error &>/dev/null; then
            log_error "$name must be a positive integer: $value"
        fi
        return 1
    fi

    # Check range
    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        if type log_error &>/dev/null; then
            log_error "$name must be between $min and $max: $value"
        fi
        return 1
    fi

    return 0
}

# Validate URL format (http or https)
# Args:
#   $1 - URL to validate
#   $2 - optional: name of field (for error messages, default: "webhook")
# Returns:
#   0 if valid, 1 if invalid
validate_url() {
    local url="$1"
    local name="${2:-webhook}"

    # Check if empty
    if [ -z "$url" ]; then
        return 0  # Empty is okay, just not configured
    fi

    # Just check it looks like a URL (http or https)
    if [[ ! "$url" =~ ^https?:// ]]; then
        if type log_error &>/dev/null; then
            log_error "$name URL must use HTTP or HTTPS: $url"
        fi
        return 1
    fi

    return 0
}

# Validate email address (basic RFC 5322 compliance)
# Args:
#   $1 - email address to validate
#   $2 - optional: name of field (for error messages, default: "email")
# Returns:
#   0 if valid, 1 if invalid
validate_email() {
    local email="$1"
    local name="${2:-email}"

    if [ -z "$email" ]; then
        return 0  # Empty is okay
    fi

    # Basic email validation regex
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        if type log_error &>/dev/null; then
            log_error "$name address format invalid: $email"
        fi
        return 1
    fi

    return 0
}

# Validate file path
# Args:
#   $1 - path to validate
#   $2 - optional: name of field (for error messages, default: "path")
#   $3 - optional: require_exists (true/false, default: false)
# Returns:
#   0 if valid, 1 if invalid
validate_path() {
    local path="$1"
    local name="${2:-path}"
    local require_exists="${3:-false}"

    if [ -z "$path" ]; then
        return 0  # Empty is okay unless explicitly required
    fi

    # Reject URLs (user probably meant a file path)
    if [[ "$path" =~ ^https?:// ]]; then
        if type log_error &>/dev/null; then
            log_error "$name should be a file path, not a URL: $path"
        fi
        return 1
    fi

    # Check if file exists if required
    if [ "$require_exists" = "true" ] && [ ! -e "$path" ]; then
        if type log_error &>/dev/null; then
            log_error "$name does not exist: $path"
        fi
        return 1
    fi

    return 0
}

# Escape string for safe JSON usage
# Args:
#   $1 - string to escape
# Returns:
#   Escaped string suitable for JSON (via stdout)
json_escape() {
    local str="$1"
    # Escape backslashes first (order matters!)
    str="${str//\\/\\\\}"
    # Escape double quotes
    str="${str//\"/\\\"}"
    # Escape control characters
    str="${str//$'\t'/\\t}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    # Remove other control characters (0x00-0x1F except handled above)
    str="$(printf '%s' "$str" | tr -d '\000-\010\013\014\016-\037')"
    printf '%s' "$str"
}

# Mask sensitive tokens in output/logs
# Shows first 8 characters only, rest is redacted
# Args:
#   $1 - token to mask
# Returns:
#   Masked token (via stdout)
mask_token() {
    local token="$1"
    if [ -z "$token" ] || [ "${#token}" -lt 12 ]; then
        echo "[REDACTED]"
        return
    fi
    echo "${token:0:8}...[REDACTED]"
}

# Backwards compatibility aliases
# Some scripts may use validate_webhook_url instead of validate_url
validate_webhook_url() {
    validate_url "$@"
}

# Some scripts may use validate_file_path instead of validate_path
validate_file_path() {
    validate_path "$@"
}

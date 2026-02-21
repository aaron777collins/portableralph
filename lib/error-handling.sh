#!/bin/bash
# error-handling.sh - Enhanced error handling library for PortableRalph
# Provides standardized error handling, retry logic, and recovery mechanisms
#
# Functions:
#   - setup_error_handling()     Initialize error handling for script
#   - log_error()               Log error with timestamp and context
#   - log_warning()             Log warning message
#   - retry_command()           Retry command with exponential backoff
#   - validate_api_key()        Validate Claude API key format
#   - validate_disk_space()     Check available disk space
#   - cleanup_on_exit()         Cleanup function for script termination
#   - handle_signal()           Signal handler for graceful shutdown
#   - format_error_message()    Format consistent error messages
#   - suggest_recovery()        Provide recovery suggestions
#
# Usage:
#   source "${RALPH_DIR}/lib/error-handling.sh"
#   setup_error_handling

set -euo pipefail

# Global variables
ERROR_LOG_DIR=""
ERROR_LOG_FILE=""
SCRIPT_NAME=""
SCRIPT_PID=$$

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Initialize error handling for the current script
# Args:
#   $1 - script name (optional, defaults to basename of calling script)
#   $2 - log directory (optional, defaults to ~/.portableralph/logs)
setup_error_handling() {
    local script_name="${1:-$(basename "${BASH_SOURCE[1]}")}"
    local log_dir="${2:-}"
    
    SCRIPT_NAME="$script_name"
    
    # Set up logging directory
    if [ -z "$log_dir" ]; then
        if [ -n "${HOME:-}" ]; then
            ERROR_LOG_DIR="${HOME}/.portableralph/logs"
        else
            ERROR_LOG_DIR="/tmp/portableralph-logs"
        fi
    else
        ERROR_LOG_DIR="$log_dir"
    fi
    
    # Create log directory with fallback
    if ! mkdir -p "$ERROR_LOG_DIR" 2>/dev/null; then
        ERROR_LOG_DIR="/tmp/portableralph-logs"
        mkdir -p "$ERROR_LOG_DIR" 2>/dev/null || ERROR_LOG_DIR="/tmp"
    fi
    
    # Set log file name with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    ERROR_LOG_FILE="${ERROR_LOG_DIR}/${script_name}_${timestamp}.log"
    
    # Set up signal handlers for graceful shutdown
    trap 'handle_signal SIGINT' INT
    trap 'handle_signal SIGTERM' TERM
    trap 'cleanup_on_exit $?' EXIT
    
    # Log initialization
    log_info "Error handling initialized for $script_name (PID: $SCRIPT_PID)"
    log_info "Log file: $ERROR_LOG_FILE"
}

# Log error message with timestamp and context
# Args:
#   $1 - error message
#   $2 - optional: error code (default: 1)
log_error() {
    local message="$1"
    local error_code="${2:-1}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format the error message
    local formatted_message
    formatted_message=$(format_error_message "$message" "$error_code")
    
    # Output to stderr with color
    echo -e "${RED}${formatted_message}${NC}" >&2
    
    # Log to file if available
    if [ -n "$ERROR_LOG_FILE" ] && [ -w "$(dirname "$ERROR_LOG_FILE")" ] 2>/dev/null; then
        echo "[$timestamp] [ERROR] [$SCRIPT_NAME:$SCRIPT_PID] $message (code: $error_code)" >> "$ERROR_LOG_FILE"
    fi
}

# Log warning message
# Args:
#   $1 - warning message
log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${YELLOW}Warning: $message${NC}" >&2
    
    if [ -n "$ERROR_LOG_FILE" ] && [ -w "$(dirname "$ERROR_LOG_FILE")" ] 2>/dev/null; then
        echo "[$timestamp] [WARNING] [$SCRIPT_NAME:$SCRIPT_PID] $message" >> "$ERROR_LOG_FILE"
    fi
}

# Log info message
# Args:
#   $1 - info message
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ -n "$ERROR_LOG_FILE" ] && [ -w "$(dirname "$ERROR_LOG_FILE")" ] 2>/dev/null; then
        echo "[$timestamp] [INFO] [$SCRIPT_NAME:$SCRIPT_PID] $message" >> "$ERROR_LOG_FILE"
    fi
}

# Retry command with exponential backoff
# Args:
#   $1 - max attempts (default: 3)
#   $2 - base delay in seconds (default: 1)
#   $3 - max delay in seconds (default: 30)
#   $4+ - command to retry
retry_command() {
    local max_attempts="${1:-3}"
    local base_delay="${2:-1}"
    local max_delay="${3:-30}"
    shift 3
    
    local attempt=1
    local delay=$base_delay
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempting command (try $attempt/$max_attempts): $*"
        
        if "$@"; then
            log_info "Command succeeded on attempt $attempt"
            return 0
        fi
        
        local exit_code=$?
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Command failed after $max_attempts attempts: $*" "$exit_code"
            return $exit_code
        fi
        
        log_warning "Command failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
        sleep "$delay"
        
        # Exponential backoff with jitter
        delay=$((delay * 2))
        if [ $delay -gt $max_delay ]; then
            delay=$max_delay
        fi
        # Add random jitter (0-25% of delay)
        local jitter=$((delay / 4))
        if [ $jitter -gt 0 ]; then
            delay=$((delay + (RANDOM % jitter)))
        fi
        
        attempt=$((attempt + 1))
    done
}

# Validate Claude API key format
# Args:
#   $1 - API key to validate
# Returns:
#   0 if valid, 1 if invalid
validate_api_key() {
    local api_key="$1"
    
    if [ -z "$api_key" ]; then
        log_error "Claude API key is empty or not set"
        suggest_recovery "Set CLAUDE_API_KEY environment variable with your API key from https://console.anthropic.com/"
        return 1
    fi
    
    # Validate format: should start with sk- and be reasonable length
    if [[ ! "$api_key" =~ ^sk-[A-Za-z0-9_-]{40,}$ ]]; then
        log_error "Invalid Claude API key format"
        suggest_recovery "API key should start with 'sk-' and be at least 40+ characters long"
        return 1
    fi
    
    return 0
}

# Validate available disk space
# Args:
#   $1 - required space in MB (default: 100)
#   $2 - path to check (default: current directory)
# Returns:
#   0 if sufficient space, 1 if insufficient
validate_disk_space() {
    local required_mb="${1:-100}"
    local check_path="${2:-.}"
    
    # Get available space in MB
    local available_space
    if command -v df >/dev/null 2>&1; then
        available_space=$(df -m "$check_path" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    else
        log_warning "Cannot check disk space (df command not available)"
        return 0  # Assume OK if we can't check
    fi
    
    if [ "$available_space" -lt "$required_mb" ]; then
        log_error "Insufficient disk space: ${available_space}MB available, ${required_mb}MB required"
        suggest_recovery "Free up disk space or choose a different location"
        return 1
    fi
    
    return 0
}

# Cleanup function called on script exit
# Args:
#   $1 - exit code
cleanup_on_exit() {
    local exit_code="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$exit_code" -eq 0 ]; then
        log_info "Script completed successfully"
    else
        log_error "Script exited with code $exit_code" "$exit_code"
    fi
    
    # Perform any script-specific cleanup
    if type cleanup_script_specific >/dev/null 2>&1; then
        cleanup_script_specific "$exit_code"
    fi
    
    log_info "Cleanup completed"
}

# Signal handler for graceful shutdown
# Args:
#   $1 - signal name
handle_signal() {
    local signal="$1"
    log_warning "Received signal $signal, shutting down gracefully..."
    
    # Kill any background jobs
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Perform cleanup
    if type cleanup_script_specific >/dev/null 2>&1; then
        cleanup_script_specific 130
    fi
    
    exit 130
}

# Format consistent error messages
# Args:
#   $1 - error message
#   $2 - optional: error code
format_error_message() {
    local message="$1"
    local error_code="${2:-}"
    
    if [ -n "$error_code" ] && [ "$error_code" != "1" ]; then
        echo "Error ($error_code): $message"
    else
        echo "Error: $message"
    fi
}

# Suggest recovery actions for common errors
# Args:
#   $1 - recovery suggestion
suggest_recovery() {
    local suggestion="$1"
    echo -e "${BLUE}Suggestion: $suggestion${NC}" >&2
}

# Validate network connectivity
# Args:
#   $1 - optional: host to test (default: anthropic.com)
#   $2 - optional: timeout in seconds (default: 5)
# Returns:
#   0 if connected, 1 if not
validate_network_connectivity() {
    local host="${1:-anthropic.com}"
    local timeout="${2:-5}"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time "$timeout" --head "https://$host" >/dev/null 2>&1; then
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --timeout="$timeout" --spider "https://$host" 2>/dev/null; then
            return 0
        fi
    elif command -v nc >/dev/null 2>&1; then
        if nc -w "$timeout" -z "$host" 443 2>/dev/null; then
            return 0
        fi
    fi
    
    log_error "Network connectivity test failed for $host"
    suggest_recovery "Check your internet connection and try again"
    return 1
}

# Validate command dependencies
# Args:
#   $@ - list of required commands
# Returns:
#   0 if all commands available, 1 if any missing
validate_dependencies() {
    local missing_commands=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        suggest_recovery "Install missing commands using your package manager"
        return 1
    fi
    
    return 0
}

# Enhanced file validation with recovery suggestions
# Args:
#   $1 - file path
#   $2 - optional: file type description (default: "file")
# Returns:
#   0 if valid, 1 if invalid
validate_file_enhanced() {
    local file_path="$1"
    local file_type="${2:-file}"
    
    if [ -z "$file_path" ]; then
        log_error "No $file_type specified"
        return 1
    fi
    
    if [ ! -e "$file_path" ]; then
        log_error "$file_type not found: $file_path"
        suggest_recovery "Check the file path and ensure the file exists"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        log_error "$file_type is not readable: $file_path"
        suggest_recovery "Check file permissions: chmod 644 '$file_path'"
        return 1
    fi
    
    # Check if file is empty
    if [ ! -s "$file_path" ]; then
        log_warning "$file_type is empty: $file_path"
    fi
    
    return 0
}

# Quick check if error handling is initialized
is_error_handling_initialized() {
    [ -n "$ERROR_LOG_FILE" ] && [ -n "$SCRIPT_NAME" ]
}

# Legacy compatibility function names
validate_webhook_url() {
    if [ -f "${RALPH_DIR:-}/lib/validation.sh" ]; then
        source "${RALPH_DIR}/lib/validation.sh"
        validate_url "$@"
    else
        log_warning "Validation library not found, using basic URL check"
        local url="$1"
        [[ "$url" =~ ^https?:// ]]
    fi
}
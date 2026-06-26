#!/bin/bash
# platform-utils.sh - Cross-platform utilities for PortableRalph
# Functions for path handling, process management, and platform detection
#
# Usage:
#   source ./lib/platform-utils.sh
#   OS=$(detect_os)
#   NORMALIZED_PATH=$(normalize_path "/path/to/file")

# Detect operating system
# Returns: Linux, macOS, WSL, Windows, or Unknown
detect_os() {
    case "$(uname -s)" in
        Linux*)
            # Check if running under WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "WSL"
            else
                echo "Linux"
            fi
            ;;
        Darwin*)
            echo "macOS"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "Windows"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Check if running on Windows (including WSL and Git Bash)
is_windows() {
    local os=$(detect_os)
    [[ "$os" == "Windows" || "$os" == "WSL" ]]
}

# Check if running on Unix-like system
is_unix() {
    local os=$(detect_os)
    [[ "$os" == "Linux" || "$os" == "macOS" ]]
}

# Check if running in WSL
is_wsl() {
    local os=$(detect_os)
    [[ "$os" == "WSL" ]]
}

# Normalize path separators for current platform
# Args: $1 = path
# Returns: normalized path (/ on Unix, \ on Windows)
normalize_path() {
    local path="$1"
    local os=$(detect_os)

    case "$os" in
        Windows)
            # Convert forward slashes to backslashes
            echo "$path" | sed 's/\//\\/g'
            ;;
        *)
            # Convert backslashes to forward slashes
            echo "$path" | sed 's/\\/\//g'
            ;;
    esac
}

# Convert WSL path to Windows path
# Args: $1 = WSL path (e.g., /mnt/c/Users/...)
# Returns: Windows path (e.g., C:\Users\...)
wsl_to_windows_path() {
    local wsl_path="$1"

    if ! is_wsl; then
        echo "$wsl_path"
        return
    fi

    # Use wslpath if available
    if command -v wslpath &> /dev/null; then
        wslpath -w "$wsl_path"
    else
        # Manual conversion for /mnt/c/... style paths
        if [[ "$wsl_path" =~ ^/mnt/([a-z])(/.*)?$ ]]; then
            local drive_letter="${BASH_REMATCH[1]}"
            local rest_of_path="${BASH_REMATCH[2]:-}"
            local windows_path="${drive_letter^^}:${rest_of_path//\//\\}"
            echo "$windows_path"
        else
            echo "$wsl_path"
        fi
    fi
}

# Convert Windows path to WSL path
# Args: $1 = Windows path (e.g., C:\Users\...)
# Returns: WSL path (e.g., /mnt/c/Users/...)
windows_to_wsl_path() {
    local win_path="$1"

    if ! is_wsl; then
        echo "$win_path"
        return
    fi

    # Use wslpath if available
    if command -v wslpath &> /dev/null; then
        wslpath -u "$win_path"
    else
        # Manual conversion for C:\... style paths
        if [[ "$win_path" =~ ^([A-Za-z]):(.*)$ ]]; then
            local drive_letter="${BASH_REMATCH[1]}"
            local rest_of_path="${BASH_REMATCH[2]}"
            local wsl_path="/mnt/${drive_letter,,}${rest_of_path//\\//}"
            echo "$wsl_path"
        else
            echo "$win_path"
        fi
    fi
}

# Get absolute path in platform-appropriate format
# Args: $1 = relative or absolute path
# Returns: absolute path
get_absolute_path() {
    local path="$1"

    if [ -z "$path" ]; then
        echo "Error: get_absolute_path requires a path argument" >&2
        return 1
    fi

    # Use realpath if available
    if command -v realpath &> /dev/null; then
        local result
        result=$(realpath "$path" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$result"
        else
            echo "Error: Cannot resolve absolute path for: $path" >&2
            echo "$path"
            return 1
        fi
    else
        # Fallback to manual resolution
        if [[ "$path" = /* ]]; then
            echo "$path"
        else
            echo "$(pwd)/$path"
        fi
    fi
}

# Check if a path is absolute
# Args: $1 = path
# Returns: 0 if absolute, 1 if relative
is_absolute_path() {
    local path="$1"
    local os=$(detect_os)

    case "$os" in
        Windows)
            # Windows absolute: C:\... or \\server\...
            [[ "$path" =~ ^[A-Za-z]: ]] || [[ "$path" =~ ^\\\\ ]]
            ;;
        *)
            # Unix absolute: /...
            [[ "$path" = /* ]]
            ;;
    esac
}

# Find a command in PATH (cross-platform which/where)
# Args: $1 = command name
# Returns: full path to command or empty string
find_command() {
    local cmd="$1"

    if command -v "$cmd" &> /dev/null; then
        command -v "$cmd"
    else
        return 1
    fi
}

# Check if a process is running
# Args: $1 = process ID
# Returns: 0 if running, 1 if not
is_process_running() {
    local pid="$1"

    if [ -z "$pid" ]; then
        return 1
    fi

    # Check if process exists
    if kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Kill a process gracefully (SIGTERM) with timeout, then force (SIGKILL)
# Args: $1 = process ID, $2 = timeout in seconds (default: 5)
# Returns: 0 if killed, 1 if failed
kill_process_graceful() {
    local pid="$1"
    local timeout="${2:-5}"

    if [ -z "$pid" ]; then
        echo "Error: kill_process_graceful requires a PID argument" >&2
        return 1
    fi

    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid PID (must be numeric): $pid" >&2
        return 1
    fi

    if ! is_process_running "$pid"; then
        return 0
    fi

    # Send SIGTERM
    if ! kill "$pid" 2>/dev/null; then
        echo "Error: Failed to send SIGTERM to process $pid" >&2
        return 1
    fi

    # Wait for process to exit
    local elapsed=0
    while is_process_running "$pid" && [ "$elapsed" -lt "$timeout" ]; do
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # If still running, force kill
    if is_process_running "$pid"; then
        if ! kill -9 "$pid" 2>/dev/null; then
            echo "Error: Failed to send SIGKILL to process $pid" >&2
            return 1
        fi
        sleep 1
    fi

    # Check if process is dead
    if is_process_running "$pid"; then
        echo "Error: Process $pid could not be killed" >&2
        return 1
    else
        return 0
    fi
}

# Get process IDs by name pattern
# Args: $1 = process name or pattern
# Returns: space-separated list of PIDs
get_pids_by_name() {
    local pattern="$1"

    # Use pgrep if available
    if command -v pgrep &> /dev/null; then
        pgrep -f "$pattern" 2>/dev/null || true
    else
        # Fallback to ps + grep
        ps aux | grep "$pattern" | grep -v grep | awk '{print $2}' || true
    fi
}

# Create a lock file to prevent concurrent execution
# Args: $1 = lock file path
# Returns: 0 if lock acquired, 1 if already locked
acquire_lock() {
    local lock_file="$1"
    local pid=$$

    if [ -z "$lock_file" ]; then
        echo "Error: acquire_lock requires a lock file path argument" >&2
        return 1
    fi

    # Check if lock file exists and process is still running
    if [ -f "$lock_file" ]; then
        local existing_pid=$(cat "$lock_file" 2>/dev/null)
        if [ -n "$existing_pid" ] && is_process_running "$existing_pid"; then
            echo "Error: Lock already held by process $existing_pid" >&2
            echo "Lock file: $lock_file" >&2
            return 1
        else
            # Stale lock file, remove it
            echo "Warning: Removing stale lock file (process $existing_pid not running)" >&2
            rm -f "$lock_file" 2>/dev/null || true
        fi
    fi

    # Create lock file with current PID
    if ! echo "$pid" > "$lock_file" 2>/dev/null; then
        echo "Error: Failed to create lock file: $lock_file" >&2
        echo "Check directory permissions" >&2
        return 1
    fi

    return 0
}

# Release a lock file
# Args: $1 = lock file path
release_lock() {
    local lock_file="$1"
    rm -f "$lock_file" 2>/dev/null || true
}

# Set file permissions (cross-platform)
# Args: $1 = file path, $2 = mode (e.g., 755, 600)
set_permissions() {
    local file="$1"
    local mode="$2"
    local os=$(detect_os)

    if [ -z "$file" ]; then
        echo "Error: set_permissions requires a file path argument" >&2
        return 1
    fi

    if [ -z "$mode" ]; then
        echo "Error: set_permissions requires a mode argument (e.g., 755, 600)" >&2
        return 1
    fi

    if [ ! -e "$file" ]; then
        echo "Error: File does not exist: $file" >&2
        return 1
    fi

    case "$os" in
        Windows)
            # Windows: use icacls or skip
            # This is complex, so we skip for now (PowerShell version handles it)
            return 0
            ;;
        *)
            if ! chmod "$mode" "$file" 2>/dev/null; then
                echo "Error: Failed to set permissions $mode on file: $file" >&2
                return 1
            fi
            ;;
    esac
}

# Make a file executable (cross-platform)
# Args: $1 = file path
make_executable() {
    local file="$1"
    set_permissions "$file" "755"
}

# Get temporary directory (cross-platform)
get_temp_dir() {
    local os=$(detect_os)

    case "$os" in
        Windows)
            # In Git Bash/MSYS, prefer POSIX /tmp over $TEMP (which has
            # Windows backslash paths that break bash operations).
            if [ -d "/tmp" ]; then
                echo "/tmp"
            else
                echo "${TEMP:-${TMP:-/tmp}}"
            fi
            ;;
        WSL)
            echo "${TMPDIR:-/tmp}"
            ;;
        *)
            echo "${TMPDIR:-/tmp}"
            ;;
    esac
}

# Get null device path (cross-platform)
# Returns: /dev/null on Unix, NUL on Windows CMD, /dev/null for Git Bash/WSL
get_null_device() {
    local os=$(detect_os)

    case "$os" in
        Windows)
            # Check if we're in a POSIX-like shell (Git Bash, MSYS, Cygwin)
            if [ -e "/dev/null" ]; then
                echo "/dev/null"
            else
                # Pure Windows CMD/PowerShell
                echo "NUL"
            fi
            ;;
        *)
            echo "/dev/null"
            ;;
    esac
}

# Get user home directory (cross-platform)
# Returns appropriate home directory for the current environment
get_home_dir() {
    local os=$(detect_os)

    case "$os" in
        Windows)
            # In Git Bash/MSYS/Cygwin, prefer $HOME (POSIX path like /c/Users/X)
            # over $USERPROFILE (Windows path like C:\Users\X) — backslash paths
            # break bash path concatenation and file operations.
            if [ -n "${HOME:-}" ]; then
                echo "$HOME"
            else
                echo "${USERPROFILE:-~}"
            fi
            ;;
        *)
            echo "${HOME:-~}"
            ;;
    esac
}

# Get shell configuration file path (cross-platform)
# Returns the appropriate shell config file for the current shell
get_shell_config() {
    local os=$(detect_os)

    # For Windows PowerShell
    if [ "$os" = "Windows" ] && [ -n "${PSModulePath:-}" ]; then
        # PowerShell profile
        echo "${PROFILE:-$HOME/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1}"
        return
    fi

    # Detect shell for Unix-like systems
    if [ -n "${ZSH_VERSION:-}" ] || [[ "${SHELL:-}" == *"zsh"* ]]; then
        echo "${HOME}/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ] || [[ "${SHELL:-}" == *"bash"* ]]; then
        echo "${HOME}/.bashrc"
    else
        # Default to .bashrc
        echo "${HOME}/.bashrc"
    fi
}

# Get environment configuration file path (cross-platform)
# Returns the location where .ralph.env should be stored
get_config_dir() {
    local os=$(detect_os)

    case "$os" in
        Windows)
            # Windows: use APPDATA or USERPROFILE
            if [ -n "${APPDATA:-}" ]; then
                echo "${APPDATA}/ralph"
            else
                echo "${USERPROFILE:-${HOME}}/.ralph"
            fi
            ;;
        *)
            # Unix: use HOME
            echo "${HOME}"
            ;;
    esac
}

# Escape string for safe use in shell commands
# Args: $1 = string to escape
# Returns: escaped string
escape_shell_string() {
    local str="$1"
    # Escape single quotes by replacing ' with '\''
    echo "$str" | sed "s/'/'\\\\''/g"
}

# ============================================================================
# Windows Compatibility Enhancements
# ============================================================================

# Check if running in Git Bash on Windows
# Returns: 0 if Git Bash, 1 otherwise
is_git_bash() {
    [[ "$(uname -s)" =~ ^MINGW ]] || [[ "$(uname -s)" =~ ^MSYS ]]
}

# Check if running in Cygwin
# Returns: 0 if Cygwin, 1 otherwise
is_cygwin() {
    [[ "$(uname -s)" =~ ^CYGWIN ]]
}

# Check if running in a Windows environment (Git Bash, WSL, or Cygwin)
# Returns: 0 if Windows environment, 1 otherwise
is_windows_environment() {
    is_windows || is_wsl || is_git_bash || is_cygwin
}

# Convert path from Unix to Windows format (for Git Bash/WSL)
# Args: $1 = Unix path
# Returns: Windows path if in Windows environment, otherwise original path
unix_to_windows_path() {
    local path="$1"
    local os=$(detect_os)

    case "$os" in
        WSL)
            wsl_to_windows_path "$path"
            ;;
        Windows)
            # Git Bash style: /c/Users -> C:\Users
            if [[ "$path" =~ ^/([a-z])/(.*)$ ]]; then
                local drive="${BASH_REMATCH[1]^^}"
                local rest="${BASH_REMATCH[2]}"
                echo "${drive}:\\${rest//\//\\}"
            else
                # Just convert slashes
                echo "$path" | sed 's/\//\\/g'
            fi
            ;;
        *)
            echo "$path"
            ;;
    esac
}

# Check if a command is available, with Windows-appropriate fallbacks
# Args: $1 = command name
#       $2 = optional fallback command for Windows
# Returns: 0 if available, 1 if not
check_command_available() {
    local cmd="$1"
    local windows_fallback="${2:-}"

    if command -v "$cmd" &> /dev/null; then
        return 0
    fi

    # Check for Windows fallback
    if is_windows_environment && [ -n "$windows_fallback" ]; then
        if command -v "$windows_fallback" &> /dev/null; then
            return 0
        fi
    fi

    return 1
}

# Get the appropriate grep command (grep or findstr on Windows)
# Returns: command name to use
get_grep_command() {
    if check_command_available "grep"; then
        echo "grep"
    elif is_windows && command -v findstr &> /dev/null; then
        echo "findstr"
    else
        echo "grep"  # Default, may fail
    fi
}

# Get the appropriate find command (find or where/dir on Windows)
# Returns: command name to use
get_find_command() {
    if check_command_available "find"; then
        echo "find"
    elif is_windows && command -v where &> /dev/null; then
        echo "where"
    else
        echo "find"  # Default, may fail
    fi
}

# Get the appropriate sed command (sed or PowerShell on Windows)
# Returns: command name to use
get_sed_command() {
    if check_command_available "sed"; then
        echo "sed"
    else
        echo "sed"  # Default, may fail
    fi
}

# Get the appropriate awk command (awk or gawk on Windows)
# Returns: command name to use
get_awk_command() {
    if check_command_available "awk"; then
        echo "awk"
    elif check_command_available "gawk"; then
        echo "gawk"
    else
        echo "awk"  # Default, may fail
    fi
}

# Safe grep wrapper with fallback to findstr on Windows
# Args: all grep arguments
# Note: This provides basic grep functionality with Windows compatibility
safe_grep() {
    local grep_cmd=$(get_grep_command)

    if [ "$grep_cmd" = "findstr" ]; then
        # Convert common grep options to findstr
        # This is basic - not all options supported
        findstr "$@" 2>/dev/null
    else
        grep "$@" 2>/dev/null
    fi
}

# Safe find wrapper with platform detection
# Args: all find arguments
# Note: This provides basic find functionality with Windows compatibility
safe_find() {
    local find_cmd=$(get_find_command)

    if [ "$find_cmd" = "where" ]; then
        # Windows where command has different syntax
        # This is a very limited implementation
        where "$@" 2>/dev/null
    else
        find "$@" 2>/dev/null
    fi
}

# Get process list in a cross-platform way
# Args: $1 = optional process name filter
# Returns: process list formatted appropriately for platform
safe_ps() {
    local filter="${1:-}"

    if command -v ps &> /dev/null; then
        if [ -n "$filter" ]; then
            ps aux | grep "$filter" | grep -v grep
        else
            ps aux
        fi
    elif is_windows && command -v tasklist &> /dev/null; then
        # Windows tasklist command
        if [ -n "$filter" ]; then
            tasklist | grep -i "$filter"
        else
            tasklist
        fi
    else
        echo "Error: No process listing command available" >&2
        return 1
    fi
}

# Kill process with cross-platform support
# Args: $1 = PID or process name
# Returns: 0 if successful, 1 otherwise
safe_kill() {
    local target="$1"

    if [ -z "$target" ]; then
        echo "Error: safe_kill requires a PID or process name" >&2
        return 1
    fi

    # Check if numeric PID
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        if command -v kill &> /dev/null; then
            kill "$target" 2>/dev/null
        elif is_windows && command -v taskkill &> /dev/null; then
            taskkill /PID "$target" /F 2>/dev/null
        else
            echo "Error: No kill command available" >&2
            return 1
        fi
    else
        # Process name
        if command -v pkill &> /dev/null; then
            pkill "$target" 2>/dev/null
        elif is_windows && command -v taskkill &> /dev/null; then
            taskkill /IM "$target" /F 2>/dev/null
        else
            echo "Error: No kill command available" >&2
            return 1
        fi
    fi
}

# Count lines with cross-platform support
# Args: $1 = file path (optional, uses stdin if not provided)
# Returns: line count
safe_wc() {
    local file="${1:-}"

    if command -v wc &> /dev/null; then
        if [ -n "$file" ]; then
            wc -l "$file" 2>/dev/null
        else
            wc -l
        fi
    else
        # Fallback: count lines with basic shell
        if [ -n "$file" ]; then
            if [ -f "$file" ]; then
                local count=0
                while IFS= read -r line; do
                    count=$((count + 1))
                done < "$file"
                echo "$count $file"
            else
                echo "0 $file"
            fi
        else
            local count=0
            while IFS= read -r line; do
                count=$((count + 1))
            done
            echo "$count"
        fi
    fi
}

# Check if running with appropriate privileges
# Returns: 0 if has admin/root, 1 if not
has_admin_privileges() {
    local os=$(detect_os)

    case "$os" in
        Windows)
            # Check for Administrator privileges (Git Bash)
            if command -v net &> /dev/null; then
                net session &>/dev/null
                return $?
            else
                # Assume no admin if can't check
                return 1
            fi
            ;;
        WSL)
            # In WSL, check if user is root
            [ "$(id -u)" -eq 0 ]
            ;;
        *)
            # Unix: check if root
            [ "$(id -u)" -eq 0 ]
            ;;
    esac
}

# Get the appropriate line ending for the platform
# Returns: \r\n for Windows, \n for Unix
get_line_ending() {
    local os=$(detect_os)

    case "$os" in
        Windows)
            printf "\r\n"
            ;;
        *)
            printf "\n"
            ;;
    esac
}

# Convert line endings in a file
# Args: $1 = file path
#       $2 = target format ('unix' or 'windows')
# Returns: 0 if successful, 1 otherwise
convert_line_endings() {
    local file="$1"
    local format="${2:-unix}"

    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    case "$format" in
        unix)
            # Convert to Unix line endings (LF)
            if command -v dos2unix &> /dev/null; then
                dos2unix "$file" 2>/dev/null
            elif command -v sed &> /dev/null; then
                sed -i 's/\r$//' "$file"
            else
                echo "Warning: Cannot convert line endings, no suitable command found" >&2
            fi
            ;;
        windows)
            # Convert to Windows line endings (CRLF)
            if command -v unix2dos &> /dev/null; then
                unix2dos "$file" 2>/dev/null
            elif command -v sed &> /dev/null; then
                sed -i 's/$/\r/' "$file"
            else
                echo "Warning: Cannot convert line endings, no suitable command found" >&2
            fi
            ;;
        *)
            echo "Error: Invalid format '$format'. Use 'unix' or 'windows'" >&2
            return 1
            ;;
    esac
}

# Get environment variable with platform-specific handling
# Args: $1 = variable name
#       $2 = default value (optional)
# Returns: variable value or default
get_env_var() {
    local var_name="$1"
    local default_value="${2:-}"
    local value="${!var_name:-}"

    if [ -z "$value" ]; then
        # Try common Windows variable names
        if is_windows_environment; then
            case "$var_name" in
                HOME)
                    value="${USERPROFILE:-$default_value}"
                    ;;
                TMPDIR)
                    value="${TEMP:-${TMP:-$default_value}}"
                    ;;
                USER)
                    value="${USERNAME:-$default_value}"
                    ;;
                *)
                    value="$default_value"
                    ;;
            esac
        else
            value="$default_value"
        fi
    fi

    echo "$value"
}

# Check if we need to use Windows-style path for a command
# Args: $1 = command name
# Returns: 0 if Windows path needed, 1 otherwise
needs_windows_path() {
    local cmd="$1"

    # Commands that need Windows paths in Git Bash/WSL
    local windows_commands="explorer.exe notepad.exe code.exe powershell.exe cmd.exe"

    for win_cmd in $windows_commands; do
        if [[ "$cmd" == "$win_cmd" ]]; then
            return 0
        fi
    done

    return 1
}

# Execute a command with proper path conversion
# Args: $1 = command
#       $@ = arguments (paths will be converted if needed)
# Returns: command exit code
execute_with_path_conversion() {
    local cmd="$1"
    shift

    if needs_windows_path "$cmd" && is_windows_environment; then
        # Convert paths in arguments
        local converted_args=()
        for arg in "$@"; do
            if [ -e "$arg" ]; then
                # This is a file/directory, convert the path
                converted_args+=("$(unix_to_windows_path "$arg")")
            else
                converted_args+=("$arg")
            fi
        done
        "$cmd" "${converted_args[@]}"
    else
        "$cmd" "$@"
    fi
}

# Export functions for use in other scripts
export -f detect_os
export -f is_windows
export -f is_unix
export -f is_wsl
export -f is_git_bash
export -f is_cygwin
export -f is_windows_environment
export -f normalize_path
export -f wsl_to_windows_path
export -f windows_to_wsl_path
export -f unix_to_windows_path
export -f get_absolute_path
export -f is_absolute_path
export -f find_command
export -f is_process_running
export -f kill_process_graceful
export -f get_pids_by_name
export -f acquire_lock
export -f release_lock
export -f set_permissions
export -f make_executable
export -f get_temp_dir
export -f get_null_device
export -f get_home_dir
export -f get_shell_config
export -f get_config_dir
export -f escape_shell_string
export -f check_command_available
export -f get_grep_command
export -f get_find_command
export -f get_sed_command
export -f get_awk_command
export -f safe_grep
export -f safe_find
export -f safe_ps
export -f safe_kill
export -f safe_wc
export -f has_admin_privileges
export -f get_line_ending
export -f convert_line_endings
export -f get_env_var
export -f needs_windows_path
export -f execute_with_path_conversion

#!/bin/bash
# test-constants-lib.sh - Tests for lib/constants.sh
# Verifies all constants are defined and read-only
#
# Tests:
#   - All constants are defined with expected values
#   - Constants are exported for use in scripts
#   - Constants are read-only (cannot be modified)
#   - Scripts can load and use constants
#   - Constants have sensible default values

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output-constants"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

setup() {
    mkdir -p "$TEST_DIR"

    # Source the constants library
    if [ -f "$RALPH_DIR/lib/constants.sh" ]; then
        source "$RALPH_DIR/lib/constants.sh"
    else
        echo "ERROR: constants.sh not found at $RALPH_DIR/lib/constants.sh"
        exit 1
    fi
}

teardown() {
    rm -rf "$TEST_DIR"
}

assert_defined() {
    local var_name="$1"
    local message="${2:-Variable $var_name should be defined}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ -n "${!var_name+x}" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" = "$actual" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_readonly() {
    local var_name="$1"
    local message="${2:-Variable $var_name should be readonly}"

    TESTS_RUN=$((TESTS_RUN + 1))

    # Try to modify the variable (this should fail for readonly vars)
    local test_result=0
    eval "${var_name}=999 2>/dev/null" || test_result=$?

    if [ $test_result -ne 0 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message (variable can be modified)"
        return 1
    fi
}

assert_exported() {
    local var_name="$1"
    local message="${2:-Variable $var_name should be exported}"

    TESTS_RUN=$((TESTS_RUN + 1))

    # Check if variable is in export list
    # Note: readonly exported vars show as "declare -rx" not "declare -x"
    if export -p | grep -qE "declare -[a-z]*x[a-z]* $var_name="; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        return 1
    fi
}

# ============================================
# TIMEOUT AND DELAY CONSTANTS
# ============================================

test_timeout_constants() {
    echo ""
    echo "Testing: Timeout and delay constants"

    assert_defined "HTTP_MAX_TIME" "HTTP_MAX_TIME is defined"
    assert_defined "HTTP_CONNECT_TIMEOUT" "HTTP_CONNECT_TIMEOUT is defined"
    assert_defined "HTTP_SMTP_TIMEOUT" "HTTP_SMTP_TIMEOUT is defined"
    assert_defined "CUSTOM_SCRIPT_TIMEOUT" "CUSTOM_SCRIPT_TIMEOUT is defined"
    assert_defined "PROCESS_STOP_TIMEOUT" "PROCESS_STOP_TIMEOUT is defined"
    assert_defined "PROCESS_VERIFY_DELAY" "PROCESS_VERIFY_DELAY is defined"
    assert_defined "ITERATION_DELAY" "ITERATION_DELAY is defined"

    # Check reasonable values
    assert_equals "10" "$HTTP_MAX_TIME" "HTTP_MAX_TIME = 10 seconds"
    assert_equals "5" "$HTTP_CONNECT_TIMEOUT" "HTTP_CONNECT_TIMEOUT = 5 seconds"
    assert_equals "30" "$HTTP_SMTP_TIMEOUT" "HTTP_SMTP_TIMEOUT = 30 seconds"
    assert_equals "30" "$CUSTOM_SCRIPT_TIMEOUT" "CUSTOM_SCRIPT_TIMEOUT = 30 seconds"
}

# ============================================
# RATE LIMIT CONSTANTS
# ============================================

test_rate_limit_constants() {
    echo ""
    echo "Testing: Rate limit constants"

    assert_defined "RATE_LIMIT_MAX" "RATE_LIMIT_MAX is defined"
    assert_defined "RATE_LIMIT_WINDOW" "RATE_LIMIT_WINDOW is defined"
    assert_defined "EMAIL_BATCH_DELAY_DEFAULT" "EMAIL_BATCH_DELAY_DEFAULT is defined"
    assert_defined "EMAIL_BATCH_MAX_DEFAULT" "EMAIL_BATCH_MAX_DEFAULT is defined"
    assert_defined "EMAIL_BATCH_LOCK_RETRIES" "EMAIL_BATCH_LOCK_RETRIES is defined"
    assert_defined "EMAIL_BATCH_LOCK_DELAY" "EMAIL_BATCH_LOCK_DELAY is defined"

    # Check values
    assert_equals "60" "$RATE_LIMIT_MAX" "RATE_LIMIT_MAX = 60 per minute"
    assert_equals "60" "$RATE_LIMIT_WINDOW" "RATE_LIMIT_WINDOW = 60 seconds"
}

# ============================================
# RETRY LOGIC CONSTANTS
# ============================================

test_retry_constants() {
    echo ""
    echo "Testing: Retry logic constants"

    assert_defined "NOTIFY_MAX_RETRIES" "NOTIFY_MAX_RETRIES is defined"
    assert_defined "NOTIFY_RETRY_DELAY" "NOTIFY_RETRY_DELAY is defined"
    assert_defined "CLAUDE_MAX_RETRIES" "CLAUDE_MAX_RETRIES is defined"
    assert_defined "CLAUDE_RETRY_DELAY" "CLAUDE_RETRY_DELAY is defined"
    assert_defined "SLACK_MAX_FAILURES" "SLACK_MAX_FAILURES is defined"

    # Check values
    assert_equals "3" "$NOTIFY_MAX_RETRIES" "NOTIFY_MAX_RETRIES = 3"
    assert_equals "2" "$NOTIFY_RETRY_DELAY" "NOTIFY_RETRY_DELAY = 2 seconds"
    assert_equals "3" "$CLAUDE_MAX_RETRIES" "CLAUDE_MAX_RETRIES = 3"
    assert_equals "5" "$CLAUDE_RETRY_DELAY" "CLAUDE_RETRY_DELAY = 5 seconds"
}

# ============================================
# MONITORING CONSTANTS
# ============================================

test_monitoring_constants() {
    echo ""
    echo "Testing: Monitoring constants"

    assert_defined "MONITOR_INTERVAL_DEFAULT" "MONITOR_INTERVAL_DEFAULT is defined"
    assert_defined "MONITOR_INTERVAL_MIN" "MONITOR_INTERVAL_MIN is defined"
    assert_defined "MONITOR_INTERVAL_MAX" "MONITOR_INTERVAL_MAX is defined"
    assert_defined "MONITOR_PROGRESS_THRESHOLD" "MONITOR_PROGRESS_THRESHOLD is defined"
    assert_defined "LOG_MAX_SIZE" "LOG_MAX_SIZE is defined"
    assert_defined "LOG_MAX_BACKUPS" "LOG_MAX_BACKUPS is defined"
    assert_defined "TIME_DISPLAY_MINUTE" "TIME_DISPLAY_MINUTE is defined"
    assert_defined "TIME_DISPLAY_HOUR" "TIME_DISPLAY_HOUR is defined"

    # Check values
    assert_equals "300" "$MONITOR_INTERVAL_DEFAULT" "MONITOR_INTERVAL_DEFAULT = 300 seconds (5 min)"
    assert_equals "10" "$MONITOR_INTERVAL_MIN" "MONITOR_INTERVAL_MIN = 10 seconds"
    assert_equals "86400" "$MONITOR_INTERVAL_MAX" "MONITOR_INTERVAL_MAX = 86400 seconds (24 hours)"
    assert_equals "5" "$MONITOR_PROGRESS_THRESHOLD" "MONITOR_PROGRESS_THRESHOLD = 5%"
}

# ============================================
# NOTIFICATION FREQUENCY CONSTANTS
# ============================================

test_notification_frequency_constants() {
    echo ""
    echo "Testing: Notification frequency constants"

    assert_defined "NOTIFY_FREQUENCY_DEFAULT" "NOTIFY_FREQUENCY_DEFAULT is defined"
    assert_defined "NOTIFY_FREQUENCY_MIN" "NOTIFY_FREQUENCY_MIN is defined"
    assert_defined "NOTIFY_FREQUENCY_MAX" "NOTIFY_FREQUENCY_MAX is defined"

    # Check values
    assert_equals "5" "$NOTIFY_FREQUENCY_DEFAULT" "NOTIFY_FREQUENCY_DEFAULT = 5"
    assert_equals "1" "$NOTIFY_FREQUENCY_MIN" "NOTIFY_FREQUENCY_MIN = 1"
    assert_equals "100" "$NOTIFY_FREQUENCY_MAX" "NOTIFY_FREQUENCY_MAX = 100"
}

# ============================================
# VALIDATION CONSTANTS
# ============================================

test_validation_constants() {
    echo ""
    echo "Testing: Validation limit constants"

    assert_defined "VALIDATION_MIN_DEFAULT" "VALIDATION_MIN_DEFAULT is defined"
    assert_defined "VALIDATION_MAX_DEFAULT" "VALIDATION_MAX_DEFAULT is defined"
    assert_defined "MAX_ITERATIONS_DEFAULT" "MAX_ITERATIONS_DEFAULT is defined"
    assert_defined "MAX_ITERATIONS_MIN" "MAX_ITERATIONS_MIN is defined"
    assert_defined "MAX_ITERATIONS_MAX" "MAX_ITERATIONS_MAX is defined"
    assert_defined "TOKEN_MASK_PREFIX_LENGTH" "TOKEN_MASK_PREFIX_LENGTH is defined"
    assert_defined "MESSAGE_TRUNCATE_LENGTH" "MESSAGE_TRUNCATE_LENGTH is defined"
    assert_defined "ERROR_DETAILS_TRUNCATE_LENGTH" "ERROR_DETAILS_TRUNCATE_LENGTH is defined"

    # Check values
    assert_equals "0" "$VALIDATION_MIN_DEFAULT" "VALIDATION_MIN_DEFAULT = 0"
    assert_equals "999999" "$VALIDATION_MAX_DEFAULT" "VALIDATION_MAX_DEFAULT = 999999"
    assert_equals "8" "$TOKEN_MASK_PREFIX_LENGTH" "TOKEN_MASK_PREFIX_LENGTH = 8"
}

# ============================================
# NETWORK CONSTANTS
# ============================================

test_network_constants() {
    echo ""
    echo "Testing: Network configuration constants"

    assert_defined "HTTP_STATUS_SUCCESS_MIN" "HTTP_STATUS_SUCCESS_MIN is defined"
    assert_defined "HTTP_STATUS_SUCCESS_MAX" "HTTP_STATUS_SUCCESS_MAX is defined"

    # Check values
    assert_equals "200" "$HTTP_STATUS_SUCCESS_MIN" "HTTP_STATUS_SUCCESS_MIN = 200"
    assert_equals "300" "$HTTP_STATUS_SUCCESS_MAX" "HTTP_STATUS_SUCCESS_MAX = 300"
}

# ============================================
# FILE PERMISSION CONSTANTS
# ============================================

test_permission_constants() {
    echo ""
    echo "Testing: File permission constants"

    assert_defined "CONFIG_FILE_MODE" "CONFIG_FILE_MODE is defined"

    # Check value
    assert_equals "600" "$CONFIG_FILE_MODE" "CONFIG_FILE_MODE = 600 (owner read/write only)"
}

# ============================================
# TELEGRAM CONSTANTS
# ============================================

test_telegram_constants() {
    echo ""
    echo "Testing: Telegram validation constants"

    assert_defined "TELEGRAM_TOKEN_PREFIX_MIN" "TELEGRAM_TOKEN_PREFIX_MIN is defined"
    assert_defined "TELEGRAM_TOKEN_PREFIX_MAX" "TELEGRAM_TOKEN_PREFIX_MAX is defined"
    assert_defined "TELEGRAM_TOKEN_SECRET_LENGTH" "TELEGRAM_TOKEN_SECRET_LENGTH is defined"

    # Check values
    assert_equals "8" "$TELEGRAM_TOKEN_PREFIX_MIN" "TELEGRAM_TOKEN_PREFIX_MIN = 8"
    assert_equals "10" "$TELEGRAM_TOKEN_PREFIX_MAX" "TELEGRAM_TOKEN_PREFIX_MAX = 10"
    assert_equals "35" "$TELEGRAM_TOKEN_SECRET_LENGTH" "TELEGRAM_TOKEN_SECRET_LENGTH = 35"
}

# ============================================
# DISPLAY CONSTANTS
# ============================================

test_display_constants() {
    echo ""
    echo "Testing: Display formatting constants"

    assert_defined "SPINNER_FRAMES" "SPINNER_FRAMES is defined"
    assert_defined "LOG_TAIL_LINES" "LOG_TAIL_LINES is defined"
    assert_defined "UPDATE_MAX_BACKUPS" "UPDATE_MAX_BACKUPS is defined"

    # Check values
    assert_equals "10" "$SPINNER_FRAMES" "SPINNER_FRAMES = 10"
    assert_equals "10" "$LOG_TAIL_LINES" "LOG_TAIL_LINES = 10"
    assert_equals "5" "$UPDATE_MAX_BACKUPS" "UPDATE_MAX_BACKUPS = 5"
}

# ============================================
# READONLY VERIFICATION
# ============================================

test_constants_are_readonly() {
    echo ""
    echo "Testing: Constants are readonly"

    # Test a sample of constants to verify they're readonly
    assert_readonly "HTTP_MAX_TIME" "HTTP_MAX_TIME is readonly"
    assert_readonly "NOTIFY_MAX_RETRIES" "NOTIFY_MAX_RETRIES is readonly"
    assert_readonly "MONITOR_INTERVAL_DEFAULT" "MONITOR_INTERVAL_DEFAULT is readonly"
    assert_readonly "CONFIG_FILE_MODE" "CONFIG_FILE_MODE is readonly"
    assert_readonly "TOKEN_MASK_PREFIX_LENGTH" "TOKEN_MASK_PREFIX_LENGTH is readonly"
}

# ============================================
# EXPORT VERIFICATION
# ============================================

test_constants_are_exported() {
    echo ""
    echo "Testing: Constants are exported for scripts"

    # Test that key constants are exported
    assert_exported "HTTP_MAX_TIME" "HTTP_MAX_TIME is exported"
    assert_exported "NOTIFY_MAX_RETRIES" "NOTIFY_MAX_RETRIES is exported"
    assert_exported "MONITOR_INTERVAL_DEFAULT" "MONITOR_INTERVAL_DEFAULT is exported"
    assert_exported "CONFIG_FILE_MODE" "CONFIG_FILE_MODE is exported"
    assert_exported "RATE_LIMIT_MAX" "RATE_LIMIT_MAX is exported"
}

# ============================================
# SCRIPT USAGE TEST
# ============================================

test_script_can_use_constants() {
    echo ""
    echo "Testing: Scripts can load and use constants"

    # Create a test script that uses constants
    local test_script="$TEST_DIR/test-constants-usage.sh"
    cat > "$test_script" << 'EOF'
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
EOF
    chmod +x "$test_script"

    # Run the test script
    local output
    output=$("$test_script" 2>&1)

    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$output" | grep -q "HTTP_MAX_TIME=10" && \
       echo "$output" | grep -q "NOTIFY_MAX_RETRIES=3" && \
       echo "$output" | grep -q "CONFIG_FILE_MODE=600"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Script successfully loads and uses constants"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Script failed to load constants properly"
        echo "Output: $output"
    fi
}

# ============================================
# SANITY CHECKS
# ============================================

test_timeout_sanity() {
    echo ""
    echo "Testing: Timeout values are sensible"

    # HTTP timeouts should be reasonable (5-30 seconds)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$HTTP_MAX_TIME" -ge 5 ] && [ "$HTTP_MAX_TIME" -le 30 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} HTTP_MAX_TIME is sensible ($HTTP_MAX_TIME seconds)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} HTTP_MAX_TIME might be too high/low ($HTTP_MAX_TIME)"
    fi

    # Script timeout should be reasonable (10-60 seconds)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$CUSTOM_SCRIPT_TIMEOUT" -ge 10 ] && [ "$CUSTOM_SCRIPT_TIMEOUT" -le 60 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} CUSTOM_SCRIPT_TIMEOUT is sensible ($CUSTOM_SCRIPT_TIMEOUT seconds)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} CUSTOM_SCRIPT_TIMEOUT might be too high/low ($CUSTOM_SCRIPT_TIMEOUT)"
    fi
}

test_retry_sanity() {
    echo "Testing: Retry values are sensible"

    # Max retries should be 1-5
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$NOTIFY_MAX_RETRIES" -ge 1 ] && [ "$NOTIFY_MAX_RETRIES" -le 5 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} NOTIFY_MAX_RETRIES is sensible ($NOTIFY_MAX_RETRIES)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} NOTIFY_MAX_RETRIES might be too high/low ($NOTIFY_MAX_RETRIES)"
    fi

    # Retry delay should be reasonable (1-10 seconds)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$NOTIFY_RETRY_DELAY" -ge 1 ] && [ "$NOTIFY_RETRY_DELAY" -le 10 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} NOTIFY_RETRY_DELAY is sensible ($NOTIFY_RETRY_DELAY seconds)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} NOTIFY_RETRY_DELAY might be too high/low ($NOTIFY_RETRY_DELAY)"
    fi
}

test_monitoring_sanity() {
    echo "Testing: Monitoring values are sensible"

    # Monitor interval should be 10s to 24h
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$MONITOR_INTERVAL_MIN" -eq 10 ] && [ "$MONITOR_INTERVAL_MAX" -eq 86400 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Monitor interval range is sensible (10s - 24h)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Monitor interval range might be wrong"
    fi

    # Progress threshold should be reasonable (1-10%)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$MONITOR_PROGRESS_THRESHOLD" -ge 1 ] && [ "$MONITOR_PROGRESS_THRESHOLD" -le 10 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} MONITOR_PROGRESS_THRESHOLD is sensible ($MONITOR_PROGRESS_THRESHOLD%)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} MONITOR_PROGRESS_THRESHOLD might be too high/low ($MONITOR_PROGRESS_THRESHOLD)"
    fi
}

# ============================================
# RUN ALL TESTS
# ============================================

run_all_tests() {
    echo "======================================"
    echo "Constants Library Test Suite"
    echo "Testing: lib/constants.sh"
    echo "======================================"

    setup

    test_timeout_constants
    test_rate_limit_constants
    test_retry_constants
    test_monitoring_constants
    test_notification_frequency_constants
    test_validation_constants
    test_network_constants
    test_permission_constants
    test_telegram_constants
    test_display_constants

    test_constants_are_readonly
    test_constants_are_exported
    test_script_can_use_constants

    test_timeout_sanity
    test_retry_sanity
    test_monitoring_sanity

    teardown

    # Print summary
    echo ""
    echo "======================================"
    echo "Constants Library Test Summary"
    echo "======================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All constants library tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some constants library tests failed.${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_all_tests
fi

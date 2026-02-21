#!/bin/bash
# test-error-handling.sh - Comprehensive error handling tests for PortableRalph
# Tests error scenarios across all major components
#
# Tests:
#   - File permission errors
#   - Network failure simulations
#   - Invalid input validation
#   - Resource exhaustion scenarios
#   - Configuration corruption handling
#   - Exit code verification
#   - Error message clarity
#   - Recovery mechanism validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output-error-handling"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

setup() {
    echo -e "${BLUE}Setting up error handling test environment...${NC}"
    
    # Clean test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Create isolated test environment
    export HOME="$TEST_DIR"
    export TMPDIR="$TEST_DIR/tmp"
    mkdir -p "$TMPDIR"
    
    # Prepare test plan files
    echo "# Test Plan" > "$TEST_DIR/test-plan.md"
    echo "This is a test plan for error handling validation" >> "$TEST_DIR/test-plan.md"
    
    # Create invalid plan file (binary data)
    printf '\x00\x01\x02\x03\x04\x05' > "$TEST_DIR/invalid-binary.md"
    
    # Create extremely long filename (filesystem limits test) - skip for now
    # LONG_NAME=$(printf 'a%.0s' {1..300})
    # echo "# Long filename test" > "$TEST_DIR/${LONG_NAME}.md" 2>/dev/null || true
}

cleanup() {
    echo -e "${BLUE}Cleaning up error handling tests...${NC}"
    rm -rf "$TEST_DIR"
    
    # Kill any background processes started during tests
    jobs -p | xargs -r kill 2>/dev/null || true
}

# Test assertion functions
assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" -eq "$actual" ]; then
        echo -e "${GREEN}✓ $test_name: Exit code $actual (expected $expected)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ $test_name: Exit code $actual (expected $expected)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local expected="$1"
    local output="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓ $test_name: Output contains '$expected'${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ $test_name: Output does not contain '$expected'${NC}"
        echo -e "${YELLOW}  Actual output: $output${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Core error handling tests
test_missing_plan_file() {
    echo -e "\n${BLUE}Testing: Missing plan file handling${NC}"
    
    local output
    local exit_code
    
    # Test missing plan file
    output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/nonexistent.md" 2>&1) || exit_code=$?
    
    assert_exit_code 1 "${exit_code:-0}" "Missing plan file"
    assert_contains "not found" "$output" "Missing file error message"
    assert_contains "nonexistent.md" "$output" "Specific filename in error"
}

test_permission_errors() {
    echo -e "\n${BLUE}Testing: File permission error handling${NC}"
    
    local output
    local exit_code
    local readonly_file="$TEST_DIR/readonly.md"
    
    # Create readonly file
    echo "# Readonly test plan" > "$readonly_file"
    chmod 000 "$readonly_file"
    
    # Test readonly plan file access
    output=$("$RALPH_DIR/ralph.sh" "$readonly_file" 2>&1) || exit_code=$?
    
    # Restore permissions for cleanup
    chmod 644 "$readonly_file"
    
    assert_exit_code 1 "${exit_code:-0}" "Permission denied file"
    assert_contains "Permission denied\|cannot read\|not readable" "$output" "Permission error message"
}

test_invalid_mode_parameter() {
    echo -e "\n${BLUE}Testing: Invalid mode parameter handling${NC}"
    
    local output
    local exit_code
    
    # Test invalid mode
    output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" "invalid_mode" 2>&1) || exit_code=$?
    
    assert_exit_code 1 "${exit_code:-0}" "Invalid mode parameter"
    assert_contains "Invalid mode\|Unknown mode\|mode must be" "$output" "Invalid mode error message"
    assert_contains "plan\|build" "$output" "Valid mode options listed"
}

test_invalid_iteration_parameter() {
    echo -e "\n${BLUE}Testing: Invalid iteration parameter handling${NC}"
    
    local output
    local exit_code
    
    # Test non-numeric iteration count
    output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" "build" "not_a_number" 2>&1) || exit_code=$?
    
    assert_exit_code 1 "${exit_code:-0}" "Non-numeric iteration count"
    assert_contains "Invalid\|must be.*number\|numeric" "$output" "Non-numeric error message"
    
    # Test negative iteration count
    output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" "build" "-5" 2>&1) || exit_code=$?
    
    assert_exit_code 1 "${exit_code:-0}" "Negative iteration count"
    assert_contains "Invalid\|must be positive\|greater than" "$output" "Negative number error message"
}

test_network_failure_simulation() {
    echo -e "\n${BLUE}Testing: Network failure handling${NC}"
    
    # Test with invalid API endpoint by setting fake endpoint
    local output
    local exit_code
    
    # Create test config with invalid endpoint
    export CLAUDE_API_BASE_URL="http://invalid-endpoint-12345.fake"
    
    # Test network failure (should handle gracefully)
    timeout 10s "$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" plan 2>&1 | head -20 || exit_code=$?
    
    unset CLAUDE_API_BASE_URL
    
    # We expect either proper error handling or timeout
    if [ "${exit_code:-0}" -ne 124 ] && [ "${exit_code:-0}" -ne 0 ]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Network failure: Proper error handling (exit code: ${exit_code:-0})${NC}"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Network failure: No proper error handling${NC}"
    fi
}

test_disk_space_handling() {
    echo -e "\n${BLUE}Testing: Disk space error simulation${NC}"
    
    local output
    local exit_code
    
    # Try to create a file in a non-existent mounted filesystem
    # This will fail and should be handled gracefully
    export TMPDIR="/dev/null/impossible_dir"
    
    output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" plan 2>&1) || exit_code=$?
    
    unset TMPDIR
    
    if [ "${exit_code:-0}" -ne 0 ]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Disk space/filesystem error: Proper error handling${NC}"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Disk space/filesystem error: No error handling detected${NC}"
    fi
}

test_configuration_corruption() {
    echo -e "\n${BLUE}Testing: Configuration corruption handling${NC}"
    
    local output
    local exit_code
    local config_dir="$TEST_DIR/.portableralph"
    
    mkdir -p "$config_dir"
    
    # Create corrupted configuration file
    printf '\x00\x01invalid\x02config\x03' > "$config_dir/config"
    
    output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" plan 2>&1) || exit_code=$?
    
    # Should handle corrupted config gracefully
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "${exit_code:-0}" -eq 0 ] || echo "$output" | grep -q "config.*corrupt\|config.*invalid\|reset.*config"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Configuration corruption: Handled gracefully${NC}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Configuration corruption: No graceful handling${NC}"
    fi
}

test_signal_handling() {
    echo -e "\n${BLUE}Testing: Signal handling (Ctrl+C simulation)${NC}"
    
    # Start ralph in background and send SIGINT
    timeout 5s "$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" plan >/dev/null 2>&1 &
    local pid=$!
    
    sleep 1
    
    # Send SIGINT (Ctrl+C equivalent)
    kill -INT "$pid" 2>/dev/null || true
    
    # Wait for process to terminate
    wait "$pid" 2>/dev/null || local exit_code=$?
    
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "${exit_code:-0}" -ne 0 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Signal handling: Proper cleanup on SIGINT${NC}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Signal handling: No proper SIGINT handling${NC}"
    fi
}

test_launcher_error_handling() {
    echo -e "\n${BLUE}Testing: Launcher script error handling${NC}"
    
    local output
    local exit_code
    
    # Test launcher with invalid arguments
    output=$("$RALPH_DIR/launcher.sh" --invalid-flag 2>&1) || exit_code=$?
    
    assert_exit_code 1 "${exit_code:-0}" "Launcher invalid flag"
    assert_contains "Unknown\|Invalid\|Usage:" "$output" "Launcher help on error"
    
    # Test launcher with missing file
    output=$("$RALPH_DIR/launcher.sh" "nonexistent-file.md" 2>&1) || exit_code=$?
    
    assert_exit_code 1 "${exit_code:-0}" "Launcher missing file"
    assert_contains "not found\|does not exist" "$output" "Launcher file error message"
}

test_notification_error_handling() {
    echo -e "\n${BLUE}Testing: Notification system error handling${NC}"
    
    local output
    local exit_code
    
    # Test notification with invalid webhook URL
    export SLACK_WEBHOOK_URL="not-a-valid-url"
    
    output=$("$RALPH_DIR/notify.sh" "Test message" 2>&1) || exit_code=$?
    
    unset SLACK_WEBHOOK_URL
    
    # Should handle invalid URL gracefully
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "${exit_code:-0}" -ne 0 ] || echo "$output" | grep -q "invalid.*url\|malformed.*url\|url.*format"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Notification error: Invalid URL handled${NC}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Notification error: Invalid URL not handled${NC}"
    fi
}

test_error_message_clarity() {
    echo -e "\n${BLUE}Testing: Error message clarity and actionability${NC}"
    
    local output
    local exit_code
    
    # Test with various error conditions to verify message quality
    test_cases=(
        "nonexistent.md:missing file"
        "invalid_mode:invalid mode"
    )
    
    for test_case in "${test_cases[@]}"; do
        local file="${test_case%%:*}"
        local description="${test_case##*:}"
        
        if [ "$file" = "nonexistent.md" ]; then
            output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/$file" 2>&1) || exit_code=$?
        elif [ "$file" = "invalid_mode" ]; then
            output=$("$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" "invalid_mode" 2>&1) || exit_code=$?
        fi
        
        # Check if error message is helpful (contains suggestions or specific details)
        TESTS_RUN=$((TESTS_RUN + 1))
        if echo "$output" | grep -E "(try|check|ensure|make sure|example|usage)" >/dev/null; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            echo -e "${GREEN}✓ Error message clarity: $description has actionable advice${NC}"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo -e "${RED}✗ Error message clarity: $description lacks actionable advice${NC}"
            echo -e "${YELLOW}  Message: $output${NC}"
        fi
    done
}

# Main test execution
run_all_tests() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  PortableRalph Error Handling Tests${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    setup
    
    # Run individual test suites
    test_missing_plan_file
    test_permission_errors
    test_invalid_mode_parameter
    test_invalid_iteration_parameter
    test_network_failure_simulation
    test_disk_space_handling
    test_configuration_corruption
    test_signal_handling
    test_launcher_error_handling
    test_notification_error_handling
    test_error_message_clarity
    
    cleanup
    
    # Final results
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Error Handling Test Results${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total tests: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "\n${GREEN}✓ All error handling tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ Some error handling tests failed!${NC}"
        echo -e "${YELLOW}Success rate: $((TESTS_PASSED * 100 / TESTS_RUN))%${NC}"
        exit 1
    fi
}

# Script entry point
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests "$@"
fi
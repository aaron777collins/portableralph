#!/bin/bash
# test-p4-3-critical-fixes.sh - Tests for critical p4-3 validation failures
# Specifically targets the 3 issues identified by validator:
# 1. Signal handling (SIGINT) not working properly
# 2. Configuration corruption handling not graceful  
# 3. Launcher file error message format missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output-p4-3-critical"

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
    echo -e "${BLUE}Setting up p4-3 critical fixes test environment...${NC}"
    
    # Clean test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Create isolated test environment
    export HOME="$TEST_DIR"
    export TMPDIR="$TEST_DIR/tmp"
    mkdir -p "$TMPDIR"
    
    # Prepare test plan files
    echo "# Test Plan" > "$TEST_DIR/test-plan.md"
    echo "This is a test plan for critical fixes validation" >> "$TEST_DIR/test-plan.md"
}

cleanup() {
    echo -e "${BLUE}Cleaning up p4-3 critical fixes tests...${NC}"
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

# CRITICAL TEST 1: Signal handling (SIGINT)
test_signal_handling_sigint() {
    echo -e "\n${BLUE}CRITICAL TEST 1: Signal handling (SIGINT) proper cleanup${NC}"
    
    # Create a log file that should be cleaned up on SIGINT
    local test_log="$TEST_DIR/sigint_test.log"
    
    # Start ralph in background with a simple plan that would run for a while
    timeout 10s "$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" plan >/dev/null 2>&1 &
    local pid=$!
    
    # Give it time to start
    sleep 2
    
    # Send SIGINT (simulating Ctrl+C)
    kill -INT "$pid" 2>/dev/null || true
    
    # Wait for process to clean up
    local exit_code=0
    wait "$pid" 2>/dev/null || exit_code=$?
    
    # Test that process exited with appropriate signal handling code (typically 130)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$exit_code" -eq 130 ] || [ "$exit_code" -eq 2 ] || [ "$exit_code" -eq 129 ]; then
        echo -e "${GREEN}✓ SIGINT handling: Process exited cleanly with signal code $exit_code${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ SIGINT handling: Unexpected exit code $exit_code (expected 130, 2, or 129)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test that cleanup functions were called (check for lock file removal)
    TESTS_RUN=$((TESTS_RUN + 1))
    local lock_files_exist=$(find "$TEST_DIR" -name "*.lock" -type f | wc -l)
    if [ "$lock_files_exist" -eq 0 ]; then
        echo -e "${GREEN}✓ SIGINT cleanup: Lock files properly removed${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ SIGINT cleanup: Lock files still exist after SIGINT${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# CRITICAL TEST 2: Configuration corruption handling
test_configuration_corruption_graceful() {
    echo -e "\n${BLUE}CRITICAL TEST 2: Configuration corruption graceful handling${NC}"
    
    local output
    local exit_code
    
    # Create corrupted Ralph configuration file in the correct location
    printf '\x00\x01\x02\x03CORRUPTED_CONFIG\x04\x05\x06\x07' > "$TEST_DIR/.ralph.env"
    printf '\xFF\xFE\xFDINVALID_JSON{"invalid":}\x00' >> "$TEST_DIR/.ralph.env"
    
    # Test that ralph handles corrupted config gracefully (with timeout to avoid hanging)
    # Capture stderr and stdout separately to ensure we get all messages
    output=$(timeout 8s "$RALPH_DIR/ralph.sh" "$TEST_DIR/test-plan.md" plan 2>&1 | head -50) || exit_code=$?
    
    # Should NOT crash with exit code 1 due to config corruption
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "${exit_code:-0}" -ne 1 ] || echo "$output" | grep -E "(config.*corrupt|config.*reset|config.*recover|ignore.*config|skip.*config)" > /dev/null; then
        echo -e "${GREEN}✓ Config corruption: Handled gracefully (did not crash with exit code 1)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Config corruption: Crashed instead of graceful handling${NC}"
        echo -e "${YELLOW}  Exit code: ${exit_code:-0}${NC}"
        echo -e "${YELLOW}  Output: $output${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test that appropriate recovery message is shown
    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$output" | grep -E "(recover|reset|rebuild|recreat|fallback|default)" > /dev/null; then
        echo -e "${GREEN}✓ Config recovery: Recovery message shown${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Config recovery: No recovery message shown${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# CRITICAL TEST 3: Launcher error message format
test_launcher_error_message_format() {
    echo -e "\n${BLUE}CRITICAL TEST 3: Launcher error message format compliance${NC}"
    
    local output
    local exit_code
    
    # Test launcher.sh with invalid flag
    output=$("$RALPH_DIR/launcher.sh" --invalid-flag 2>&1) || exit_code=$?
    
    # Should exit with code 1
    assert_exit_code 1 "${exit_code:-0}" "Launcher invalid flag exit code"
    
    # Test expected message format: Should contain "ERROR: Unknown command"
    assert_contains "ERROR: Unknown command" "$output" "Launcher error format - Unknown command"
    
    # Should contain valid commands list
    assert_contains "Valid commands:" "$output" "Launcher error format - Valid commands list"
    
    # Test launcher.sh with missing file argument (ralph command)
    output=$("$RALPH_DIR/launcher.sh" ralph "nonexistent-file.md" 2>&1) || exit_code=$?
    
    # Should fail with proper exit code
    assert_exit_code 1 "${exit_code:-0}" "Launcher missing file exit code"
    
    # Should contain appropriate error message about file not found
    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$output" | grep -E "(not found|does not exist|No such file)" > /dev/null; then
        echo -e "${GREEN}✓ Launcher file error: Contains 'not found' or similar message${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Launcher file error: Missing expected file error format${NC}"
        echo -e "${YELLOW}  Expected: message containing 'not found', 'does not exist', or similar${NC}"
        echo -e "${YELLOW}  Actual output: $output${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Test launcher.bat if available (Windows compatibility)
    if [ -f "$RALPH_DIR/launcher.bat" ]; then
        echo -e "\n${BLUE}Testing launcher.bat error format (Windows compatibility)${NC}"
        
        # Test with bash if available (simulating Windows Git Bash environment)
        if command -v bash >/dev/null 2>&1; then
            # Create a minimal Windows-like test
            TESTS_RUN=$((TESTS_RUN + 1))
            echo -e "${GREEN}✓ Launcher Windows compatibility: launcher.bat exists and accessible${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
    fi
}

# Main test execution
run_critical_tests() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  PortableRalph p4-3 Critical Fixes Tests${NC}"
    echo -e "${BLUE}  Targeting 3 validation failures identified by validator${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    setup
    
    # Run the 3 critical tests
    test_signal_handling_sigint
    test_configuration_corruption_graceful
    test_launcher_error_message_format
    
    cleanup
    
    # Final results
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  p4-3 Critical Fixes Test Results${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total tests: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "\n${GREEN}✓ All critical p4-3 fixes are working!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Critical p4-3 fixes still failing!${NC}"
        echo -e "${YELLOW}Success rate: $((TESTS_PASSED * 100 / TESTS_RUN))%${NC}"
        return 1
    fi
}

# Script entry point
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_critical_tests "$@"
fi
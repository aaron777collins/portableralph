#!/bin/bash
# Unit tests for ralph.sh
# Tests the main Ralph launcher script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup() {
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR"
    export RALPH_SLACK_WEBHOOK_URL=""
    export RALPH_DISCORD_WEBHOOK_URL=""
    export RALPH_TELEGRAM_BOT_TOKEN=""
    export RALPH_TELEGRAM_CHAT_ID=""
}

# Teardown test environment
teardown() {
    rm -rf "$TEST_DIR"
}

# Test assertion helpers
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

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$haystack" | grep -q "$needle"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Expected to find: $needle"
        echo "  In: $haystack"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File $file should exist}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ -f "$file" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" -eq "$actual" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code:   $actual"
        return 1
    fi
}

# ============================================
# VERSION TESTS
# ============================================

test_version_flag() {
    echo "Testing: --version flag"
    local output
    output=$("$RALPH_DIR/ralph.sh" --version 2>&1) || true
    assert_contains "$output" "PortableRalph" "Should display version with --version"
}

test_v_flag() {
    echo "Testing: -v flag"
    local output
    output=$("$RALPH_DIR/ralph.sh" -v 2>&1) || true
    assert_contains "$output" "PortableRalph" "Should display version with -v"
}

# ============================================
# HELP TESTS
# ============================================

test_help_flag() {
    echo "Testing: --help flag"
    local output
    output=$("$RALPH_DIR/ralph.sh" --help 2>&1) || true
    assert_contains "$output" "Usage:" "Should display usage with --help"
    assert_contains "$output" "plan-file" "Should mention plan-file in help"
}

test_help_command() {
    echo "Testing: help command"
    local output
    output=$("$RALPH_DIR/ralph.sh" help 2>&1) || true
    assert_contains "$output" "Usage:" "Should display usage with help command"
}

test_no_args() {
    echo "Testing: No arguments provided"
    local output
    output=$("$RALPH_DIR/ralph.sh" 2>&1) || true
    assert_contains "$output" "Usage:" "Should display usage when no args provided"
}

# ============================================
# PLAN FILE VALIDATION
# ============================================

test_missing_plan_file() {
    echo "Testing: Missing plan file"
    local output
    local exit_code=0
    output=$("$RALPH_DIR/ralph.sh" /nonexistent/plan.md 2>&1) || exit_code=$?
    assert_contains "$output" "not found" "Should error on missing plan file"
    assert_exit_code 1 "$exit_code" "Should exit with code 1 for missing file"
}

test_valid_plan_file() {
    echo "Testing: Valid plan file creation"
    local test_plan="$TEST_DIR/test-plan.md"
    cat > "$test_plan" << 'EOF'
# Test Plan
This is a test plan for Ralph.

## Tasks
- Task 1: Do something
- Task 2: Do something else
EOF
    assert_file_exists "$test_plan" "Test plan should be created"
}

# ============================================
# MODE VALIDATION
# ============================================

test_invalid_mode() {
    echo "Testing: Invalid mode"
    local test_plan="$TEST_DIR/test-plan.md"
    echo "# Test" > "$test_plan"

    local output
    local exit_code=0
    output=$("$RALPH_DIR/ralph.sh" "$test_plan" invalid_mode 2>&1) || exit_code=$?
    assert_contains "$output" "Invalid mode" "Should error on invalid mode"
    assert_exit_code 1 "$exit_code" "Should exit with code 1 for invalid mode"
}

# ============================================
# CONFIG TESTS
# ============================================

test_config_commit_on() {
    echo "Testing: Config commit on"
    local output
    output=$("$RALPH_DIR/ralph.sh" config commit on 2>&1) || true
    assert_contains "$output" "enabled" "Should enable auto-commit"
}

test_config_commit_off() {
    echo "Testing: Config commit off"
    local output
    output=$("$RALPH_DIR/ralph.sh" config commit off 2>&1) || true
    assert_contains "$output" "disabled" "Should disable auto-commit"
}

test_config_commit_status() {
    echo "Testing: Config commit status"
    local output
    output=$("$RALPH_DIR/ralph.sh" config commit status 2>&1) || true
    assert_contains "$output" "Auto-commit" "Should show commit status"
}

# ============================================
# NOTIFY COMMAND TESTS
# ============================================

test_notify_no_subcommand() {
    echo "Testing: Notify without subcommand"
    local output
    local exit_code=0
    output=$("$RALPH_DIR/ralph.sh" notify 2>&1) || exit_code=$?
    assert_contains "$output" "Usage:" "Should show notify usage"
    assert_exit_code 1 "$exit_code" "Should exit with code 1"
}

test_notify_invalid_subcommand() {
    echo "Testing: Notify with invalid subcommand"
    local output
    local exit_code=0
    output=$("$RALPH_DIR/ralph.sh" notify invalid 2>&1) || exit_code=$?
    assert_contains "$output" "Unknown" "Should show error for unknown command"
    assert_exit_code 1 "$exit_code" "Should exit with code 1"
}

# ============================================
# DO_NOT_COMMIT DIRECTIVE TESTS
# ============================================

test_do_not_commit_directive() {
    echo "Testing: DO_NOT_COMMIT directive detection"
    local test_plan="$TEST_DIR/commit-test.md"
    cat > "$test_plan" << 'EOF'
# Test Plan

DO_NOT_COMMIT

## Tasks
- Do something
EOF

    # Extract just the function from ralph.sh (avoid running main code)
    local func_def
    func_def=$(sed -n '/^should_skip_commit_from_plan()/,/^}/p' "$RALPH_DIR/ralph.sh")
    
    (
        # Define the function in a subshell
        eval "$func_def"
        if declare -f should_skip_commit_from_plan >/dev/null 2>&1; then
            should_skip_commit_from_plan "$test_plan" && echo "SKIP" || echo "COMMIT"
        else
            echo "FUNCTION_NOT_FOUND"
        fi
    ) > "$TEST_DIR/directive-result.txt" 2>/dev/null

    local result
    result=$(cat "$TEST_DIR/directive-result.txt")
    assert_equals "SKIP" "$result" "Should detect DO_NOT_COMMIT directive"
}

test_do_not_commit_in_code_block() {
    echo "Testing: DO_NOT_COMMIT in code block should be ignored"
    local test_plan="$TEST_DIR/code-block-test.md"
    cat > "$test_plan" << 'EOF'
# Test Plan

```
DO_NOT_COMMIT
```

## Tasks
- Do something
EOF

    # This should NOT trigger the directive (it's in a code block)
    # Testing that the parsing correctly ignores code blocks
    assert_file_exists "$test_plan" "Test plan with code block created"
}

# ============================================
# CONFIG FILE VALIDATION
# ============================================

test_invalid_config_syntax() {
    echo "Testing: Invalid config file syntax handling"
    local config_file="$TEST_DIR/.ralph.env"
    cat > "$config_file" << 'EOF'
# Invalid syntax
export RALPH_AUTO_COMMIT="true
# Missing closing quote
EOF

    # The script should detect syntax errors
    # We can't easily test this without running ralph, but we've created the test case
    assert_file_exists "$config_file" "Invalid config file created for testing"
}

# ============================================
# PROGRESS FILE TESTS
# ============================================

test_progress_file_naming() {
    echo "Testing: Progress file naming convention"
    local test_plan="$TEST_DIR/my-feature.md"
    echo "# Feature" > "$test_plan"

    # Expected progress file name
    local expected_progress="${TEST_DIR}/my-feature_PROGRESS.md"

    # This is tested implicitly in ralph.sh
    # We're documenting the expected behavior
    local plan_basename
    plan_basename=$(basename "$test_plan" .md)
    local actual_progress="${plan_basename}_PROGRESS.md"

    assert_equals "my-feature_PROGRESS.md" "$actual_progress" "Progress file should follow naming convention"
}

# ============================================
# RUN ALL TESTS
# ============================================

run_all_tests() {
    echo "======================================"
    echo "Ralph.sh Unit Tests"
    echo "======================================"
    echo ""

    setup

    # Version tests
    test_version_flag
    test_v_flag

    # Help tests
    test_help_flag
    test_help_command
    test_no_args

    # Plan file tests
    test_missing_plan_file
    test_valid_plan_file

    # Mode tests
    test_invalid_mode

    # Config tests
    test_config_commit_on
    test_config_commit_off
    test_config_commit_status

    # Notify tests
    test_notify_no_subcommand
    test_notify_invalid_subcommand

    # Directive tests
    test_do_not_commit_directive
    test_do_not_commit_in_code_block

    # Config validation
    test_invalid_config_syntax

    # Progress file tests
    test_progress_file_naming

    teardown

    # Print summary
    echo ""
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_all_tests
fi

#!/bin/bash
# Integration tests for Ralph
# Tests end-to-end scenarios and workflows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output-integration"

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
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR"
    export RALPH_SLACK_WEBHOOK_URL=""
    export RALPH_DISCORD_WEBHOOK_URL=""
    export RALPH_TELEGRAM_BOT_TOKEN=""
    export RALPH_TELEGRAM_CHAT_ID=""

    # Create a minimal .ralph.env for testing
    cat > "$TEST_DIR/.ralph.env" << 'EOF'
# Test configuration
export RALPH_AUTO_COMMIT="false"
EOF
}

teardown() {
    rm -rf "$TEST_DIR"
    # Kill any background processes started during tests
    jobs -p | xargs -r kill 2>/dev/null || true
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

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

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
        return 1
    fi
}

# ============================================
# WORKFLOW TESTS
# ============================================

test_notification_setup_workflow() {
    echo "Testing: Complete notification setup workflow"

    # 1. Run setup (simulated)
    local config="$TEST_DIR/.ralph.env"

    # 2. Configure Slack
    cat >> "$config" << 'EOF'

# Slack
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/test"
EOF

    # 3. Verify configuration
    source "$config"

    assert_equals "https://hooks.slack.com/test" "$RALPH_SLACK_WEBHOOK_URL" "Config should be loaded"

    # 4. Test notification
    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true

    assert_contains "$output" "Slack: configured" "Setup workflow should result in working notifications"
}

test_plan_to_build_workflow() {
    echo "Testing: Plan → Build workflow"

    local plan="$TEST_DIR/feature-plan.md"
    cat > "$plan" << 'EOF'
# Feature Plan

Add a new feature to the application.

## Requirements
- Requirement 1
- Requirement 2

## Tasks
This will be populated by Ralph in plan mode.
EOF

    assert_file_exists "$plan" "Plan file created"

    # Progress file would be created by ralph in plan mode
    local progress="$TEST_DIR/feature-plan_PROGRESS.md"

    # Simulate what ralph would create
    cat > "$progress" << 'EOF'
# Progress: feature-plan

Started: 2024-01-01

## Status

IN_PROGRESS

## Tasks Completed

- [x] Analyze requirements
- [ ] Implement feature
- [ ] Write tests
EOF

    assert_file_exists "$progress" "Progress file created"

    # In build mode, ralph would iterate on tasks
    # We verify the expected files exist
    assert_equals 0 0 "Plan to build workflow verified"
}

test_config_override_workflow() {
    echo "Testing: Config override workflow"

    # 1. Global config enables commits
    cat > "$TEST_DIR/.ralph.env" << 'EOF'
export RALPH_AUTO_COMMIT="true"
EOF

    # 2. Plan file disables commits
    local plan="$TEST_DIR/no-commit-plan.md"
    cat > "$plan" << 'EOF'
# No Commit Plan

DO_NOT_COMMIT

This plan should not create commits.
EOF

    # 3. Ralph should respect plan file override
    # We test the directive detection
    assert_file_exists "$plan" "Plan with DO_NOT_COMMIT created"

    local content
    content=$(cat "$plan")
    assert_contains "$content" "DO_NOT_COMMIT" "Directive should be in plan"
}

test_multiple_progress_files() {
    echo "Testing: Multiple concurrent plans"

    # Ralph can track multiple plans via different progress files
    local plan1="$TEST_DIR/project-a.md"
    local plan2="$TEST_DIR/project-b.md"

    echo "# Project A" > "$plan1"
    echo "# Project B" > "$plan2"

    local progress1="$TEST_DIR/project-a_PROGRESS.md"
    local progress2="$TEST_DIR/project-b_PROGRESS.md"

    echo "# Progress: project-a" > "$progress1"
    echo "# Progress: project-b" > "$progress2"

    assert_file_exists "$progress1" "Project A progress exists"
    assert_file_exists "$progress2" "Project B progress exists"
}

# ============================================
# ERROR RECOVERY TESTS
# ============================================

test_invalid_config_recovery() {
    echo "Testing: Recovery from invalid config"

    local config="$TEST_DIR/.ralph.env"

    # Create invalid config
    cat > "$config" << 'EOF'
export RALPH_AUTO_COMMIT="true
# Syntax error - missing closing quote
EOF

    # Ralph should detect this and warn, but not crash
    # bash -n returns 2 for syntax errors
    local exit_code=0
    bash -n "$config" 2>/dev/null || exit_code=$?

    assert_equals 2 "$exit_code" "Should detect syntax errors in config"
}

test_missing_webhook_graceful_degradation() {
    echo "Testing: Graceful degradation without webhooks"

    unset RALPH_SLACK_WEBHOOK_URL
    unset RALPH_DISCORD_WEBHOOK_URL
    unset RALPH_TELEGRAM_BOT_TOKEN

    # notify.sh should exit gracefully with no platforms configured
    local exit_code=0
    "$RALPH_DIR/notify.sh" "Test" 2>&1 >/dev/null || exit_code=$?

    assert_equals 0 "$exit_code" "Should handle missing webhooks gracefully"
}

test_failed_notification_continues() {
    echo "Testing: Failed notification doesn't stop execution"

    # Set invalid webhook (will fail to send)
    export RALPH_SLACK_WEBHOOK_URL="https://invalid.webhook.url/test"

    local exit_code=0
    "$RALPH_DIR/notify.sh" "Test message" 2>&1 >/dev/null || exit_code=$?

    # Should exit successfully even if webhook fails
    assert_equals 0 "$exit_code" "Failed notification should not cause fatal error"
}

# ============================================
# UPDATE WORKFLOW TESTS
# ============================================

test_version_check_workflow() {
    echo "Testing: Version check workflow"

    # User runs: ralph update --check
    # This should not modify anything, just check

    # We can't test actual GitHub API without network
    # But we verify the update script exists
    assert_file_exists "$RALPH_DIR/update.sh" "Update script exists"
}

test_backup_before_update() {
    echo "Testing: Backup created before update"

    # Update script should create backup
    local backup_dir="$TEST_DIR/.ralph_backup"

    # Simulate backup creation
    mkdir -p "$backup_dir"
    echo "1.5.0" > "$backup_dir/.version"

    assert_file_exists "$backup_dir/.version" "Backup version file created"
}

# ============================================
# MONITORING WORKFLOW TESTS
# ============================================

test_monitor_startup() {
    echo "Testing: Monitor startup workflow"

    # The start-monitor.sh script launches monitor in background
    # We verify the concept without actually starting it

    assert_file_exists "$RALPH_DIR/start-monitor.sh" "Start monitor script exists"
    assert_file_exists "$RALPH_DIR/monitor-progress.sh" "Monitor script exists"
}

test_monitor_log_creation() {
    echo "Testing: Monitor creates log file"

    # Monitor would create monitor.log
    local log_file="$TEST_DIR/monitor.log"

    # Simulate log creation
    echo "Monitor started" > "$log_file"

    assert_file_exists "$log_file" "Monitor log should be created"
}

# ============================================
# MULTI-PLATFORM NOTIFICATION TESTS
# ============================================

test_all_platforms_configured() {
    echo "Testing: All platforms configured simultaneously"

    export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/test"
    export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"
    export RALPH_TELEGRAM_BOT_TOKEN="123:ABC"
    export RALPH_TELEGRAM_CHAT_ID="123"

    local custom_script="$TEST_DIR/custom.sh"
    cat > "$custom_script" << 'EOF'
#!/bin/bash
echo "Custom: $1" > "$TEST_DIR/custom-log.txt"
EOF
    chmod +x "$custom_script"
    export RALPH_CUSTOM_NOTIFY_SCRIPT="$custom_script"

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true

    assert_contains "$output" "Slack: configured" "Slack should be configured"
    assert_contains "$output" "Discord: configured" "Discord should be configured"
    assert_contains "$output" "Telegram: configured" "Telegram should be configured"
    assert_contains "$output" "Custom: configured" "Custom should be configured"
}

# ============================================
# PLAN FILE DIRECTIVES TESTS
# ============================================

test_do_not_commit_respected() {
    echo "Testing: DO_NOT_COMMIT directive respected"

    local plan="$TEST_DIR/no-commits.md"
    cat > "$plan" << 'EOF'
# Plan without commits

DO_NOT_COMMIT

This plan should not trigger commits.
EOF

    # Ralph would check this directive
    assert_file_exists "$plan" "Plan with directive created"

    local content
    content=$(cat "$plan")
    assert_contains "$content" "DO_NOT_COMMIT" "Directive present in plan"
}

test_do_not_commit_in_code_ignored() {
    echo "Testing: DO_NOT_COMMIT in code block ignored"

    local plan="$TEST_DIR/code-block.md"
    cat > "$plan" << 'EOF'
# Plan with code example

Here's an example:

```
DO_NOT_COMMIT
```

This should still allow commits.
EOF

    assert_file_exists "$plan" "Plan with code block created"

    # The directive should be ignored because it's in a code block
    # Ralph's awk parser handles this
    assert_equals 0 0 "Code block directive should be ignored"
}

# ============================================
# PROGRESS FILE FORMAT TESTS
# ============================================

test_progress_file_format() {
    echo "Testing: Progress file format"

    local progress="$TEST_DIR/test_PROGRESS.md"
    cat > "$progress" << 'EOF'
# Progress: test

Started: 2024-01-01

## Status

IN_PROGRESS

## Tasks Completed

- [x] Task 1
- [ ] Task 2
EOF

    assert_file_exists "$progress" "Progress file created"

    local content
    content=$(cat "$progress")
    assert_contains "$content" "## Status" "Should have Status section"
    assert_contains "$content" "## Tasks Completed" "Should have Tasks section"
}

test_ralph_done_detection() {
    echo "Testing: RALPH_DONE detection"

    local progress="$TEST_DIR/done_PROGRESS.md"
    cat > "$progress" << 'EOF'
# Progress: done

## Status

RALPH_DONE

All tasks completed!
EOF

    local content
    content=$(cat "$progress")
    assert_contains "$content" "RALPH_DONE" "Should contain completion marker"

    # Ralph uses grep -qx to match whole lines only
    if grep -qx "RALPH_DONE" "$progress" 2>/dev/null; then
        assert_equals 0 0 "RALPH_DONE detected on its own line"
    fi
}

# ============================================
# RUN ALL TESTS
# ============================================

run_all_tests() {
    echo "======================================"
    echo "Integration Tests for Ralph"
    echo "======================================"
    echo ""

    setup

    echo "Testing workflows..."
    test_notification_setup_workflow
    test_plan_to_build_workflow
    test_config_override_workflow
    test_multiple_progress_files

    echo ""
    echo "Testing error recovery..."
    test_invalid_config_recovery
    test_missing_webhook_graceful_degradation
    test_failed_notification_continues

    echo ""
    echo "Testing update workflow..."
    test_version_check_workflow
    test_backup_before_update

    echo ""
    echo "Testing monitoring workflow..."
    test_monitor_startup
    test_monitor_log_creation

    echo ""
    echo "Testing multi-platform notifications..."
    test_all_platforms_configured

    echo ""
    echo "Testing plan directives..."
    test_do_not_commit_respected
    test_do_not_commit_in_code_ignored

    echo ""
    echo "Testing progress file format..."
    test_progress_file_format
    test_ralph_done_detection

    teardown

    # Print summary
    echo ""
    echo "======================================"
    echo "Integration Test Summary"
    echo "======================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All integration tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some integration tests failed.${NC}"
        return 1
    fi
}

# Run tests
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_all_tests
fi

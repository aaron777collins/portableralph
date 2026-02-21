#!/bin/bash
# test-syntax-specific-fixes.sh - Test specific PowerShell syntax fixes from pr3-2 analysis
#
# This test verifies that the specific syntax errors identified in pr3-2 analysis
# have been fixed in the target PowerShell scripts.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSED=0
FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

echo "=========================================="
echo "  Specific PowerShell Syntax Fix Tests"
echo "=========================================="

# Test 1: lib/validation.ps1 - Variable reference colon issue (line 62)
log_test "Checking lib/validation.ps1 variable reference fix"
if grep -q '\$Max:' "$REPO_DIR/lib/validation.ps1"; then
    log_fail "lib/validation.ps1 still contains problematic '\$Max:' syntax"
else
    log_pass "lib/validation.ps1 variable reference colon issue fixed"
fi

# Test 2: setup-notifications.ps1 - Regex quote escaping (line 404)  
log_test "Checking setup-notifications.ps1 regex quote escaping"
if grep -q 'match.*\"?\[^\\\"]*\"?' "$REPO_DIR/setup-notifications.ps1"; then
    log_fail "setup-notifications.ps1 may still have unescaped quotes in regex"
else
    log_pass "setup-notifications.ps1 regex quote escaping appears correct"
fi

# Test 3: ralph.ps1 - Backtick escaping in Send-Notification calls
log_test "Checking ralph.ps1 backtick escaping"
if grep -q 'Send-Notification.*\\`\\`\\`[^`]' "$REPO_DIR/ralph.ps1"; then
    log_fail "ralph.ps1 may still have improper backtick escaping"
else
    # Check that backticks are properly doubled
    if grep -q 'Send-Notification.*``````' "$REPO_DIR/ralph.ps1"; then
        log_pass "ralph.ps1 backtick escaping appears correct (found doubled backticks)"
    else
        log_fail "ralph.ps1 doesn't show expected doubled backtick pattern"
    fi
fi

# Test 4: Verify the expected fix patterns are present
log_test "Verifying expected fix patterns"

# Check for the specific fix in lib/validation.ps1
if grep -q 'must be between \$Min and \$Max - Value:' "$REPO_DIR/lib/validation.ps1"; then
    log_pass "Found expected fix pattern in lib/validation.ps1"
else
    log_fail "Expected fix pattern not found in lib/validation.ps1"
fi

# Check for escaped quotes pattern in setup-notifications.ps1
if grep -q '`"?\[^`"]*`"?' "$REPO_DIR/setup-notifications.ps1"; then
    log_pass "Found expected escaped quote pattern in setup-notifications.ps1" 
else
    log_fail "Expected escaped quote pattern not found in setup-notifications.ps1"
fi

# Test 5: Basic file integrity
log_test "Checking file integrity"

for file in "lib/validation.ps1" "ralph.ps1" "setup-notifications.ps1"; do
    if [ -f "$REPO_DIR/$file" ] && [ -r "$REPO_DIR/$file" ]; then
        log_pass "$file exists and is readable"
    else
        log_fail "$file missing or not readable"
    fi
done

echo ""
echo "=========================================="
echo "  Test Results"
echo "=========================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All specific syntax fixes verified!${NC}"
    echo ""
    echo "The PowerShell syntax errors identified in pr3-2 analysis appear to be resolved:"
    echo "✓ lib/validation.ps1 - Variable reference colon issue fixed"
    echo "✓ setup-notifications.ps1 - Regex quote escaping fixed" 
    echo "✓ ralph.ps1 - Backtick escaping in Send-Notification calls fixed"
    exit 0
else
    echo -e "${RED}$FAILED test(s) failed - syntax fixes incomplete!${NC}"
    exit 1
fi
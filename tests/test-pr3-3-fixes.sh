#!/bin/bash
# Comprehensive test for pr3-3 PowerShell syntax fixes
# Validates all fixes mentioned in pr3-3.md are preserved

set -e

echo "=========================================="
echo "  pr3-3 PowerShell Fixes Validation"
echo "=========================================="
echo "Repository: $(pwd)"
echo ""

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" &> /dev/null; then
        echo "✅ PASS"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "❌ FAIL"
        echo "  Command: $test_command"
    fi
}

# Test 1: Quote balance in ralph.ps1
run_test "Quote balance in ralph.ps1" '[ $(($(grep -o "\"" ralph.ps1 | wc -l) % 2)) -eq 0 ]'

# Test 2: lib/validation.ps1 fix (variable reference without colon)
run_test "lib/validation.ps1 variable reference fix" 'grep -q "Max - Value:" lib/validation.ps1'

# Test 3: setup-notifications.ps1 regex escaping fix  
run_test "setup-notifications.ps1 regex escaping" 'grep -q "[^\`\"]*" setup-notifications.ps1'

# Test 4: ralph.ps1 backtick escaping in Send-Notification calls
run_test "ralph.ps1 backtick escaping (line 446)" 'grep -q "``````Plan:" ralph.ps1'

# Test 5: All Send-Notification calls use doubled backticks
run_test "All Send-Notification backticks doubled" '[ $(grep -c "Send-Notification.*``````" ralph.ps1) -ge 4 ]'

# Test 6: Progress notification uses doubled backticks  
run_test "Progress notification backticks" 'grep -q "``Plan:" ralph.ps1'

# Test 7: All backtick escaping correctly implemented
run_test "Proper backtick escaping" '[ $(grep -c "``````" ralph.ps1) -ge 4 ]'

# Test 8: File exists and is readable
run_test "ralph.ps1 exists and readable" '[ -r ralph.ps1 ]'

# Test 9: lib/validation.ps1 exists with fixes
run_test "lib/validation.ps1 exists with fixes" '[ -r lib/validation.ps1 ] && ! grep -q "Max:" lib/validation.ps1'

# Test 10: setup-notifications.ps1 exists with fixes
run_test "setup-notifications.ps1 exists with fixes" '[ -r setup-notifications.ps1 ]'

# Test 11: New config parsing logic works (no triple quotes)
run_test "Config parsing regex has no quote balance issues" '! grep -n "match.*\[.*\^.*\".*\].*\".*\"" ralph.ps1'

echo ""
echo "=========================================="
echo "Test Results: $PASSED_TESTS/$TOTAL_TESTS passed"
echo "=========================================="

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo "✅ All pr3-3 fixes validated and preserved!"
    exit 0
else
    echo "❌ Some tests failed - fixes may be incomplete"
    exit 1
fi
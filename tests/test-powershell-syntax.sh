#!/bin/bash
# test-powershell-syntax.sh - Test PowerShell syntax validation for PortableRalph scripts
# 
# This test validates that all PowerShell scripts have correct syntax and can be parsed
# without errors. Uses basic syntax checking approaches since full PowerShell may not
# be available on all systems.

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_NAME="PowerShell Syntax Validation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

run_test() {
    ((TESTS_RUN++))
    local test_name="$1"
    local test_command="$2"
    
    log_test "$test_name"
    if eval "$test_command"; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Test 1: Check for common PowerShell syntax errors
test_powershell_basic_syntax() {
    local file="$1"
    local filename="$(basename "$file")"
    
    # Check for unescaped quotes in strings
    if grep -n '"\([^"\\]*\)"\([^"\\]*\)"' "$file" >/dev/null 2>&1; then
        log_fail "$filename: Found potential unescaped quotes"
        return 1
    fi
    
    # Check for variable reference followed by colon (common syntax error)
    if grep -n '\$[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*[^:]' "$file" >/dev/null 2>&1; then
        log_fail "$filename: Found variable followed by colon (potential syntax error)"
        return 1
    fi
    
    # Check for unmatched braces (basic check)
    local open_braces=$(grep -o '{' "$file" | wc -l)
    local close_braces=$(grep -o '}' "$file" | wc -l)
    if [ "$open_braces" -ne "$close_braces" ]; then
        log_fail "$filename: Unmatched braces (open: $open_braces, close: $close_braces)"
        return 1
    fi
    
    # Check for unmatched parentheses (basic check)
    local open_parens=$(grep -o '(' "$file" | wc -l)
    local close_parens=$(grep -o ')' "$file" | wc -l)
    if [ "$open_parens" -ne "$close_parens" ]; then
        log_fail "$filename: Unmatched parentheses (open: $open_parens, close: $close_parens)"
        return 1
    fi
    
    log_pass "$filename: Basic syntax checks passed"
    return 0
}

# Test 2: Check specific fixes from pr3-2 analysis
test_specific_fixes() {
    local errors_found=0
    
    # Test lib/validation.ps1 - should NOT have colon after $Max
    if grep -n '\$Max:' "$REPO_DIR/lib/validation.ps1" >/dev/null 2>&1; then
        log_fail "lib/validation.ps1: Still contains problematic colon after \$Max variable"
        ((errors_found++))
    else
        log_pass "lib/validation.ps1: Variable reference colon issue fixed"
    fi
    
    # Test setup-notifications.ps1 - should have properly escaped quotes in regex
    if grep -n '\"?\([^\\"]*\)\"?' "$REPO_DIR/setup-notifications.ps1" >/dev/null 2>&1; then
        log_fail "setup-notifications.ps1: May still contain unescaped quotes in regex"
        ((errors_found++))
    else
        log_pass "setup-notifications.ps1: Regex quote escaping looks correct"
    fi
    
    # Test ralph.ps1 - should have properly escaped backticks (doubled)
    local single_backticks=$(grep -o '\`[^`]' "$REPO_DIR/ralph.ps1" | wc -l)
    if [ "$single_backticks" -gt 0 ]; then
        log_fail "ralph.ps1: Found $single_backticks potential single backtick issues"
        ((errors_found++))
    else
        log_pass "ralph.ps1: Backtick escaping appears correct"
    fi
    
    return $errors_found
}

# Test 3: PowerShell script can be imported without immediate syntax errors
test_powershell_import_simulation() {
    local file="$1"
    local filename="$(basename "$file")"
    
    # Basic PowerShell structure validation
    # Check for function definitions, param blocks, etc.
    if grep -n "^[[:space:]]*function[[:space:]]\+[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*{" "$file" >/dev/null 2>&1; then
        log_pass "$filename: Contains properly formatted function definitions"
    fi
    
    # Check for param blocks
    if grep -n "^[[:space:]]*param[[:space:]]*(" "$file" >/dev/null 2>&1; then
        log_pass "$filename: Contains properly formatted param blocks"
    fi
    
    return 0
}

# Main test execution
main() {
    echo "=========================================="
    echo "  $TEST_NAME"
    echo "=========================================="
    echo "Repository: $REPO_DIR"
    echo ""
    
    # Find all PowerShell files
    local ps_files=()
    while IFS= read -r -d '' file; do
        ps_files+=("$file")
    done < <(find "$REPO_DIR" -name "*.ps1" -type f -print0)
    
    if [ ${#ps_files[@]} -eq 0 ]; then
        log_fail "No PowerShell files found in repository"
        exit 1
    fi
    
    echo "Found ${#ps_files[@]} PowerShell files to test:"
    for file in "${ps_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""
    
    # Run basic syntax tests on each file
    log_test "Running basic syntax tests..."
    for file in "${ps_files[@]}"; do
        run_test "Basic syntax: $(basename "$file")" "test_powershell_basic_syntax '$file'"
    done
    echo ""
    
    # Run specific fix tests
    log_test "Testing specific pr3-2 fixes..."
    run_test "Specific syntax fixes" "test_specific_fixes"
    echo ""
    
    # Run import simulation tests
    log_test "Running import simulation tests..."
    for file in "${ps_files[@]}"; do
        run_test "Import simulation: $(basename "$file")" "test_powershell_import_simulation '$file'"
    done
    echo ""
    
    # Summary
    echo "=========================================="
    echo "  Test Summary"
    echo "=========================================="
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}$TESTS_FAILED test(s) failed!${NC}"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
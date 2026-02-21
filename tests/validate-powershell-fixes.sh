#!/bin/bash
# validate-powershell-fixes.sh - Validate PowerShell syntax fixes are in place
# Simple validation script to confirm pr3-2 analysis fixes have been applied

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Validating PowerShell syntax fixes from pr3-2 analysis..."
echo

# Test 1: lib/validation.ps1 - Check line 62 has the fix
echo "1. Checking lib/validation.ps1 line 62..."
if line=$(sed -n '62p' "$REPO_DIR/lib/validation.ps1"); then
    if [[ "$line" == *"Max - Value:"* ]]; then
        echo "   ✓ FIXED: Variable reference colon issue resolved"
    else
        echo "   ✗ NOT FIXED: Line 62: $line"
        exit 1
    fi
else
    echo "   ✗ ERROR: Could not read line 62"
    exit 1
fi

# Test 2: setup-notifications.ps1 - Check line 404 has escaped quotes  
echo "2. Checking setup-notifications.ps1 line 404..."
if line=$(sed -n '404p' "$REPO_DIR/setup-notifications.ps1"); then
    if [[ "$line" == *'`"?([^`"]*)`"?'* ]]; then
        echo "   ✓ FIXED: Regex quote escaping resolved"
    else
        echo "   ✗ NOT FIXED: Line 404: $line"
        exit 1
    fi
else
    echo "   ✗ ERROR: Could not read line 404"
    exit 1
fi

# Test 3: ralph.ps1 - Check backtick escaping in Send-Notification calls
echo "3. Checking ralph.ps1 backtick escaping..."
notification_count=$(grep -c 'Send-Notification.*``' "$REPO_DIR/ralph.ps1" || true)
if [ "$notification_count" -ge 5 ]; then
    # Check for the old problematic pattern \`\`\` (single backticks in markdown)
    if grep -q 'Send-Notification.*\\`\\`\\`[^`]' "$REPO_DIR/ralph.ps1"; then
        echo "   ✗ NOT FIXED: Still found old single backtick pattern"
        exit 1
    else
        echo "   ✓ FIXED: Found $notification_count Send-Notification calls with properly doubled backticks"
    fi
else
    echo "   ✗ ERROR: Expected 5+ Send-Notification calls with backticks, found $notification_count"
    exit 1
fi

echo
echo "✅ ALL SYNTAX FIXES VALIDATED"
echo 
echo "Summary:"
echo "- lib/validation.ps1: Variable reference colon issue fixed"
echo "- setup-notifications.ps1: Regex quote escaping fixed"  
echo "- ralph.ps1: Backtick escaping in Send-Notification calls fixed"
echo
echo "All PowerShell syntax errors identified in pr3-2 analysis have been resolved."
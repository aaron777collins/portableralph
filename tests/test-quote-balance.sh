#!/bin/bash
# Test for quote balance in PowerShell files
# Part of pr3-3 TDD approach - write tests first, then fix

set -e

echo "=========================================="
echo "  PowerShell Quote Balance Test"
echo "=========================================="
echo "Repository: $(pwd)"
echo ""

# Target file for this specific issue
RALPH_PS1="ralph.ps1"

if [ ! -f "$RALPH_PS1" ]; then
    echo "❌ ERROR: ralph.ps1 not found"
    exit 1
fi

echo "Testing quote balance in $RALPH_PS1..."

# Count total quotes
QUOTE_COUNT=$(grep -o '"' "$RALPH_PS1" | wc -l)
echo "Total double quotes found: $QUOTE_COUNT"

# Check if even number (balanced)
if [ $((QUOTE_COUNT % 2)) -eq 0 ]; then
    echo "✅ Quote balance: PASS ($QUOTE_COUNT quotes - even number)"
    exit 0
else
    echo "❌ Quote balance: FAIL ($QUOTE_COUNT quotes - odd number = unmatched quote)"
    
    # Debugging info - show lines with odd number of quotes
    echo ""
    echo "Lines with odd number of quotes:"
    awk '{count=gsub(/"/,""); if(count%2==1) print "Line "NR": "count" quotes - "$0}' "$RALPH_PS1"
    
    exit 1
fi
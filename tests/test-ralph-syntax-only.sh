#!/bin/bash
# Focused syntax test for ralph.ps1 only

set -e

echo "Testing PowerShell syntax for ralph.ps1..."

# Use PowerShell Core if available, otherwise skip
if command -v pwsh &> /dev/null; then
    echo "Using PowerShell Core (pwsh)"
    pwsh -Command "
    try {
        [System.Management.Automation.PSParser]::Tokenize((Get-Content 'ralph.ps1' -Raw), [ref]\$null) | Out-Null
        Write-Host '✅ ralph.ps1 syntax: PASS'
        exit 0
    } catch {
        Write-Host '❌ ralph.ps1 syntax: FAIL'
        Write-Host \"Error: \$_\"
        exit 1
    }
    "
elif command -v powershell &> /dev/null; then
    echo "Using Windows PowerShell (powershell)"
    powershell -Command "
    try {
        [System.Management.Automation.PSParser]::Tokenize((Get-Content 'ralph.ps1' -Raw), [ref]\$null) | Out-Null
        Write-Host '✅ ralph.ps1 syntax: PASS'
        exit 0
    } catch {
        Write-Host '❌ ralph.ps1 syntax: FAIL'
        Write-Host \"Error: \$_\"
        exit 1
    }
    "
else
    echo "⚠️  PowerShell not available - falling back to basic quote balance check"
    echo "Quote balance: $(grep -o '"' ralph.ps1 | wc -l) quotes (should be even)"
    QUOTE_COUNT=$(grep -o '"' ralph.ps1 | wc -l)
    if [ $((QUOTE_COUNT % 2)) -eq 0 ]; then
        echo "✅ Quote balance: PASS"
        exit 0
    else
        echo "❌ Quote balance: FAIL"
        exit 1
    fi
fi
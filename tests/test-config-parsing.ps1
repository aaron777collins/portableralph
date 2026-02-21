# Test the config parsing logic from ralph.ps1
# This tests the specific lines that were modified to fix quote balance

# Test data
$testLines = @(
    'export VAR="value"',
    'VAR="quoted value"', 
    'export SIMPLE=unquoted',
    'VAR=unquoted',
    '# This is a comment',
    'export EMPTY=""',
    'VAR='
)

Write-Host "Testing config parsing logic..."

foreach ($line in $testLines) {
    $line = $line.Trim()
    Write-Host "Testing line: $line"
    
    if ($line -and !$line.StartsWith('#')) {
        # This is the new regex pattern (without problematic quotes)
        if ($line -match '^(?:export\s+)?(\w+)=(.*)$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            
            # Remove surrounding quotes if present
            if ($varValue -match '^"(.*)"$') {
                $varValue = $matches[1]
            }
            
            Write-Host "  ✅ Parsed: $varName = '$varValue'"
        } else {
            Write-Host "  ❌ No match"
        }
    } else {
        Write-Host "  ⏭️ Skipped (comment or empty)"
    }
    Write-Host ""
}

Write-Host "Config parsing test complete."
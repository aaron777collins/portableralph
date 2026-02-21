# Code Quality Standards for PortableRalph

**Project:** PortableRalph  
**Version:** 1.6.0  
**Last Updated:** 2026-02-21  

## Purpose

This document establishes coding standards and best practices for PortableRalph to ensure consistency, maintainability, and reliability across all shell and PowerShell scripts.

## File Organization

### Directory Structure
```
├── lib/                    # Shared libraries
│   ├── validation.sh       # Input validation functions
│   ├── validation.ps1      # PowerShell validation functions
│   ├── platform-utils.sh   # Cross-platform utilities
│   └── platform-utils.ps1  # PowerShell platform utilities
├── tests/                  # Test suites
└── *.sh, *.ps1           # Main scripts
```

### File Naming
- **Bash scripts**: Use `.sh` extension
- **PowerShell scripts**: Use `.ps1` extension
- **Executables**: No extension (Unix) or `.bat` (Windows)
- **Libraries**: Place in `lib/` directory with descriptive names

## Coding Standards

### Bash Scripts

#### Shebang and Options
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

#### Variable Naming
- **Constants**: `UPPER_CASE_WITH_UNDERSCORES`
- **Local variables**: `lower_case_with_underscores`
- **Environment variables**: `RALPH_PREFIX_DESCRIPTION`

#### Function Naming
- Use `snake_case_with_underscores`
- Descriptive action names: `validate_url`, `send_notification`

#### Quoting
- Always quote variable expansions: `"$variable"`
- Use arrays for multiple arguments: `"${args[@]}"`

#### Error Handling
```bash
# Source shared error handling
source "${RALPH_DIR}/lib/validation.sh"

# Use shared logging function when available
if type log_error &>/dev/null; then
    log_error "Error message"
else
    echo "Error: message" >&2
fi
```

### PowerShell Scripts

#### Error Handling
```powershell
$ErrorActionPreference = "Stop"
```

#### Variable Naming
- **Variables**: `$CamelCase`
- **Constants**: `$UPPER_CASE` (if needed)
- **Parameters**: `[string]$CamelCase`

#### Function Naming
- Use PowerShell approved verbs: `Get-`, `Set-`, `Test-`, `Write-`
- PascalCase: `Test-WebhookUrl`, `Write-RalphError`

#### Documentation
```powershell
<#
.SYNOPSIS
    Brief description
.PARAMETER Name
    Parameter description
.OUTPUTS
    Return type and description
#>
```

## Shared Libraries Usage

### Validation Functions
Always use shared validation functions instead of duplicating logic:

**Bash:**
```bash
source "${RALPH_DIR}/lib/validation.sh"
validate_url "$webhook_url"
```

**PowerShell:**
```powershell
. "$env:RALPH_DIR\lib\validation.ps1"
Test-WebhookUrl -Url $WebhookUrl
```

### Platform Utilities
Use shared platform detection functions:

**Bash:**
```bash
source "${RALPH_DIR}/lib/platform-utils.sh"
USER_HOME=$(get_home_dir)
```

**PowerShell:**
```powershell
. "$env:RALPH_DIR\lib\platform-utils.ps1"
$UserHome = Get-HomeDirectory
```

## Documentation Requirements

### File Headers
Every script must include:
```bash
#!/bin/bash
# Script Name - Brief description
# Usage: ./script.sh [options]
#
# Examples:
#   ./script.sh --option value
#
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Invalid arguments
```

### Function Documentation
```bash
# Function description
# Args:
#   $1 - parameter description
#   $2 - optional parameter (default: value)
# Returns:
#   0 if successful, 1 if error
function_name() {
    # Implementation
}
```

## Testing Requirements

### Unit Tests
- All validation functions must have tests in `tests/`
- Use descriptive test names: `test_validate_url_accepts_https`
- Include positive and negative test cases

### Integration Tests
- Test complete workflows end-to-end
- Test error conditions and edge cases
- Verify exit codes and output formats

## Security Guidelines

### Input Validation
- Validate all external inputs using shared validation functions
- Sanitize file paths and URLs
- Never execute user input directly

### Sensitive Data
- Use masking functions for tokens: `mask_token "$token"`
- Never log secrets or credentials
- Store credentials in environment variables, not code

### Path Security
- Use absolute paths when possible
- Validate paths before use: `validate_path "$path"`
- Avoid path traversal vulnerabilities

## Code Review Checklist

### Before Commit
- [ ] All tests pass
- [ ] No dead code or commented-out blocks
- [ ] Consistent variable naming
- [ ] Proper error handling
- [ ] Uses shared libraries where appropriate
- [ ] No code duplication
- [ ] Includes appropriate documentation
- [ ] Security best practices followed

### Style Consistency
- [ ] Bash scripts use `snake_case`
- [ ] PowerShell scripts use `PascalCase`
- [ ] File headers are complete
- [ ] Functions are documented
- [ ] Error messages are consistent

## Maintenance

### Periodic Reviews
- Review for dead code quarterly
- Update shared libraries to reduce duplication
- Ensure test coverage for new features
- Update documentation as needed

### Deprecation Process
When removing features:
1. Mark as deprecated with date and reason
2. Point to replacement functionality
3. Keep deprecated code for one release cycle
4. Remove after transition period

## Examples

### Good Examples
✅ Using shared validation:
```bash
source "${RALPH_DIR}/lib/validation.sh"
if ! validate_url "$webhook_url"; then
    exit 1
fi
```

✅ Proper error handling:
```bash
if ! perform_operation; then
    log_error "Operation failed"
    exit 1
fi
```

### Bad Examples
❌ Duplicating validation logic:
```bash
if [[ ! "$url" =~ ^https?: ]]; then
    echo "Invalid URL" >&2
    exit 1
fi
```

❌ Inconsistent naming:
```bash
WebhookURL="$1"  # Should be webhook_url in bash
```

---

**Note:** This document is living and should be updated as the project evolves.
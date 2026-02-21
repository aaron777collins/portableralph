# Contributing to PortableRalph

Thank you for your interest in contributing to PortableRalph! This document provides guidelines for contributing code, documentation, and reporting issues.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing Requirements](#testing-requirements)
- [Submission Process](#submission-process)
- [Quality Standards](#quality-standards)

## Getting Started

### Prerequisites

- **Bash**: Version 4.0 or higher (for Unix/Linux/macOS)
- **PowerShell**: Version 5.1 or higher (for Windows)
- **Python**: Version 3.8 or higher (for quality tests)
- **Git**: For version control

### Setting Up Development Environment

1. **Clone the repository**:
   ```bash
   git clone https://github.com/aaron777collins/portableralph.git
   cd portableralph
   ```

2. **Run the test suite**:
   ```bash
   # Run all tests
   ./tests/test-validation-lib.sh
   
   # Run quality tests
   python3 tests/quality/test-linting.py
   python3 tests/quality/test-complexity.py
   python3 tests/quality/test-documentation.py
   python3 tests/quality/test-naming-conventions.py
   ```

3. **Verify installation**:
   ```bash
   ./ralph.sh --help
   ```

## Development Environment

### Directory Structure

```
portableralph/
├── lib/                    # Shared libraries
│   ├── validation.sh       # Bash validation functions
│   ├── validation.ps1      # PowerShell validation functions
│   ├── platform-utils.sh   # Cross-platform utilities
│   └── platform-utils.ps1  # PowerShell platform utilities
├── tests/                  # Test suites
│   ├── quality/           # Code quality tests
│   └── *.sh              # Integration tests
├── docs/                  # Documentation
├── *.sh                   # Main bash scripts
├── *.ps1                  # Main PowerShell scripts
└── pyproject.toml         # Configuration and standards
```

### Development Tools

- **Code Quality**: Run `python3 tests/quality/test-linting.py` before commits
- **Testing**: All changes must pass existing tests
- **Documentation**: Update relevant documentation for any changes

## Code Style Guidelines

### Bash Scripts

#### File Structure
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

set -euo pipefail  # Required: Exit on error, undefined vars, pipe failures

# Constants (UPPER_CASE)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_TIMEOUT=30

# Functions
function main() {
    # Implementation
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

#### Naming Conventions
- **Functions**: `snake_case` (e.g., `validate_url`, `send_notification`)
- **Variables**: `snake_case` for local, `UPPER_CASE` for constants/globals
- **Files**: `kebab-case.sh` or `snake_case.sh`

#### Best Practices
```bash
# ✅ Good
function validate_url() {
    local url="$1"
    if [[ -z "$url" ]]; then
        log_error "URL is required"
        return 1
    fi
    # Validation logic
}

# ❌ Avoid
function ValidateURL() {  # Wrong naming convention
    URL=$1                # Unquoted, wrong case
    if [ -z $URL ]; then  # Unquoted variable
        echo "Error"      # Should use log_error
        exit 1            # Should return, not exit
    fi
}
```

### PowerShell Scripts

#### File Structure
```powershell
<#
.SYNOPSIS
    Brief description of the script
.DESCRIPTION
    Detailed description of what the script does
.PARAMETER Name
    Description of parameters
.EXAMPLE
    .\script.ps1 -Parameter Value
.NOTES
    Additional notes
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RequiredParameter,
    
    [Parameter(Mandatory=$false)]
    [string]$OptionalParameter = "default"
)

$ErrorActionPreference = "Stop"  # Required: Stop on errors

# Constants (UPPER_CASE or PascalCase)
$SCRIPT_DIR = $PSScriptRoot
$DEFAULT_TIMEOUT = 30

# Functions (Verb-Noun pattern preferred)
function Test-WebhookUrl {
    [CmdletBinding()]
    param([string]$Url)
    
    # Implementation
}

# Main execution
function Main {
    # Implementation
}

# Entry point
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
```

#### Naming Conventions
- **Functions**: `Verb-Noun` (e.g., `Test-WebhookUrl`, `Write-RalphLog`) or `PascalCase`
- **Variables**: `$PascalCase` (e.g., `$WebhookUrl`, `$UserHome`)
- **Parameters**: `$PascalCase` (e.g., `$InputPath`, `$TimeoutSeconds`)
- **Files**: `PascalCase.ps1` or `kebab-case.ps1`

#### Best Practices
```powershell
# ✅ Good
function Test-WebhookUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url
    )
    
    if ([string]::IsNullOrEmpty($Url)) {
        Write-RalphError "URL is required"
        return $false
    }
    # Validation logic
}

# ❌ Avoid
function validate_url($url) {  # Wrong naming, no param attributes
    if (!$url) {               # Inconsistent null check
        Write-Host "Error"     # Should use Write-RalphError
        exit 1                 # Should return $false
    }
}
```

## Testing Requirements

### Quality Tests

Before submitting any changes, run all quality tests:

```bash
# Test linting and syntax
python3 tests/quality/test-linting.py

# Test function complexity
python3 tests/quality/test-complexity.py

# Test documentation coverage
python3 tests/quality/test-documentation.py

# Test naming conventions
python3 tests/quality/test-naming-conventions.py
```

### Integration Tests

```bash
# Run full test suite
./tests/test-validation-lib.sh

# Verify scripts work
./ralph.sh --help
./ralph.ps1 -Help  # On Windows
```

### Test-Driven Development

1. **Write tests first** for new functionality
2. **Run tests** to confirm they fail initially
3. **Implement** the feature to make tests pass
4. **Refactor** while keeping tests green
5. **Document** the new functionality

## Submission Process

### Before Submitting

- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] No code duplication introduced
- [ ] Function complexity < 15
- [ ] All functions documented

### Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the guidelines above

3. **Test thoroughly**:
   ```bash
   # Run all tests
   ./tests/test-validation-lib.sh
   python3 tests/quality/test-linting.py
   python3 tests/quality/test-complexity.py
   python3 tests/quality/test-documentation.py
   python3 tests/quality/test-naming-conventions.py
   ```

4. **Commit with descriptive messages**:
   ```bash
   git add .
   git commit -m "feat: add webhook validation with retry logic"
   ```

5. **Push and create PR**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create pull request** with:
   - Clear description of changes
   - Link to related issues
   - Screenshots if UI changes
   - Test results

## Quality Standards

### Code Quality Metrics

- **Complexity**: Functions must have cyclomatic complexity < 15
- **Documentation**: 80% of functions must be documented
- **Naming**: Consistent naming conventions enforced
- **Duplication**: No significant code duplication
- **Testing**: New code must include tests

### Performance Requirements

- **Startup Time**: Scripts should start in < 2 seconds
- **Memory Usage**: Keep memory footprint minimal
- **Error Handling**: All error paths must be tested
- **Platform Support**: Changes must work on Linux, macOS, and Windows

### Security Requirements

- **Input Validation**: All external inputs must be validated
- **Path Safety**: Use path validation to prevent traversal attacks
- **Credential Handling**: Never log or expose credentials
- **Dependency Security**: Only use trusted dependencies

## Shared Libraries

### Using Validation Functions

Always use shared validation instead of duplicating logic:

```bash
# ✅ Good - Use shared validation
source "${RALPH_DIR}/lib/validation.sh"
if ! validate_url "$webhook_url"; then
    exit 1
fi

# ❌ Avoid - Don't duplicate validation
if [[ ! "$url" =~ ^https?: ]]; then
    echo "Invalid URL" >&2
    exit 1
fi
```

### Error Handling

Use shared error handling functions:

```bash
# ✅ Good - Use shared logging
if ! perform_operation; then
    log_error "Operation failed: $?"
    return 1
fi

# ❌ Avoid - Inconsistent error handling  
if ! perform_operation; then
    echo "ERROR: Something went wrong" >&2
    exit 1
fi
```

## Documentation Guidelines

### Function Documentation

#### Bash Functions
```bash
# Function description explaining what it does
# Args:
#   $1 - parameter description
#   $2 - optional parameter (default: value)
# Returns:
#   0 if successful, 1 if error
function_name() {
    # Implementation
}
```

#### PowerShell Functions
```powershell
<#
.SYNOPSIS
    Brief description of what the function does
.PARAMETER Name
    Description of the parameter
.OUTPUTS
    Description of what the function returns
.EXAMPLE
    Test-WebhookUrl -Url "https://example.com"
#>
```

### File Documentation

Every script must include:
- Purpose and description
- Usage examples
- Exit codes
- Dependencies
- Examples

## Getting Help

### Resources

- **README.md**: Basic usage and installation
- **CODE_QUALITY_STANDARDS.md**: Detailed coding standards
- **Issues**: GitHub issue tracker for bugs and features

### Communication

- **GitHub Issues**: For bug reports and feature requests
- **Pull Requests**: For code contributions
- **Discussions**: For questions and community discussion

## Code Review Process

### What We Look For

1. **Correctness**: Does the code work as intended?
2. **Style**: Follows established conventions?
3. **Testing**: Adequate test coverage?
4. **Documentation**: Clear and complete?
5. **Performance**: Efficient implementation?
6. **Security**: No security vulnerabilities?

### Review Timeline

- **Initial Response**: Within 48 hours
- **Full Review**: Within 1 week
- **Follow-up**: As needed for revisions

## Release Process

1. **Feature Freeze**: No new features for release candidates
2. **Testing Phase**: Comprehensive testing on all platforms
3. **Documentation**: Update changelog and documentation
4. **Tagging**: Semantic versioning (MAJOR.MINOR.PATCH)
5. **Distribution**: Release binaries and packages

Thank you for contributing to PortableRalph! Your contributions help make autonomous AI development more accessible to everyone.
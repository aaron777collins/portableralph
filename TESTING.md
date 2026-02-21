# Testing Guide

PortableRalph includes a comprehensive test suite with 150+ automated tests covering all platforms and functionality. This guide covers how to run tests, understand test results, and contribute new tests.

## Quick Start

**Unix/Linux/macOS:**
```bash
cd ~/ralph/tests
./run-all-tests.sh
```

**Windows (PowerShell):**
```powershell
cd ~\ralph\tests
.\run-all-tests.ps1
```

## Test Categories

### Unit Tests
Test individual components and functions in isolation.

**Location:** `tests/unit/`
**Coverage:** Core functions, validation libraries, utility functions

```bash
# Run unit tests only
./run-all-tests.sh --unit-only
```

### Integration Tests
Test component interactions and workflows.

**Location:** `tests/integration/`
**Coverage:** End-to-end workflows, file operations, API interactions

```bash
# Run integration tests only
./run-all-tests.sh --integration-only
```

### Security Tests
Validate security controls and protections.

**Location:** `tests/security/`
**Coverage:** Input validation, file permissions, credential handling, network security

```bash
# Run security tests only
./run-all-tests.sh --security-only
```

### Platform Tests
Ensure cross-platform compatibility.

**Location:** `tests/platform/`
**Coverage:** Windows/Unix differences, path handling, line endings

```bash
# Run platform-specific tests
./run-all-tests.sh --platform-only
```

### Quality Tests
Validate code quality and standards compliance.

**Location:** `tests/quality/`
**Coverage:** Linting, complexity analysis, documentation coverage

```bash
# Run quality tests only
./run-all-tests.sh --quality-only
```

### Documentation Tests
Validate documentation completeness and accuracy.

**Location:** `tests/documentation/`
**Coverage:** README completeness, link validation, installation procedures

```bash
# Run documentation tests only
python3 tests/documentation/run_documentation_tests.py
```

## Test Options

### Verbose Output
Get detailed test output and debugging information:

```bash
./run-all-tests.sh --verbose
```

### Stop on First Failure
Stop testing at the first failure for quick debugging:

```bash
./run-all-tests.sh --stop-on-failure
```

### Specific Test Files
Run specific test files:

```bash
# Run specific test
./tests/test-ralph.sh

# Run specific test category
./tests/security/run_security_tests.py
```

## Test Results

### Understanding Output

**✅ PASSED** - Test completed successfully
**❌ FAILED** - Test failed with error
**⚠️ SKIPPED** - Test skipped due to missing dependencies
**🔥 ERROR** - Test crashed or had unexpected error

### Success Criteria

- **Unit Tests:** Must have 95%+ pass rate
- **Integration Tests:** Must have 90%+ pass rate
- **Security Tests:** Must have 100% pass rate (no exceptions)
- **Platform Tests:** Must pass on target platforms
- **Quality Tests:** Must meet minimum quality thresholds

## Writing New Tests

### Test Structure

```bash
#!/bin/bash
# tests/test-example.sh

source "$(dirname "$0")/test-framework.sh"

test_example_function() {
    # Arrange
    local input="test input"
    local expected="expected output"
    
    # Act
    local result=$(example_function "$input")
    
    # Assert
    assert_equals "$expected" "$result" "Function should transform input correctly"
}

# Run tests
run_tests
```

### Python Tests

```python
#!/usr/bin/env python3
# tests/test-example.py

import unittest
from pathlib import Path

class ExampleTests(unittest.TestCase):
    def test_example(self):
        # Arrange
        input_data = "test input"
        expected = "expected output"
        
        # Act
        result = example_function(input_data)
        
        # Assert
        self.assertEqual(expected, result)

if __name__ == "__main__":
    unittest.main()
```

### Test Naming Conventions

- **Test files:** `test-{component}.sh` or `test_{component}.py`
- **Test functions:** `test_{functionality}()` or `test_{functionality}_with_{condition}()`
- **Test classes:** `{Component}Tests`

### Test Documentation

Each test file should include:
- Purpose and scope comment
- Dependencies and requirements
- Expected behavior description
- Cleanup procedures if needed

## Platform-Specific Testing

### Windows Testing

Windows tests run in multiple environments:
- **PowerShell 5.1** (Windows PowerShell)
- **PowerShell 7+** (Cross-platform PowerShell)
- **Git Bash** (Unix-like environment)
- **WSL** (Windows Subsystem for Linux)

```powershell
# Windows-specific test
Describe "Windows PowerShell Tests" {
    It "Should handle Windows paths correctly" {
        $result = Convert-Path "~\ralph"
        $result | Should -Match "Users\\.+\\ralph"
    }
}
```

### Unix/Linux Testing

Unix tests should be portable across:
- **Linux distributions** (Ubuntu, CentOS, Alpine)
- **macOS** (Intel and Apple Silicon)
- **BSD variants**

```bash
# Unix-specific test
test_unix_paths() {
    local home_path="$HOME/ralph"
    assert_path_exists "$home_path"
}
```

## CI/CD Integration

### GitHub Actions

Tests run automatically on:
- **Push to main branch**
- **Pull requests**
- **Release creation**
- **Daily schedule** (regression testing)

### Test Matrices

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    shell: [bash, pwsh]
    exclude:
      - os: ubuntu-latest
        shell: pwsh
```

### Artifacts

Test runs generate:
- **Test reports** (JUnit XML format)
- **Coverage reports** (HTML and XML)
- **Performance metrics**
- **Security scan results**

## Troubleshooting Tests

### Common Issues

| Problem | Solution |
|---------|----------|
| Tests timeout | Increase timeout values, check for infinite loops |
| Permission errors | Ensure test files have execute permissions |
| Path not found | Use absolute paths or proper relative paths |
| Environment differences | Use platform detection and conditional logic |

### Debugging Failed Tests

1. **Run with verbose output:** `./run-all-tests.sh --verbose`
2. **Run specific test:** `./tests/test-specific.sh`
3. **Check test logs:** `cat tests/logs/test-results.log`
4. **Verify environment:** Check dependencies and configurations

### Test Environment Setup

```bash
# Prepare test environment
cd ~/ralph
export RALPH_TEST_MODE=true
export CLAUDE_API_KEY="test-key-$(date +%s)"

# Clean previous test artifacts
rm -rf tests/tmp/
mkdir -p tests/tmp/

# Run tests
./tests/run-all-tests.sh
```

## Test Coverage

### Coverage Requirements

- **Code Coverage:** 80% minimum for production code
- **Branch Coverage:** 70% minimum for conditional logic
- **Function Coverage:** 90% minimum for public functions

### Generating Coverage Reports

```bash
# Generate coverage report
./tests/coverage/generate-coverage.sh

# View HTML report
open tests/coverage/html/index.html
```

### Coverage Exclusions

Some code is excluded from coverage requirements:
- Error handling code that's difficult to trigger
- Platform-specific code not running in CI
- Development and debugging utilities

## Performance Testing

### Benchmarks

Performance tests ensure Ralph maintains acceptable performance:

```bash
# Run performance benchmarks
./tests/performance/run-benchmarks.sh

# Compare with baseline
./tests/performance/compare-baseline.sh
```

### Performance Metrics

- **Startup time:** < 2 seconds
- **Task processing:** < 30 seconds per iteration
- **Memory usage:** < 500MB peak
- **File I/O:** Efficient batch operations

## Security Testing

### Security Test Categories

1. **Input Validation:** SQL injection, command injection, path traversal
2. **Authentication:** API key handling, credential storage
3. **Authorization:** File permissions, access controls
4. **Network Security:** HTTPS enforcement, SSRF protection
5. **Data Protection:** Credential masking, secure cleanup

### Running Security Tests

```bash
# Comprehensive security testing
./tests/security/run_security_tests.py

# Specific security category
./tests/security/test-input-validation.py
```

### Security Requirements

- **Zero critical vulnerabilities** in production code
- **All inputs validated** and sanitized
- **Credentials never logged** or exposed
- **HTTPS-only** for all network communication

## Contributing Test Improvements

### Before Contributing

1. **Read existing tests** to understand patterns
2. **Check test coverage** to identify gaps
3. **Verify your environment** can run existing tests
4. **Follow naming conventions** for consistency

### Test Review Process

1. **Write tests first** (TDD approach)
2. **Ensure tests fail** initially (red phase)
3. **Implement functionality** to make tests pass (green phase)
4. **Refactor if needed** while keeping tests green
5. **Submit pull request** with tests and implementation

### Test Quality Standards

- **Clear test names** that describe the behavior being tested
- **Comprehensive assertions** that validate expected behavior
- **Proper cleanup** of test artifacts and state
- **Platform compatibility** across supported environments
- **Documentation** of complex test logic

## Advanced Testing

### Load Testing

For high-volume usage scenarios:

```bash
# Simulate multiple concurrent Ralph instances
./tests/load/concurrent-ralph-test.sh 10

# Test with large project files
./tests/load/large-project-test.sh
```

### Regression Testing

Ensure changes don't break existing functionality:

```bash
# Run full regression suite
./tests/regression/run-regression-tests.sh

# Compare with previous version
./tests/regression/compare-versions.sh v1.6.0 v1.7.0
```

### Compatibility Testing

Test across different environments and configurations:

```bash
# Test different Claude CLI versions
./tests/compatibility/claude-versions-test.sh

# Test different Git configurations
./tests/compatibility/git-configs-test.sh
```

## Test Infrastructure

### Test Framework

PortableRalph uses a custom test framework built on:
- **Bash testing framework** for shell script tests
- **Python unittest** for Python-based tests
- **Custom assertions** for Ralph-specific validations

### Test Data Management

- **Test fixtures:** Reusable test data in `tests/fixtures/`
- **Mock data:** Simulated API responses in `tests/mocks/`
- **Sample projects:** Real project examples in `tests/samples/`

### Test Environment Isolation

Each test run uses:
- **Temporary directories** for file operations
- **Environment variable overrides** for configuration
- **Process isolation** to prevent interference
- **Cleanup procedures** to reset state

## Getting Help

### Test Documentation

- **Test framework docs:** `tests/framework/README.md`
- **Writing tests guide:** `tests/docs/writing-tests.md`
- **CI/CD configuration:** `.github/workflows/`

### Community Support

- **GitHub Issues:** Report test failures or request test improvements
- **Discussions:** Ask questions about testing approaches
- **Pull Requests:** Contribute test improvements

### Maintainer Contact

For complex testing issues or framework improvements, contact the maintainers through GitHub issues with the `testing` label.
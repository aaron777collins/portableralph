# PortableRalph Test Failure Analysis

**Generated:** 2026-02-14 14:05 EST  
**Updated:** 2026-02-14 14:10 EST — Reframed: Focus on feature implementation, not security  
**Repository:** https://github.com/aaron777collins/portableralph  
**Total Test Suites:** 10 | **Passed:** 3 | **Failed:** 7

---

## Executive Summary

The PortableRalph test suite has 7 failing test suites out of 10 total. The failures fall into **3 distinct categories**:

| Category | Count | Suites Affected |
|----------|-------|-----------------|
| Missing File/Dependency | 1 | Monitor Tests |
| Exit Code Mismatch | 3 | Ralph, Integration, Validation |
| Test/Impl Mismatch | 3 | Constants, Security Tests, Security Fixes |

**Goal:** Implement the features the tests expect. This is about functionality, not security hardening.

---

## Prioritized Fix Plan

### Priority 1: Missing Implementations 🔴

| Test Suite | What's Missing | Fix |
|------------|----------------|-----|
| Monitor Tests | `monitor-progress.sh` doesn't exist | Create the bash script (port from PS1 if exists) |
| Validation Library | `validate_url()` doesn't check for localhost | Add localhost rejection to match test expectation |
| Security Tests | File path validation accepts URLs | Add URL detection to file path validation |

### Priority 2: Exit Code Fixes 🟠

| Test Suite | Issue | Fix |
|------------|-------|-----|
| Ralph Tests | Invalid mode returns 0 instead of 1 | Add mode validation in `ralph.sh` |
| Integration Tests | Invalid config returns 2 instead of 1 | Wrap config sourcing with error handler |

### Priority 3: Test Alignment 🟢

| Test Suite | Issue | Fix |
|------------|-------|-----|
| Constants Library | Constants not exported | Add `export` keyword |
| Security Fixes | Error message string mismatch | Update implementation message OR update test |

---

## Detailed Failures

### 1. Monitor Tests ❌ — MISSING FILE

```
awk: fatal: cannot open file 'monitor-progress.sh' for reading: No such file or directory
```

**Fix:** Create `monitor-progress.sh` that implements the expected functionality. Check if `monitor-progress.ps1` exists to port from.

---

### 2. Validation Library ❌ — MISSING FEATURE

```
SSRF protection
✗ Rejects localhost
  Expected exit code: 1
  Actual exit code:   0
```

**Fix:** The test expects `validate_url()` to reject localhost URLs. Implement this check:
```bash
# In validate_url()
if [[ "$url" =~ ^https?://(localhost|127\.0\.0\.1) ]]; then
    return 1
fi
```

---

### 3. Security Tests ❌ — MISSING FEATURE

```
File path validation concept
✗ File paths should not be URLs
```

**Fix:** The file path validation function should reject URLs. Add:
```bash
# In validate_file_path() or similar
if [[ "$path" =~ ^https?:// ]]; then
    return 1
fi
```

---

### 4. Ralph Tests ❌ — EXIT CODE

```
Should exit with code 1 for invalid mode
  Expected: 1, Actual: 0
```

**Fix:** Add mode validation at the start of `ralph.sh`:
```bash
valid_modes=("download" "monitor" "setup" ...)  # whatever the valid modes are
if [[ ! " ${valid_modes[*]} " =~ " ${mode} " ]]; then
    echo "Error: Invalid mode '$mode'" >&2
    exit 1
fi
```

---

### 5. Integration Tests ❌ — EXIT CODE

```
Recovery from invalid config
  Expected: 1, Actual: 2
```

**Fix:** Wrap config sourcing to return 1 instead of letting bash return 2:
```bash
if ! source "$config_file" 2>/dev/null; then
    echo "Error: Invalid config syntax" >&2
    exit 1
fi
```

---

### 6. Constants Library ❌ — NOT EXPORTED

```
Constants are exported for scripts
✗ HTTP_MAX_TIME is exported
```

**Fix:** Change from `readonly` to `export`:
```bash
export HTTP_MAX_TIME=30
export readonly HTTP_MAX_TIME  # or both
```

---

### 7. Security Fixes ❌ — MESSAGE MISMATCH

```
Custom script executable validation
✗ Detects non-executable custom script
  Expected to find: "not executable"
```

**Fix:** Either update the error message in the implementation to say "not executable", or update the test to match what's actually output.

---

## Task Breakdown

### Phase 1: Implement Missing Features
- [ ] Create `monitor-progress.sh`
- [ ] Add localhost rejection to `validate_url()`
- [ ] Add URL rejection to file path validation

### Phase 2: Fix Exit Codes
- [ ] Add mode validation to `ralph.sh`
- [ ] Wrap config sourcing with error handler

### Phase 3: Align Tests/Impl
- [ ] Export constants in `lib/constants.sh`
- [ ] Fix error message in executable validation

---

*Analysis completed by sub-agent p0-1-categorize-failures*
*Updated by Sophie to focus on feature implementation*

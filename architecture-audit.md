# PortableRalph Architecture Audit

**Task:** p0-3-architecture-audit
**Generated:** 2026-02-22

---

## Architecture Overview

PortableRalph is a **shell script-based toolkit** for portable media management. The codebase follows a traditional Unix-style pattern with:
- Main entry point (`ralph.sh`)
- Library files (`lib/*.sh`)
- Configuration files
- Test suites (`tests/*.sh`)

---

## Identified Design Issues

### 1. 🔴 No Centralized Error Handling

**Problem:** Each script implements its own error handling (or doesn't). There's no standardized way to:
- Return consistent exit codes
- Log errors uniformly
- Propagate error context

**Impact:** 
- 3 test suites fail due to exit code inconsistency
- Debugging is difficult - errors don't bubble up predictably
- Silent failures possible

**Technical Debt:** HIGH

**Architectural Fix:**
```bash
# lib/errors.sh (proposed)
source "lib/exit-codes.sh"

die() {
    local msg="$1"
    local code="${2:-$EXIT_ERROR}"
    echo "ERROR: $msg" >&2
    exit "$code"
}

check_or_die() {
    local condition="$1"
    local msg="$2"
    eval "$condition" || die "$msg"
}
```

### 2. 🔴 Security Validation is Reactive, Not Defensive

**Problem:** Validation functions (`lib/validation.sh`) are written to confirm "is this input valid?" but don't ask "is this input hostile?"

**Current Pattern:**
```bash
validate_url() {
    # Checks: does it look like a URL?
    # Missing: is it localhost? Is it an internal IP?
}
```

**Impact:**
- SSRF vulnerabilities possible
- File path parameters could accept URLs
- User-controlled input could reach sensitive paths

**Technical Debt:** HIGH (Security)

**Architectural Fix:**
```bash
# Add hostile input detection before happy-path validation
validate_url() {
    local url="$1"
    
    # FIRST: Reject hostile patterns
    if is_internal_url "$url"; then
        return 1  # SSRF protection
    fi
    
    # THEN: Validate structure
    if [[ ! "$url" =~ ^https?:// ]]; then
        return 1
    fi
    
    return 0
}

is_internal_url() {
    local url="$1"
    [[ "$url" =~ localhost ]] && return 0
    [[ "$url" =~ 127\.0\.0\. ]] && return 0
    [[ "$url" =~ ^https?://10\. ]] && return 0
    [[ "$url" =~ ^https?://192\.168\. ]] && return 0
    [[ "$url" =~ ^https?://172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && return 0
    return 1
}
```

### 3. 🟡 Constants Not Designed for Subprocesses

**Problem:** `lib/constants.sh` uses `readonly` but not `export`. Constants are available when the library is sourced, but not in subshells or subprocesses.

**Current:**
```bash
readonly HTTP_MAX_TIME=30
```

**Expected by tests:**
```bash
export readonly HTTP_MAX_TIME=30
# or
export HTTP_MAX_TIME=30
readonly HTTP_MAX_TIME
```

**Impact:** Low - only matters if scripts spawn subprocesses that need these values.

**Design Question:** Is this intentional? If constants should stay in parent process only, the test expectation is wrong. If they should propagate, add `export`.

**Technical Debt:** LOW

### 4. 🟡 Missing Cross-Platform Support File

**Problem:** `monitor-progress.sh` doesn't exist. There's a `monitor-progress.ps1` (PowerShell), suggesting incomplete cross-platform support.

**Impact:** Monitor test suite can't run at all.

**Technical Debt:** MEDIUM

**Architectural Fix:** Either:
1. Port PowerShell logic to bash (`monitor-progress.sh`)
2. Update tests to skip on non-Windows if monitor is PS-only
3. Create a bash shim that provides compatible interface

### 5. 🟡 Test-Implementation Coupling Issues

**Problem:** Tests check for specific string literals in error messages. Implementation may have changed without updating tests.

**Example:**
```bash
# Test expects:
[[ "$output" == *"not executable"* ]]

# Implementation might say:
"Script is not executable"  # Different wording
```

**Impact:** False failures that mask whether functionality actually works.

**Technical Debt:** LOW (but annoying)

**Architectural Fix:** 
- Use exit codes for machine-readable checks
- Reserve string matching for human-readable output verification only
- Document error message formats

---

## Dependency Complexity

```
                    ┌──────────────┐
                    │   ralph.sh   │  Main entry point
                    └──────┬───────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │ lib/        │ │ config      │ │ tests/      │
    │ validation  │ │ (user)      │ │ (separate)  │
    │ constants   │ │             │ │             │
    │ errors(?)   │ │             │ │             │
    └─────────────┘ └─────────────┘ └─────────────┘
```

The architecture is **flat** — which is good for simplicity but means:
- No clear layering (validation before execution)
- No dependency injection (hard to test in isolation)
- Config errors can crash in unexpected places

---

## Recommended Architecture Changes

### Priority 1: Error Handling Foundation
Create `lib/errors.sh` with:
- Exit code constants
- `die()` function for fatal errors
- `warn()` function for non-fatal issues
- `check_or_die()` for condition checking

Then refactor all scripts to use it.

### Priority 2: Security Layer
Create `lib/security.sh` with:
- `is_hostile_url()` — SSRF protection
- `is_safe_path()` — path traversal protection
- `validate_file_not_url()` — filepath/URL confusion protection

Integrate into validation.sh as first-pass checks.

### Priority 3: Cross-Platform Abstraction
Create `lib/platform.sh` with:
- OS detection
- Path normalization (Unix vs Windows)
- Feature availability checks

Then platform-specific scripts can delegate to this.

---

## Summary

| Issue | Severity | Architectural Impact | Fix Effort |
|-------|----------|---------------------|------------|
| No centralized error handling | 🔴 HIGH | Causes 3+ test failures | Medium |
| Security validation gaps | 🔴 HIGH | Security vulnerability | Low |
| Constants not exported | 🟡 MEDIUM | 1 test failure | Trivial |
| Missing cross-platform script | 🟡 MEDIUM | 1 test suite blocked | Medium |
| Test string matching | 🟢 LOW | False failures | Low |

**Main Takeaway:** The codebase lacks defensive layers (error handling, security checks). Adding these foundational pieces will fix most failures and prevent future regressions.

---

*Audit completed by Coordinator (p0-3-architecture-audit)*

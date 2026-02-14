# PortableRalph Fix Strategy

**Tasks:** p0-4-complexity-estimates & p0-5-prioritized-order
**Generated:** 2026-02-22
**Status:** FINAL — Ready for Phase 1 Execution

---

## Executive Summary

7 test suites are failing. Deep analysis reveals:
- **5 failures** trace back to **2 root causes** (exit codes + security validation)
- **2 failures** are independent (test alignment issues)
- **1 failure** is blocked on a missing file

**Recommended approach:** Fix the 2 root causes first, which automatically resolves 5 failures with minimal effort per fix.

---

## Complexity Estimates

### Difficulty Scale
| Rating | Definition | Typical Time |
|--------|------------|--------------|
| Trivial | Single-line or obvious fix | <15 min |
| Easy | Small, localized change | 15-60 min |
| Moderate | Multiple file changes, some design | 1-3 hours |
| Hard | Architectural change, careful testing | 3-8 hours |
| Major Refactor | Significant restructure | 1+ days |

### Per-Fix Estimates

| Fix ID | Description | Complexity | Time Est | Risk |
|--------|-------------|------------|----------|------|
| F1 | Create `lib/exit-codes.sh` | Easy | 30 min | Low |
| F2 | Create `lib/errors.sh` with `die()` | Easy | 45 min | Low |
| F3 | Refactor `ralph.sh` mode validation | Easy | 30 min | Low |
| F4 | Refactor config error handling | Easy | 30 min | Low |
| F5 | Add SSRF protection to `validate_url()` | Easy | 45 min | Low |
| F6 | Add URL rejection to filepath validation | Easy | 30 min | Low |
| F7 | Add `export` to constants (or fix test) | Trivial | 10 min | None |
| F8 | Create `monitor-progress.sh` or fix path | Moderate | 2 hours | Medium |
| F9 | Fix error message assertion in test | Trivial | 15 min | None |

**Total Estimated Time:** ~6-7 hours for all fixes

---

## Dependency Matrix

```
F1 (exit-codes.sh)
 │
 └──► F2 (errors.sh) depends on F1
       │
       ├──► F3 (ralph.sh mode) depends on F2
       │
       └──► F4 (config error) depends on F2

F5 (SSRF protection) — independent
F6 (URL in path) — independent  
F7 (constants export) — independent
F8 (monitor script) — independent
F9 (error message) — independent
```

---

## Prioritized Fix Order

### Wave 1: Foundation (Do First)
**Goal:** Establish error handling pattern that all other fixes will use.

| Order | Fix | What | Why First |
|-------|-----|------|-----------|
| 1 | F1 | Create `lib/exit-codes.sh` | Base for all error handling |
| 2 | F2 | Create `lib/errors.sh` | Provides `die()` for other fixes |

**Time:** ~1.25 hours
**Fixes:** 0 tests (but enables Wave 2)

### Wave 2: Quick Wins (High ROI)
**Goal:** Fix the most test failures with the least code.

| Order | Fix | What | Tests Fixed |
|-------|-----|------|-------------|
| 3 | F5 | SSRF protection | Validation Library ✅ |
| 4 | F6 | URL in filepath | Security Tests ✅ |
| 5 | F3 | Mode validation | Ralph Tests ✅ |
| 6 | F4 | Config error trap | Integration Tests ✅ |

**Time:** ~2 hours
**Fixes:** 4 test suites (57% of failures)

### Wave 3: Cleanup (Independent Fixes)
**Goal:** Mop up remaining failures.

| Order | Fix | What | Tests Fixed |
|-------|-----|------|-------------|
| 7 | F7 | Constants export | Constants Library ✅ |
| 8 | F9 | Error message text | Security Fixes ✅ |

**Time:** ~25 min
**Fixes:** 2 test suites (total: 6/7 = 86%)

### Wave 4: Cross-Platform (Larger Effort)
**Goal:** Fix the blocked test suite.

| Order | Fix | What | Tests Fixed |
|-------|-----|------|-------------|
| 9 | F8 | Create/fix monitor script | Monitor Tests ✅ |

**Time:** ~2 hours
**Fixes:** 1 test suite (total: 7/7 = 100%)

---

## Implementation Details

### F1: Create `lib/exit-codes.sh`
```bash
#!/usr/bin/env bash
# Standard exit codes for PortableRalph

export EXIT_SUCCESS=0
export EXIT_ERROR=1
export EXIT_INVALID_ARGS=2
export EXIT_MISSING_DEP=3
export EXIT_CONFIG_ERROR=4
export EXIT_PERMISSION=5
```

### F2: Create `lib/errors.sh`
```bash
#!/usr/bin/env bash
# Error handling utilities

source "${BASH_SOURCE%/*}/exit-codes.sh"

die() {
    local msg="${1:-Unknown error}"
    local code="${2:-$EXIT_ERROR}"
    echo "ERROR: $msg" >&2
    exit "$code"
}

warn() {
    echo "WARNING: $1" >&2
}

check_or_die() {
    local msg="$1"
    shift
    "$@" || die "$msg"
}
```

### F3: Mode Validation Fix (ralph.sh)
```bash
# Add near top of ralph.sh, after parsing mode
VALID_MODES="backup restore sync check"
if [[ ! " $VALID_MODES " =~ " $mode " ]]; then
    die "Invalid mode: $mode. Valid modes: $VALID_MODES" $EXIT_INVALID_ARGS
fi
```

### F4: Config Error Trap (integration)
```bash
# Wrap config sourcing
load_config() {
    local config_file="$1"
    if ! source "$config_file" 2>/dev/null; then
        die "Invalid config file: $config_file" $EXIT_CONFIG_ERROR
    fi
}
```

### F5: SSRF Protection
```bash
# Add to lib/validation.sh
is_internal_url() {
    local url="$1"
    [[ "$url" =~ localhost ]] && return 0
    [[ "$url" =~ 127\.0\.0\. ]] && return 0
    [[ "$url" =~ ^https?://10\. ]] && return 0
    [[ "$url" =~ ^https?://192\.168\. ]] && return 0
    [[ "$url" =~ ^https?://172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && return 0
    [[ "$url" =~ ^file:// ]] && return 0
    return 1
}

validate_url() {
    local url="$1"
    
    # Security check first
    if is_internal_url "$url"; then
        return 1
    fi
    
    # Then format validation
    [[ "$url" =~ ^https?:// ]] || return 1
    return 0
}
```

### F6: URL in Filepath Rejection
```bash
# Add to lib/validation.sh
validate_filepath() {
    local path="$1"
    
    # Reject URLs masquerading as paths
    if [[ "$path" =~ ^(https?|ftp|file):// ]]; then
        return 1
    fi
    
    # Normal path validation...
    [[ -n "$path" ]] || return 1
    return 0
}
```

### F7: Constants Export
```bash
# In lib/constants.sh, change:
readonly HTTP_MAX_TIME=30

# To:
export HTTP_MAX_TIME=30
readonly HTTP_MAX_TIME
```

OR update the test to not expect export (if design intent is parent-only).

### F8: Monitor Script
Port from PowerShell or create bash equivalent:
```bash
#!/usr/bin/env bash
# monitor-progress.sh - Monitor operation progress

source "${BASH_SOURCE%/*}/lib/errors.sh"

show_progress() {
    local current="$1"
    local total="$2"
    local percent=$((current * 100 / total))
    printf "\rProgress: [%-50s] %d%%" $(printf '#%.0s' $(seq 1 $((percent / 2)))) "$percent"
}

# Main logic...
```

### F9: Error Message Fix
Either update implementation to say "not executable":
```bash
# Change
echo "Script lacks execute permission"
# To
echo "Script is not executable"
```

Or update test to match actual message.

---

## Risk Assessment

| Fix | Risk | Mitigation |
|-----|------|------------|
| F1-F2 | Low — Additive, doesn't break existing | Test in isolation first |
| F3-F4 | Low — Controlled changes | Run affected tests immediately |
| F5-F6 | Low — Security improvements | Ensure no false positives |
| F7 | None — Trivial | Test subprocess behavior |
| F8 | Medium — New code | Validate against PS1 behavior |
| F9 | None — String change | Verify exact match |

---

## Verification Checklist

After all fixes:
- [ ] `./tests/test-ralph.sh` passes
- [ ] `./tests/test-monitor.sh` passes  
- [ ] `./tests/test-validation.sh` passes
- [ ] `./tests/test-constants.sh` passes
- [ ] `./tests/test-integration.sh` passes
- [ ] `./tests/test-security.sh` passes
- [ ] `./tests/test-security-fixes.sh` passes
- [ ] Full test suite: `./run-tests.sh` = 10/10 pass

---

## Next Steps

1. ✅ Phase 0 Analysis Complete
2. ⏳ Phase 1: Execute fixes in priority order (Waves 1-4)
3. ⏳ Phase 2: Run full test suite
4. ⏳ Phase 3: PR review (2 open PRs)
5. ⏳ Phase 4: Windows verification
6. ⏳ Phase 5: Deploy

**Ready for Phase 1 execution.**

---

*Strategy completed by Coordinator (p0-4 + p0-5)*

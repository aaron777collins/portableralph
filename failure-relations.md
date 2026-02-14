# PortableRalph Test Failure Relations Analysis

**Task:** p0-2-identify-relations
**Generated:** 2026-02-22
**Input:** test-failure-analysis.md

---

## Systemic vs Isolated Classification

### 🔴 SYSTEMIC ISSUES (Shared Root Causes)

#### 1. Exit Code Handling Pattern (3 failures)
**Affected Suites:** Ralph Tests, Validation Library, Integration Tests

These three failures share a common anti-pattern: **inconsistent error handling** that returns success (exit 0) or non-standard codes instead of failure (exit 1).

```
Root Cause: No standardized error handling convention
     │
     ├──► Ralph Tests: Invalid mode returns 0
     │
     ├──► Validation Library: SSRF bypass returns 0
     │
     └──► Integration Tests: Config error returns 2 (not 1)
```

**Systemic Nature:** All three failures stem from the same architectural gap - the codebase lacks:
- Centralized exit code constants
- Standardized error handling wrapper functions
- Consistent "fail fast" validation patterns

#### 2. Security Validation Gaps (2 failures)
**Affected Suites:** Validation Library (SSRF), Security Tests (URL in filepath)

```
Root Cause: Input validation is incomplete
     │
     ├──► SSRF: validate_url() missing localhost/internal IP checks
     │
     └──► Filepath: No URL-in-path rejection
```

**Systemic Nature:** Both are symptoms of the same design gap: validation functions were written for "happy path" inputs but lack hostile input protection.

### 🟡 SEMI-ISOLATED (Related but Separate)

#### 3. Test Assertion Mismatches (2 failures)
**Affected Suites:** Constants Library, Security Fixes

```
Constants Library: Tests expect "export", code uses "readonly"
Security Fixes:    Tests expect specific error message text
```

**Relationship:** Both are test/implementation misalignment issues, but they're independent - fixing one doesn't affect the other. They share a *category* but not a *root cause*.

### 🟢 ISOLATED ISSUES (Independent)

#### 4. Missing Dependency (1 failure)
**Affected Suite:** Monitor Tests

```
monitor-progress.sh does not exist
  └── Either create file or fix test reference
```

**Isolated:** Completely independent. No other test relies on this script, and fixing it won't cascade to other failures.

---

## Root Cause vs Symptom Mapping

| Failure | Is It a Root Cause? | Dependencies |
|---------|--------------------|--------------| 
| Exit code handling convention missing | ✅ **ROOT** | Causes 3 test failures |
| Invalid mode returns 0 | ❌ Symptom | Depends on exit code convention |
| SSRF bypass returns 0 | ❌ Symptom | Depends on exit code convention |
| Config error returns 2 | ❌ Symptom | Depends on exit code convention |
| Input validation incomplete | ✅ **ROOT** | Causes 2 test failures |
| localhost URL accepted | ❌ Symptom | Depends on input validation |
| URL in filepath accepted | ❌ Symptom | Depends on input validation |
| Test assertion mismatches | ⚠️ Mixed | Independent, need case-by-case review |
| Missing script file | ✅ **ROOT** | Isolated, causes 1 test failure |

---

## Failure Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FIX ORDER IMPLICATIONS                        │
└─────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────────┐
                    │  Exit Code Standard  │  ← ROOT CAUSE
                    │  (create constants   │
                    │   + error handlers)  │
                    └──────────┬───────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
   ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
   │  Ralph Tests   │ │ Validation Lib │ │ Integration    │
   │  (mode check)  │ │ (SSRF check)   │ │ (config trap)  │
   └────────────────┘ └────────────────┘ └────────────────┘


                    ┌──────────────────────┐
                    │  Input Validation    │  ← ROOT CAUSE
                    │  (security checks)   │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
           ┌────────────────┐    ┌────────────────┐
           │ SSRF Protection│    │ Filepath URL   │
           │ (localhost)    │    │ rejection      │
           └────────────────┘    └────────────────┘


   ┌───────────────────────────────────────────────────────────────┐
   │                    INDEPENDENT ISSUES                         │
   └───────────────────────────────────────────────────────────────┘

   ┌────────────────┐     ┌────────────────┐     ┌────────────────┐
   │ Monitor Script │     │ Constants      │     │ Security Fixes │
   │ (create file)  │     │ (export/test)  │     │ (error msg)    │
   └────────────────┘     └────────────────┘     └────────────────┘
   
   No dependencies — can be fixed in any order
```

---

## Key Insights

### 1. Fix the Roots First
**3 failures** can be prevented by establishing an exit code standard. Create `lib/exit-codes.sh`:
```bash
export EXIT_SUCCESS=0
export EXIT_ERROR=1
export EXIT_INVALID_ARGS=2
# ... etc
```
Then wrap all error returns through a helper that guarantees consistent codes.

### 2. Security Validation is Structurally Weak
The validation library has an "allowlist" approach (what's valid) but not a "denylist" approach (what's hostile). Both are needed for security. Create:
- `is_hostile_url()` — checks localhost, internal IPs, file:// etc.
- `is_path_not_url()` — ensures a path parameter isn't actually a URL

### 3. Test vs Implementation Alignment is a Process Issue
The assertion mismatches (constants export, error message wording) suggest tests were written before or without reference to implementation. This is a development process issue, not a code issue.

### 4. Missing Script is Trivial
The monitor-progress.sh missing is a one-off file creation task with no cascading effects.

---

## Summary Table

| Category | Count | Systemic? | Fix Strategy |
|----------|-------|-----------|--------------|
| Exit code inconsistency | 3 | ✅ Yes | Create standard, refactor all |
| Security validation gaps | 2 | ✅ Yes | Add hostile input checks |
| Test assertion mismatch | 2 | ❌ No | Case-by-case review |
| Missing file | 1 | ❌ No | Create or update reference |

**Bottom Line:** 5 of 7 failures trace back to just 2 root causes (exit codes + security validation). Fix those foundations first, and the test fixes become trivial.

---

*Analysis completed by Coordinator (p0-2-identify-relations)*

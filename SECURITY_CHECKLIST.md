# PortableRalph Security Checklist

**Version:** 1.0  
**Created:** 2026-02-20  
**Purpose:** Security validation checklist for releases and deployments

## Pre-Release Security Review

### 🔍 Code Security Scan

#### Credential Security
- [ ] **No hardcoded credentials** - Scan all files for API keys, tokens, passwords
- [ ] **Environment variable usage** - All secrets use env vars or encrypted storage
- [ ] **No credentials in logs** - Verify no sensitive data appears in output/logs
- [ ] **Encrypted credential support** - Test `ENC:` prefix functionality works
- [ ] **Key derivation security** - Verify machine-specific key generation

**Commands to run:**
```bash
# Scan for potential secrets (should return empty):
grep -r "api_key\|password\|token\|secret\|webhook" . --exclude-dir=.git | grep -v ".example\|.md\|.template"

# Check for hardcoded URLs with credentials:
grep -r "https://.*:.*@" . --exclude-dir=.git

# Verify no credentials in environment displays:
grep -r "env\|printenv\|set" *.ps1 *.sh
```

#### Input Validation  
- [ ] **Parameter validation** - All user inputs validated and sanitized
- [ ] **Path traversal protection** - File paths validated, no `../` injection
- [ ] **Command injection protection** - No eval, exec, or dynamic command construction
- [ ] **Type enforcement** - PowerShell params enforce correct types

**Commands to run:**
```bash
# Check for dangerous functions:
grep -r "eval\|exec\|Invoke-Expression" *.ps1 *.sh *.bat

# Check for unvalidated user input usage:
grep -r "\$1\|\$2\|\$args" *.ps1 *.sh *.bat
```

#### Network Security
- [ ] **HTTPS-only communication** - No HTTP usage anywhere
- [ ] **Legitimate domains only** - All external calls to trusted services
- [ ] **Webhook validation** - Webhook URLs properly formatted and safe
- [ ] **SSL/TLS certificate validation** - No certificate bypasses

**Commands to run:**
```bash
# Verify no insecure HTTP usage:
grep -r "http://" . --exclude-dir=.git

# Check all HTTPS endpoints are legitimate:
grep -r "https://" . --exclude-dir=.git | grep -v ".md"
```

### 📁 File Security

#### File Permissions
- [ ] **PowerShell scripts:** `644` (rw-r--r--)
- [ ] **Shell scripts:** `755` (rwxr-xr-x)  
- [ ] **Batch files:** `755` (rwxr-xr-x)
- [ ] **Documentation:** `644` (rw-r--r--)
- [ ] **No world-writable files** - Check no `777` permissions

**Commands to run:**
```bash
# Check PowerShell script permissions (should be 644):
ls -la *.ps1

# Check shell script permissions (should be 755):
ls -la *.sh *.bat

# Check for world-writable files (should return empty):
find . -perm -002 -type f
```

#### File Integrity
- [ ] **No suspicious files** - Check for unexpected executables or scripts
- [ ] **Checksums verified** - Important files have expected content
- [ ] **Git history clean** - No commits adding credentials or binaries

**Commands to run:**
```bash
# Check for unexpected executable files:
find . -type f -executable | grep -v ".sh\|.bat\|/\.git/"

# Verify git history doesn't contain large binaries:
git log --stat | grep -E "binary|[0-9]{6,} insertions"
```

### 🔗 Dependency Security

#### External Dependencies
- [ ] **Minimal dependencies** - Only essential external tools required
- [ ] **Dependency versions** - Specify versions where possible
- [ ] **Trusted sources** - All dependencies from legitimate sources
- [ ] **No npm audit issues** - Run `npm audit` if Node.js dependencies exist

**Commands to run:**
```bash
# Check for dependency files:
find . -name "package*.json" -o -name "requirements*.txt" -o -name "Gemfile*" -o -name "composer.*"

# If found, run appropriate audit:
# npm audit (for Node.js)
# pip-audit (for Python)  
# bundle audit (for Ruby)
```

## Deployment Security

### 🚀 Production Environment

#### Access Controls
- [ ] **User-level installation** - Install to user directory, not system-wide
- [ ] **Service account** - Use dedicated service account for automation
- [ ] **Network restrictions** - Limit outbound network access to required domains
- [ ] **Firewall rules** - Block unnecessary inbound connections

#### Configuration Security  
- [ ] **Environment isolation** - Production config separate from development
- [ ] **Encrypted credentials** - Use encrypted env vars in production
- [ ] **Config file permissions** - `.ralph.env` readable by user only (600)
- [ ] **No default credentials** - All default values changed

**Commands to run:**
```bash
# Check config file permissions (should be 600):
ls -la ~/.ralph.env

# Verify no test/default credentials remain:
grep -E "test|example|default|demo" ~/.ralph.env
```

### 📊 Monitoring & Logging

#### Security Monitoring
- [ ] **Failed authentication alerts** - Monitor webhook authentication failures  
- [ ] **Configuration change tracking** - Log when security settings change
- [ ] **Network activity monitoring** - Track external API calls
- [ ] **Error rate monitoring** - Alert on unusual error patterns

#### Audit Trail
- [ ] **Activity logging** - Log major operations and decisions
- [ ] **Credential usage tracking** - Monitor when/how credentials are accessed
- [ ] **File modification tracking** - Log changes to critical files
- [ ] **Network request logging** - Log external API calls and responses

## Incident Response

### 🚨 Security Event Response

#### Credential Compromise
1. **Rotate all affected credentials immediately**
2. **Update webhook URLs if compromised**  
3. **Re-encrypt environment variables**
4. **Review logs for unauthorized usage**
5. **Update security documentation**

#### Code Injection Attack
1. **Stop all running instances immediately**
2. **Isolate affected systems**
3. **Review all user inputs and validate sanitization**
4. **Audit git history for malicious commits**
5. **Update input validation logic**

#### Unauthorized Access
1. **Check file permissions and ownership**
2. **Review system access logs**
3. **Rotate service account credentials**
4. **Audit configuration changes**
5. **Implement additional access controls**

## Release Validation

### ✅ Pre-Release Checklist

**Security Lead Sign-off Required:**

- [ ] Code security scan completed (no critical/high findings)
- [ ] Dependency audit passed (no critical vulnerabilities)
- [ ] File permissions verified correct
- [ ] Network security validated (HTTPS-only)
- [ ] Input validation tested
- [ ] Configuration security reviewed
- [ ] Documentation updated with security considerations
- [ ] Deployment security checklist completed

### 🔐 Security Testing

#### Manual Testing
- [ ] **Injection testing** - Try command/path injection attacks
- [ ] **Authentication testing** - Test with invalid/expired credentials
- [ ] **Authorization testing** - Verify access controls work
- [ ] **Error handling testing** - Ensure errors don't leak sensitive data

#### Automated Testing  
- [ ] **Static code analysis** - Automated security scanning
- [ ] **Dependency scanning** - Automated vulnerability checking
- [ ] **Configuration validation** - Automated config security tests
- [ ] **Integration testing** - End-to-end security workflow tests

### 📋 Version Control

#### Git Security
- [ ] **Commit signatures** - Sign commits for authenticity
- [ ] **Branch protection** - Protect main branch from direct pushes
- [ ] **Review requirements** - Require security review for sensitive changes
- [ ] **Secret scanning** - Use GitHub secret scanning or equivalent

## Emergency Procedures

### 🔥 Security Incident Process

1. **Immediate containment** - Stop affected services
2. **Impact assessment** - Determine scope of compromise
3. **Evidence preservation** - Collect logs and forensic data
4. **Stakeholder notification** - Alert relevant teams/users
5. **Remediation** - Fix vulnerabilities and restore service
6. **Post-incident review** - Update processes and controls

### 📞 Emergency Contacts

- **Security Lead:** [Contact Info]
- **System Administrator:** [Contact Info]  
- **Project Owner:** Aaron Collins
- **Incident Response Team:** [Contact Info]

---

**Checklist Version:** 1.0  
**Last Updated:** 2026-02-20  
**Next Review:** 2026-05-20 (quarterly)
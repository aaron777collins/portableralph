# Troubleshooting Guide

This guide helps you diagnose and fix common issues with PortableRalph.

## Quick Diagnostic Checklist

Before diving into specific issues, run this quick diagnostic:

```bash
# Check Ralph is installed
which ralph || ls ~/ralph/ralph.sh

# Check Claude CLI is available
which claude

# Check configuration exists
ls -la ~/.ralph.env

# Check version
ralph --version

# Test notifications
ralph notify test
```

---

## Installation Issues

### Ralph Command Not Found

**Symptoms:**
```bash
$ ralph --help
-bash: ralph: command not found
```

**Cause:** Shell alias not configured or shell config not reloaded.

**Solution:**

1. Check if alias exists:
   ```bash
   alias ralph
   ```

2. If missing, add to shell config:
   ```bash
   # For bash
   echo "alias ralph='$HOME/ralph/ralph.sh'" >> ~/.bashrc
   source ~/.bashrc

   # For zsh
   echo "alias ralph='$HOME/ralph/ralph.sh'" >> ~/.zshrc
   source ~/.zshrc
   ```

3. Or use full path:
   ```bash
   ~/ralph/ralph.sh --help
   ```

### Claude CLI Not Found

**Symptoms:**
```
❌ Missing required dependencies: claude
```

**Cause:** Claude Code CLI not installed.

**Solution:**

Install Claude Code from [https://docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code):

```bash
# Check if installed
which claude

# If not found, install from official docs
# Then verify:
claude --version
```

### Git Not Found

**Symptoms:**
```
❌ Missing required dependencies: git
```

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y git

# macOS
brew install git

# Verify
git --version
```

### Permission Denied

**Symptoms:**
```bash
$ ralph --help
-bash: ~/ralph/ralph.sh: Permission denied
```

**Cause:** Scripts not executable.

**Solution:**

```bash
chmod +x ~/ralph/*.sh
```

---

## Runtime Issues

### Ralph Keeps Repeating the Same Task

**Symptoms:**
- Ralph completes a task but doesn't mark it done
- Same task runs multiple times
- Progress file shows task as `[ ]` despite being implemented

**Possible Causes & Solutions:**

#### 1. Tests Failing

**Diagnosis:**
```bash
# Check what tests Ralph is running
tail -50 /tmp/ralph_last_run.log

# Run tests manually
npm test  # or pytest, cargo test, etc.
```

**Solution:**
- Fix failing tests
- Or temporarily skip tests if not relevant to the task
- Add test expectations to your plan file

#### 2. Build Errors

**Diagnosis:**
```bash
# Try building manually
npm run build  # or cargo build, make, etc.
```

**Solution:**
- Fix build errors
- Ensure dependencies are installed
- Check for syntax errors

#### 3. Task Already Complete But Not Detected

**Diagnosis:**
Look at the progress file:
```bash
cat my-plan_PROGRESS.md
```

**Solution:**
Manually mark the task as complete:
```markdown
- [x] Task 1: Already done
```

Then run Ralph again.

#### 4. Validation Criteria Unclear

**Solution:**
Update your plan with explicit success criteria:

```markdown
## Task 1: Add Login Endpoint

Success criteria:
- POST /auth/login endpoint exists
- Returns JWT token
- Tests pass
- No linting errors
```

### Ralph Exits Immediately

**Symptoms:**
```bash
$ ralph ./plan.md build
RALPH_DONE - Work complete!
```
(But work isn't actually complete)

**Cause:** Progress file already contains `RALPH_DONE`.

**Solution:**

1. Check the progress file:
   ```bash
   grep -n "RALPH_DONE" my-plan_PROGRESS.md
   ```

2. If found incorrectly, remove it:
   ```bash
   sed -i '/RALPH_DONE/d' my-plan_PROGRESS.md
   ```

3. Or reset the status section:
   ```markdown
   ## Status
   IN_PROGRESS
   ```

### Plan Mode Doesn't Exit

**Symptoms:**
Plan mode runs multiple iterations instead of exiting after creating task list.

**Cause:** This is a bug - plan mode should always exit after 1 iteration.

**Solution:**

1. Press `Ctrl+C` to stop
2. Check the progress file was created:
   ```bash
   ls -la *_PROGRESS.md
   ```
3. If task list looks good, run build mode:
   ```bash
   ralph ./plan.md build
   ```

### Claude CLI Errors

**Symptoms:**
```
Claude exited with error, continuing...
Error: Invalid API key
```

**Cause:** Claude CLI not authenticated or API key expired.

**Solution:**

1. Check Claude CLI status:
   ```bash
   claude --version
   ```

2. Re-authenticate:
   ```bash
   claude auth login
   ```

3. Test it works:
   ```bash
   echo "Hello" | claude -p
   ```

### Progress File Not Found

**Symptoms:**
```
Error: Progress file not found: my-plan_PROGRESS.md
```

**Cause:** Running from wrong directory or progress file deleted.

**Solution:**

1. Progress files are created in your **current directory**, not where the plan file is:
   ```bash
   # If plan is in ~/plans/feature.md
   cd ~/my-project  # Go to where you want progress file
   ralph ~/plans/feature.md plan
   # Creates: ~/my-project/feature_PROGRESS.md
   ```

2. If deleted, run plan mode again to recreate:
   ```bash
   ralph ./plan.md plan
   ```

---

## Notification Issues

### Notifications Not Sending

**Symptoms:**
Ralph runs but no Slack/Discord/Telegram messages appear.

**Diagnosis:**

1. Check configuration exists:
   ```bash
   cat ~/.ralph.env
   ```

2. Verify environment variables are loaded:
   ```bash
   echo $RALPH_SLACK_WEBHOOK_URL
   echo $RALPH_DISCORD_WEBHOOK_URL
   echo $RALPH_TELEGRAM_BOT_TOKEN
   ```

3. Test notifications:
   ```bash
   ralph notify test
   ```

**Solutions:**

#### If No Config File Exists:
```bash
ralph notify setup
```

#### If Config Exists But Not Loaded:
```bash
# Add to shell profile
echo 'source ~/.ralph.env' >> ~/.bashrc
source ~/.bashrc
```

#### If Test Fails:
Check the specific platform sections below.

### Slack Notifications Failing

**Symptoms:**
```
Slack: FAILED
```

**Common Causes:**

| Error | Solution |
|:------|:---------|
| `HTTP 404` | Webhook URL invalid - recreate in Slack |
| `HTTP 403` | Webhook revoked - check Slack app settings |
| `invalid_payload` | Message formatting issue - update Ralph |
| `timeout` | Slack API slow - wait and retry |

**Diagnosis:**

Test webhook manually:
```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  "$RALPH_SLACK_WEBHOOK_URL"
```

Expected response: `ok`

**Solution:**

If webhook doesn't work, recreate it:

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Find your Ralph app → Incoming Webhooks
3. Delete old webhook
4. Add new webhook to workspace
5. Update `~/.ralph.env` with new URL
6. Reload: `source ~/.ralph.env`

### Discord Notifications Failing

**Symptoms:**
```
Discord: FAILED
```

**Diagnosis:**

Test webhook:
```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"content":"Test"}' \
  "$RALPH_DISCORD_WEBHOOK_URL"
```

**Common Issues:**

| Issue | Solution |
|:------|:---------|
| Rate limited | Wait 1 minute, Discord has rate limits |
| Webhook deleted | Recreate in Discord channel settings |
| Invalid URL | Check URL format: `https://discord.com/api/webhooks/ID/TOKEN` |

### Telegram Notifications Failing

**Symptoms:**
```
Telegram: FAILED
```

**Diagnosis:**

Test bot:
```bash
curl "https://api.telegram.org/bot${RALPH_TELEGRAM_BOT_TOKEN}/getMe"
```

Should return bot info.

**Common Issues:**

| Issue | Solution |
|:------|:---------|
| Invalid token | Recreate bot with @BotFather |
| Wrong chat ID | Get fresh chat ID from getUpdates |
| Bot blocked | Unblock bot in Telegram |
| Bot not in group | Add bot to group and get new chat ID |

**Get correct chat ID:**

1. Send message to bot
2. Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
3. Find `"chat":{"id":YOUR_ID}` in JSON
4. Update `~/.ralph.env`

---

## Performance Issues

### Ralph Is Slow

**Symptoms:**
- Each iteration takes many minutes
- Lots of "searching codebase" time

**Causes & Solutions:**

#### 1. Large Codebase

**Solution:** Add `.gitignore` patterns to skip:
```gitignore
node_modules/
vendor/
dist/
build/
*.min.js
```

#### 2. Complex Tasks

**Solution:** Break tasks into smaller steps in progress file:
```markdown
- [ ] Task 1: Setup auth (big task)
```
↓
```markdown
- [ ] Task 1.1: Add auth dependency
- [ ] Task 1.2: Create auth middleware
- [ ] Task 1.3: Add tests
```

#### 3. Expensive Tests

**Solution:** Skip slow tests during development:
```bash
# In your plan file
## Testing Notes
Skip integration tests during build, run manually at end.
```

### Monitor Using Too Much CPU

**Symptoms:**
`monitor-progress.sh` consuming significant CPU.

**Cause:** Checking too frequently or scanning large directory.

**Solution:**

1. Increase interval:
   ```bash
   # Instead of every 30s
   ~/ralph/start-monitor.sh 30

   # Use every 5 minutes
   ~/ralph/start-monitor.sh 300
   ```

2. Limit scope:
   ```bash
   # Monitor specific directory only
   ~/ralph/monitor-progress.sh 300 ~/my-project
   ```

---

## Git Issues

### Auto-Commit Disabled When You Want It

**Symptoms:**
```
Commit: disabled (disabled via config)
```

**Solution:**

Re-enable auto-commit:
```bash
ralph config commit on
```

Or check your plan file for `DO_NOT_COMMIT` directive and remove it.

### Commit Conflicts

**Symptoms:**
```
error: Your local changes to the following files would be overwritten by merge:
```

**Cause:** Ralph running in a repo with uncommitted changes.

**Solution:**

1. Stash your changes:
   ```bash
   git stash
   ```

2. Run Ralph:
   ```bash
   ralph ./plan.md build
   ```

3. Reapply your changes:
   ```bash
   git stash pop
   ```

### Too Many Commits

**Symptoms:**
Ralph created 50 commits and you want them squashed.

**Solution:**

Squash commits after Ralph finishes:
```bash
# Interactive rebase last 50 commits
git rebase -i HEAD~50

# In editor, change "pick" to "squash" (or "s") for all but first commit
# Save and close

# Update commit message
# Force push if already pushed (use with caution):
git push --force
```

---

## Configuration Issues

### Environment Variables Not Loaded

**Symptoms:**
```bash
$ echo $RALPH_SLACK_WEBHOOK_URL

# Empty output
```

**Cause:** `~/.ralph.env` not sourced in current shell.

**Solution:**

1. Source manually:
   ```bash
   source ~/.ralph.env
   ```

2. Add to shell profile permanently:
   ```bash
   echo 'source ~/.ralph.env' >> ~/.bashrc
   source ~/.bashrc
   ```

3. Verify it loads on new shell:
   ```bash
   bash  # Start new shell
   echo $RALPH_SLACK_WEBHOOK_URL  # Should show URL
   ```

### Config File Permission Errors

**Symptoms:**
```
Warning: Syntax error in ~/.ralph.env
```

**Cause:** Config file malformed or has wrong permissions.

**Solution:**

1. Check syntax:
   ```bash
   bash -n ~/.ralph.env
   ```

2. Fix permissions:
   ```bash
   chmod 600 ~/.ralph.env
   ```

3. If corrupt, regenerate:
   ```bash
   ralph notify setup
   ```

---

## Update Issues

### Update Fails

**Symptoms:**
```
✖ Failed to download version v1.6.0
```

**Possible Causes:**

1. **Network issue:**
   ```bash
   # Test connectivity
   curl -I https://github.com
   ```

2. **Behind proxy:**
   ```bash
   export http_proxy="http://proxy.company.com:8080"
   export https_proxy="http://proxy.company.com:8080"
   ralph update
   ```

3. **Git not found:**
   ```bash
   # Install git
   sudo apt-get install git  # Ubuntu/Debian
   brew install git          # macOS
   ```

### Rollback Not Available

**Symptoms:**
```
✖ No backup found. Cannot rollback.
```

**Cause:** Rollback only works after an update (there's nothing to rollback to).

**Solution:**

Install specific version manually:
```bash
ralph update 1.5.0
```

### Version Mismatch

**Symptoms:**
```bash
$ ralph --version
PortableRalph v1.5.0

$ ralph update --check
Latest version: 1.6.0
```
But you just updated!

**Cause:** Shell cached old version or alias pointing to wrong location.

**Solution:**

1. Reload shell:
   ```bash
   hash -r  # Clear command cache
   source ~/.bashrc
   ```

2. Check alias:
   ```bash
   alias ralph
   # Should point to ~/ralph/ralph.sh
   ```

3. Verify file updated:
   ```bash
   grep "VERSION=" ~/ralph/ralph.sh
   ```

---

## Progress File Issues

### Progress File Corrupted

**Symptoms:**
- Ralph behaves erratically
- Tasks appear and disappear
- Status keeps changing

**Solution:**

1. Backup current file:
   ```bash
   cp my-plan_PROGRESS.md my-plan_PROGRESS.md.bak
   ```

2. Check for common issues:
   ```bash
   # Check for multiple Status sections
   grep -n "## Status" my-plan_PROGRESS.md

   # Check for stray RALPH_DONE markers
   grep -n "RALPH_DONE" my-plan_PROGRESS.md
   ```

3. If too corrupted, regenerate:
   ```bash
   rm my-plan_PROGRESS.md
   ralph ./my-plan.md plan
   ```

### Task Checkboxes Not Recognized

**Symptoms:**
Ralph doesn't detect completed tasks.

**Cause:** Wrong checkbox format.

**Wrong:**
```markdown
- [X] Task done (capital X)
- [✓] Task done (checkmark)
- [ x ] Task done (spaces)
```

**Correct:**
```markdown
- [x] Task done (lowercase x, no spaces)
- [ ] Task todo (space, no spaces around)
```

---

## Advanced Troubleshooting

### Enable Debug Output

Add verbose flags to Ralph commands:

```bash
# Run Claude with verbose output
# Edit ~/ralph/ralph.sh temporarily:
echo "$PROMPT" | claude -p \
    --dangerously-skip-permissions \
    --model sonnet \
    --verbose 2>&1
```

### Capture Full Logs

```bash
# Redirect all output to file
ralph ./plan.md build 2>&1 | tee ralph_debug.log
```

### Check System Resources

```bash
# Disk space
df -h

# Memory
free -h

# CPU usage
top -b -n 1 | head -20

# Process limits
ulimit -a
```

### Network Diagnostics

```bash
# Test GitHub connectivity
curl -I https://api.github.com

# Test Slack
curl -I https://hooks.slack.com

# DNS resolution
nslookup api.slack.com
```

---

## Windows-Specific Issues

PortableRalph's Windows support is CI-verified via GitHub Actions. If you encounter issues, check the [Windows CI workflow](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml) for the latest compatibility status.

### PowerShell Execution Policy Blocking Scripts

**Symptoms:**
```
.\ralph.ps1 : File cannot be loaded because running scripts is disabled on this system.
```

**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify the change
Get-ExecutionPolicy -List
```

### Line Ending Errors (`'\r': command not found`)

**Symptoms:**
```bash
bash: '\r': command not found
$'\r': command not found
```

**Cause:** Windows CRLF line endings in bash scripts.

**Solution:**
```bash
# Configure git to handle line endings automatically
git config --global core.autocrlf input

# Re-clone the repository
rm -rf ~/ralph
git clone https://github.com/aaron777collins/portableralph.git ~/ralph

# Or fix existing files
cd ~/ralph
find . -name "*.sh" -exec sed -i 's/\r$//' {} \;
```

### PowerShell Script Syntax Errors

**Diagnosis:**
```powershell
# Test script syntax without executing
$content = Get-Content "ralph.ps1" -Raw
$errors = @()
[System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
$errors | ForEach-Object { Write-Host $_.Message }
```

**Solution:**
- Pull the latest version: `git pull`
- Check the [CI status](https://github.com/aaron777collins/portableralph/actions/workflows/windows-test.yml) to confirm the scripts pass validation

### launcher.bat Issues

**Symptoms:**
`launcher.bat` fails or doesn't invoke PowerShell correctly.

**Diagnosis:**
```cmd
REM Check if launcher.bat exists and is readable
type launcher.bat | find /c ""

REM Test manually
call launcher.bat --help
echo Exit code: %ERRORLEVEL%
```

**Solutions:**
1. Use PowerShell directly instead:
   ```powershell
   .\ralph.ps1 .\plan.md
   ```
2. Verify file line endings are CRLF for `.bat` files
3. Re-clone repository with proper line ending handling

### Claude CLI Not Found on Windows

**Symptoms:**
```
'claude' is not recognized as an internal or external command
```

**Solution:**
1. Verify Claude Code CLI is installed
2. Check if claude is in PATH:
   ```powershell
   $env:PATH -split ";" | Where-Object { $_ -like "*claude*" }
   ```
3. Add Claude to PATH manually if needed:
   ```powershell
   # Add to current session
   $env:PATH += ";$env:USERPROFILE\.local\bin"
   
   # Add permanently (PowerShell profile)
   Add-Content $PROFILE '$env:PATH += ";$env:USERPROFILE\.local\bin"'
   ```

### Path Issues Between WSL and Windows

**Symptoms:**
- Files not found when using Windows paths in WSL
- `C:\Users\...` paths fail in bash

**Solution:**
```bash
# In WSL, use /mnt/c/ prefix for Windows drives
cd /mnt/c/Users/YourName/project
ralph ./plan.md

# Convert paths
# Windows: C:\Users\name\project
# WSL:     /mnt/c/Users/name/project
```

### Windows Antivirus Blocking Scripts

**Symptoms:**
- Scripts hang or fail silently
- Access denied errors intermittently

**Solution:**
1. Add exclusion for the ralph directory:
   - Open Windows Security → Virus & threat protection
   - Manage settings → Add exclusion → Folder
   - Select `C:\Users\YourName\ralph`

2. Or use Windows Defender exclusion via PowerShell:
   ```powershell
   # Run as Administrator
   Add-MpExclusion -Path "$env:USERPROFILE\ralph"
   ```

### UTF-8 Encoding Issues

**Symptoms:**
- Strange characters in output
- Unicode errors in plan files

**Solution:**
```powershell
# Set UTF-8 encoding in PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Add to PowerShell profile for persistence
Add-Content $PROFILE @"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
"@
```

### Windows-Specific Diagnostics

Run this diagnostic script for Windows issues:

```powershell
Write-Host "=== Windows Ralph Diagnostic ===" -ForegroundColor Cyan

# System info
Write-Host "`nSystem:" -ForegroundColor Yellow
Write-Host "  OS: $([System.Environment]::OSVersion.VersionString)"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "  Execution Policy: $(Get-ExecutionPolicy)"

# Check Claude CLI
Write-Host "`nClaude CLI:" -ForegroundColor Yellow
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) { 
    Write-Host "  ✅ Found at: $($claude.Source)"
} else { 
    Write-Host "  ❌ Not found in PATH" 
}

# Check Git
Write-Host "`nGit:" -ForegroundColor Yellow
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) { 
    Write-Host "  ✅ Found at: $($git.Source)"
} else { 
    Write-Host "  ❌ Not found" 
}

# Check Ralph files
Write-Host "`nRalph Installation:" -ForegroundColor Yellow
$ralphDir = "$env:USERPROFILE\ralph"
if (Test-Path $ralphDir) {
    Write-Host "  ✅ Ralph directory: $ralphDir"
    Write-Host "  Files:"
    Get-ChildItem $ralphDir -Filter "*.ps1" | ForEach-Object { Write-Host "    - $($_.Name)" }
} else {
    Write-Host "  ❌ Ralph not found at $ralphDir"
}

# Check config
Write-Host "`nConfiguration:" -ForegroundColor Yellow
$configPath = "$env:USERPROFILE\.ralph.env"
if (Test-Path $configPath) {
    Write-Host "  ✅ Config found: $configPath"
} else {
    Write-Host "  ⚠️ No config file (optional)"
}

Write-Host "`n=== End Diagnostic ===" -ForegroundColor Cyan
```

For more detailed Windows setup instructions, see [Windows Setup Guide](WINDOWS_SETUP.md).

---

## Getting Help

If you've tried the above and still have issues:

### 1. Check Existing Issues

Search GitHub issues: [github.com/aaron777collins/portableralph/issues](https://github.com/aaron777collins/portableralph/issues)

### 2. Gather Information

Before reporting, collect:

```bash
# Version info
ralph --version

# System info
uname -a
cat /etc/os-release

# Configuration (sanitized)
cat ~/.ralph.env | sed 's/hooks.slack.com.*/hooks.slack.com\/REDACTED/'

# Recent logs
tail -100 monitor.log
```

### 3. Create Minimal Reproduction

Create a simple plan file that reproduces the issue:

```markdown
# Test Plan

## Goal
Demonstrate the issue

## Steps
1. Run ralph ./test-plan.md plan
2. Observe error: [describe what goes wrong]
```

### 4. Report Issue

Open a new issue with:
- Clear title: "Build mode exits immediately on macOS"
- Ralph version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs (sanitized)

---

## See Also

- [Usage Guide](usage.md) - Command reference
- [Notifications](notifications.md) - Setup help
- [Security Guide](SECURITY.md) - Best practices
- [GitHub Issues](https://github.com/aaron777collins/portableralph/issues) - Known issues

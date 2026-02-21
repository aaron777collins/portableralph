# Troubleshooting Guide

This comprehensive troubleshooting guide helps you resolve common issues with PortableRalph based on real-world usage patterns and findings from code quality reviews.

## Quick Diagnostics

Run these commands to get instant diagnostic information:

```bash
# Test Ralph installation
ralph --help

# Test Claude CLI connection
claude --version

# Test notification setup
ralph notify test

# Check environment
env | grep RALPH
```

## Common Issues by Platform

### Windows Issues

#### PowerShell Execution Policy Errors

**Problem:**
```
.\ralph.ps1 : File .\ralph.ps1 cannot be loaded because running scripts is disabled on this system.
```

**Solutions:**
```powershell
# For current user only (recommended)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# For current session only (temporary)
Set-ExecutionPolicy Bypass -Scope Process

# Check current policy
Get-ExecutionPolicy -List
```

**Prevention:**
- Set execution policy during installation
- Document policy requirements for team members
- Use `-ExecutionPolicy Bypass` for automated environments

#### Line Ending Issues

**Problem:**
```bash
./ralph.sh: line 1: #!/bin/bash^M: No such file or directory
```

**Cause:** Windows CRLF line endings in Unix environment (Git Bash/WSL)

**Solutions:**
```bash
# Fix immediately
dos2unix ralph.sh

# Configure Git for proper line endings
git config --global core.autocrlf input

# Re-clone repository
rm -rf ~/ralph
git clone https://github.com/aaron777collins/portableralph.git ~/ralph
```

**Prevention:**
- Use `.gitattributes` file (already included)
- Configure Git properly during setup
- Use consistent development environment

#### Path Resolution Issues

**Problem:**
- PowerShell scripts can't find files
- Unix paths don't work in Windows
- Environment variables not expanded

**Solutions:**
```powershell
# PowerShell path handling
$RalphPath = Join-Path $env:USERPROFILE "ralph"
$PlanFile = Join-Path (Get-Location) "plan.md"

# Use PowerShell path cmdlets
$AbsolutePath = Resolve-Path ".\plan.md"
$RelativePath = (Get-Item "plan.md").FullName
```

**Best Practices:**
- Use `Join-Path` for cross-platform compatibility
- Avoid hardcoded path separators
- Use environment variables for home directory

#### Windows Defender / Antivirus Issues

**Problem:**
- Scripts blocked by Windows Defender
- False positive malware detection
- Performance issues due to real-time scanning

**Solutions:**
```powershell
# Add exclusion for Ralph directory (run as Administrator)
Add-MpPreference -ExclusionPath "$env:USERPROFILE\ralph"

# Exclude specific file types
Add-MpPreference -ExclusionExtension ".ps1"
Add-MpPreference -ExclusionExtension ".sh"
```

**Alternative:**
- Use Windows Security GUI to add exclusions
- Whitelist based on hash rather than path
- Configure enterprise antivirus policies

### Unix/Linux/macOS Issues

#### Permission Denied Errors

**Problem:**
```bash
bash: ./ralph.sh: Permission denied
```

**Solutions:**
```bash
# Make scripts executable
chmod +x ~/ralph/*.sh

# Fix all shell scripts at once
find ~/ralph -name "*.sh" -exec chmod +x {} \;

# Alternative: run with bash explicitly
bash ~/ralph/ralph.sh plan.md
```

**Prevention:**
- Include in installation documentation
- Add permission checks to install script
- Use `chmod +x` in Git hooks

#### Command Not Found

**Problem:**
```bash
ralph: command not found
```

**Solutions:**
```bash
# Add alias to shell profile
echo 'alias ralph="$HOME/ralph/ralph.sh"' >> ~/.bashrc
source ~/.bashrc

# Or add to PATH
echo 'export PATH="$HOME/ralph:$PATH"' >> ~/.bashrc

# For zsh users
echo 'alias ralph="$HOME/ralph/ralph.sh"' >> ~/.zshrc
```

**Verification:**
```bash
# Test the alias
which ralph
ralph --help
```

#### macOS Gatekeeper Issues

**Problem:**
- "ralph.sh is from an unidentified developer"
- Scripts blocked by macOS security

**Solutions:**
```bash
# Remove quarantine attribute
xattr -dr com.apple.quarantine ~/ralph/

# Allow specific script
spctl --add ~/ralph/ralph.sh

# System Preferences approach
# System Preferences → Security & Privacy → Allow apps downloaded from "Anywhere"
```

## Installation Issues

### Download/Clone Failures

**Problem:**
- Network connectivity issues
- SSL/TLS certificate problems
- Git authentication failures

**Diagnostics:**
```bash
# Test GitHub connectivity
curl -I https://github.com/aaron777collins/portableralph

# Test Git access
git ls-remote https://github.com/aaron777collins/portableralph.git

# Check SSL certificates
curl -vI https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh
```

**Solutions:**
```bash
# Use different Git transport
git clone git@github.com:aaron777collins/portableralph.git ~/ralph

# Download as zip instead
curl -L https://github.com/aaron777collins/portableralph/archive/refs/heads/master.zip -o ralph.zip
unzip ralph.zip
mv portableralph-master ~/ralph
```

### Dependency Issues

#### Claude CLI Not Found

**Problem:**
```bash
claude: command not found
```

**Installation:**
```bash
# Install Claude CLI (official method)
curl -fsSL https://raw.githubusercontent.com/anthropics/claude-cli/main/install.sh | bash

# Verify installation
claude --version

# Configure authentication
claude auth login
```

**Alternative Methods:**
```bash
# Using Node.js
npm install -g @anthropic-ai/claude-cli

# Using Python
pip install claude-cli

# Manual download
wget https://github.com/anthropics/claude-cli/releases/latest/download/claude-linux-amd64
chmod +x claude-linux-amd64
sudo mv claude-linux-amd64 /usr/local/bin/claude
```

#### Git Not Available

**Problem:**
- Git commands fail
- Repository operations don't work

**Installation:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install git

# CentOS/RHEL
sudo yum install git

# macOS
brew install git
# or use Xcode Command Line Tools
xcode-select --install

# Windows
# Download from https://git-scm.com/download/win
```

### Configuration Issues

#### API Key Problems

**Problem:**
- Authentication failures with Claude API
- Invalid or expired API keys

**Diagnostics:**
```bash
# Test API key
echo $CLAUDE_API_KEY

# Test Claude CLI connection
claude models list
```

**Solutions:**
```bash
# Set API key properly
export CLAUDE_API_KEY="your-api-key-here"

# Add to shell profile
echo 'export CLAUDE_API_KEY="your-api-key-here"' >> ~/.bashrc

# Use Claude CLI authentication
claude auth login
```

**Security Best Practices:**
```bash
# Create secure config file
touch ~/.ralph.env
chmod 600 ~/.ralph.env
echo 'CLAUDE_API_KEY=your-key-here' >> ~/.ralph.env
```

## Runtime Issues

### Task Execution Problems

#### Tasks Repeating Endlessly

**Problem:**
- Ralph keeps processing the same task
- Progress file not updating correctly
- Infinite loop behavior

**Diagnostics:**
```bash
# Check progress file format
cat progress.md

# Look for task completion markers
grep -n "RALPH_DONE\|completed\|finished" progress.md

# Check for syntax errors
head -20 progress.md | cat -A
```

**Solutions:**
```bash
# Fix task completion markers
# Add to progress file:
- [x] Task 1 - Description

# Or mark overall completion:
echo "RALPH_DONE" >> progress.md

# Restart with fresh progress
mv progress.md progress.backup.md
ralph plan.md plan  # Regenerate tasks
```

**Prevention:**
- Use clear task descriptions
- Verify progress file format
- Set reasonable iteration limits

#### File Permission Errors

**Problem:**
- Can't write to progress files
- Can't create temporary files
- Directory access denied

**Solutions:**
```bash
# Fix directory permissions
chmod 755 .
chmod 644 *.md

# Check disk space
df -h .

# Fix ownership issues
sudo chown -R $(whoami) ~/ralph
```

### Network Issues

#### Webhook/Notification Failures

**Problem:**
- Slack/Discord notifications not sending
- Network timeouts
- SSL certificate errors

**Diagnostics:**
```bash
# Test webhook URL
curl -X POST $RALPH_SLACK_WEBHOOK_URL -d '{"text":"test"}'

# Check network connectivity
ping google.com

# Test SSL connectivity
openssl s_client -connect hooks.slack.com:443
```

**Solutions:**
```bash
# Use curl with verbose output
export RALPH_DEBUG=true
ralph notify test

# Test with different webhook URL
# Regenerate webhook in Slack/Discord if needed

# Check proxy settings
echo $http_proxy
echo $https_proxy
```

### Performance Issues

#### Slow Execution

**Problem:**
- Ralph takes very long to complete tasks
- High CPU or memory usage
- System becomes unresponsive

**Diagnostics:**
```bash
# Monitor resource usage
top -p $(pgrep -f ralph)

# Check disk I/O
iotop -p $(pgrep -f ralph)

# Profile execution time
time ralph plan.md build 1
```

**Solutions:**
```bash
# Reduce iteration count
ralph plan.md build 10

# Enable debug mode to see where time is spent
export RALPH_DEBUG=true
ralph plan.md build 1

# Check for large files in working directory
du -sh * | sort -hr | head -10
```

**Performance Tuning:**
```bash
# Set resource limits
ulimit -m 1048576  # 1GB memory limit
ulimit -t 3600     # 1 hour CPU limit

# Use nice for lower priority
nice -n 10 ralph plan.md build
```

## Platform-Specific Issues

### WSL (Windows Subsystem for Linux) Issues

#### Path Translation Problems

**Problem:**
- Windows paths don't work in WSL
- File system permissions inconsistent
- Line ending conflicts

**Solutions:**
```bash
# Use WSL path translation
cd /mnt/c/Users/YourName/Documents

# Fix permissions for WSL
sudo mount -t drvfs C: /mnt/c -o metadata,uid=1000,gid=1000,umask=22

# Configure Git for WSL
git config --global core.autocrlf input
git config --global core.filemode false
```

#### Performance Issues in WSL

**Problem:**
- Slow file operations
- High CPU usage
- Network timeouts

**Solutions:**
```bash
# Use WSL 2 instead of WSL 1
wsl --set-version Ubuntu 2

# Store files in WSL file system, not Windows
mkdir ~/projects
cd ~/projects
git clone https://github.com/aaron777collins/portableralph.git

# Optimize WSL configuration
# Add to /etc/wsl.conf:
[automount]
options = "metadata,umask=22,fmask=11"
```

### Docker/Container Issues

#### Container Runtime Problems

**Problem:**
- Ralph doesn't work in Docker containers
- Permission issues in containerized environments
- Network connectivity problems

**Solutions:**
```dockerfile
# Use proper base image
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash ralph
USER ralph

# Set proper working directory
WORKDIR /home/ralph
```

**Docker Compose:**
```yaml
version: '3.8'
services:
  ralph:
    build: .
    environment:
      - CLAUDE_API_KEY=${CLAUDE_API_KEY}
    volumes:
      - ./projects:/home/ralph/projects:rw
    user: "1000:1000"
```

## Advanced Troubleshooting

### Debug Mode

Enable comprehensive debugging:

```bash
# Enable debug output
export RALPH_DEBUG=true

# Enable trace mode (very verbose)
export RALPH_TRACE=true

# Save debug output to file
export RALPH_LOG_FILE="ralph-debug.log"

# Run with debugging
ralph plan.md build 1 2>&1 | tee debug.log
```

### Log Analysis

```bash
# Find error patterns
grep -i error ralph-debug.log

# Check for timeouts
grep -i timeout ralph-debug.log

# Look for API issues
grep -i "api\|http\|curl" ralph-debug.log

# Analyze timing
grep -E "^\[.*\]" ralph-debug.log
```

### System Information Collection

Create a diagnostic report:

```bash
#!/bin/bash
# create-diagnostic-report.sh

echo "=== Ralph Diagnostic Report ===" > diagnostic.txt
echo "Date: $(date)" >> diagnostic.txt
echo "System: $(uname -a)" >> diagnostic.txt
echo "Shell: $SHELL" >> diagnostic.txt

echo -e "\n=== Ralph Installation ===" >> diagnostic.txt
ls -la ~/ralph/ >> diagnostic.txt 2>&1

echo -e "\n=== Environment Variables ===" >> diagnostic.txt
env | grep RALPH >> diagnostic.txt

echo -e "\n=== Claude CLI ===" >> diagnostic.txt
which claude >> diagnostic.txt 2>&1
claude --version >> diagnostic.txt 2>&1

echo -e "\n=== Git Configuration ===" >> diagnostic.txt
git --version >> diagnostic.txt 2>&1
git config --list | grep -E "(user|core)" >> diagnostic.txt 2>&1

echo -e "\n=== Disk Space ===" >> diagnostic.txt
df -h . >> diagnostic.txt 2>&1

echo -e "\n=== Recent Errors ===" >> diagnostic.txt
tail -50 ralph-debug.log >> diagnostic.txt 2>&1

echo "Diagnostic report saved to diagnostic.txt"
```

## Getting Help

### Self-Help Resources

1. **Check the logs:** Most issues leave traces in debug output
2. **Search GitHub issues:** Many problems have been solved already
3. **Review documentation:** README, TESTING.md, and code comments
4. **Test minimal examples:** Isolate the problem with simple test cases

### Community Support

1. **GitHub Issues:** [Create new issue](https://github.com/aaron777collins/portableralph/issues/new)
2. **Discussions:** [Ask questions](https://github.com/aaron777collins/portableralph/discussions)
3. **Security Issues:** Follow responsible disclosure in SECURITY.md

### Issue Reporting Template

When reporting issues, include:

```markdown
**Environment:**
- OS: [Windows 11 / Ubuntu 22.04 / macOS 13]
- Shell: [PowerShell 7.2 / Bash 5.1 / Zsh]
- Ralph Version: [git commit hash]
- Claude CLI Version: [version number]

**Problem:**
[Describe what you were trying to do]

**Expected Behavior:**
[What should have happened]

**Actual Behavior:**
[What actually happened]

**Steps to Reproduce:**
1. [First step]
2. [Second step]
3. [etc.]

**Error Messages:**
```
[Copy/paste any error messages here]
```

**Additional Context:**
[Any other relevant information]
```

### Preventive Measures

1. **Regular Updates:** Keep Ralph and dependencies updated
2. **Environment Testing:** Test changes in isolated environments first
3. **Backup Configurations:** Keep copies of working configurations
4. **Monitor Resources:** Watch disk space and memory usage
5. **Documentation:** Document custom configurations and workarounds
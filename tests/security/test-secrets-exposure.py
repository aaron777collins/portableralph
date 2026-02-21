#!/usr/bin/env python3
"""
Secrets Exposure Security Tests for PortableRalph
Scans for hardcoded secrets, credential leaks, and sensitive data exposure
"""

import subprocess
import tempfile
import os
import sys
import re
import json
import base64
from pathlib import Path

# Add repo root to path to import test utilities
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

class SecretsExposureTests:
    def __init__(self):
        self.repo_root = REPO_ROOT
        self.test_dir = None
        self.results = []
        self.failed_tests = 0
        self.total_tests = 0
        
        # Common secret patterns to detect
        self.secret_patterns = {
            'api_key': [
                r'sk-ant-api\d+-[a-zA-Z0-9-_]{64,}',  # Claude API keys
                r'["\']?api[_-]?key["\']?\s*[:=]\s*["\'][a-zA-Z0-9-_]{16,}["\']',
                r'["\']?apikey["\']?\s*[:=]\s*["\'][a-zA-Z0-9-_]{16,}["\']',
            ],
            'webhook_url': [
                r'https://hooks\.slack\.com/services/[A-Z0-9/]+',
                r'https://discord\.com/api/webhooks/[0-9]+/[a-zA-Z0-9_-]+',
                r'https://api\.telegram\.org/bot[0-9]+:[a-zA-Z0-9_-]+',
            ],
            'password': [
                r'["\']?password["\']?\s*[:=]\s*["\'][^"\']{4,}["\']',
                r'["\']?passwd["\']?\s*[:=]\s*["\'][^"\']{4,}["\']',
                r'["\']?pwd["\']?\s*[:=]\s*["\'][^"\']{4,}["\']',
            ],
            'token': [
                r'["\']?token["\']?\s*[:=]\s*["\'][a-zA-Z0-9-_]{16,}["\']',
                r'["\']?auth[_-]?token["\']?\s*[:=]\s*["\'][a-zA-Z0-9-_]{16,}["\']',
                r'bearer\s+[a-zA-Z0-9-_]{16,}',
            ],
            'secret': [
                r'["\']?secret["\']?\s*[:=]\s*["\'][^"\']{8,}["\']',
                r'["\']?client[_-]?secret["\']?\s*[:=]\s*["\'][^"\']{8,}["\']',
            ],
            'private_key': [
                r'-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----',
                r'-----BEGIN\s+OPENSSH\s+PRIVATE\s+KEY-----',
            ]
        }
        
        # Files that should never contain secrets
        self.sensitive_locations = [
            'README.md',
            'CHANGELOG.md',
            '*.log',
            '*.txt',
            'docs/*.md'
        ]

    def setup(self):
        """Setup test environment"""
        self.test_dir = tempfile.mkdtemp(prefix="ralph_secrets_test_")
        return self.test_dir

    def teardown(self):
        """Cleanup test environment"""
        if self.test_dir and os.path.exists(self.test_dir):
            subprocess.run(['rm', '-rf', self.test_dir], check=False)

    def run_test(self, test_name, test_func):
        """Run a single test and record results"""
        self.total_tests += 1
        try:
            test_func()
            self.results.append(f"✅ {test_name}: PASS")
            print(f"✅ {test_name}: PASS")
        except Exception as e:
            self.failed_tests += 1
            self.results.append(f"❌ {test_name}: FAIL - {str(e)}")
            print(f"❌ {test_name}: FAIL - {str(e)}")

    def scan_file_for_secrets(self, file_path, patterns):
        """Scan a single file for secret patterns"""
        findings = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                
            for secret_type, pattern_list in patterns.items():
                for pattern in pattern_list:
                    matches = re.finditer(pattern, content, re.IGNORECASE | re.MULTILINE)
                    for match in matches:
                        line_num = content[:match.start()].count('\n') + 1
                        findings.append({
                            'file': file_path,
                            'type': secret_type,
                            'line': line_num,
                            'match': match.group(),
                            'pattern': pattern
                        })
                        
        except Exception as e:
            # Skip binary files or files with encoding issues
            pass
            
        return findings

    def test_hardcoded_api_keys(self):
        """Test for hardcoded API keys in source files"""
        script_files = []
        for ext in ['*.sh', '*.ps1', '*.py', '*.js', '*.ts', '*.json', '*.yaml', '*.yml']:
            result = subprocess.run(['find', str(self.repo_root), '-name', ext, '-type', 'f'], 
                                  capture_output=True, text=True)
            script_files.extend(result.stdout.strip().split('\n'))
        
        # Filter out empty results and test files
        script_files = [f for f in script_files if f and 'tests/' not in f]
        
        api_key_patterns = {
            'claude_api_key': self.secret_patterns['api_key'],
            'general_api_key': [r'["\']?api[_-]?key["\']?\s*[:=]\s*["\'][a-zA-Z0-9]{20,}["\']']
        }
        
        findings = []
        for file_path in script_files:
            if os.path.exists(file_path):
                file_findings = self.scan_file_for_secrets(file_path, api_key_patterns)
                findings.extend(file_findings)
        
        # Filter out false positives (example keys, variable names, etc.)
        real_findings = []
        false_positive_indicators = [
            'example', 'test', 'dummy', 'placeholder', 'your_key_here',
            'api_key_here', 'sk-ant-api03-XXXXXXXX', 'xxx', '***',
            'TODO', 'FIXME', 'replace_with', 'insert_your'
        ]
        
        for finding in findings:
            is_false_positive = any(indicator.lower() in finding['match'].lower() 
                                  for indicator in false_positive_indicators)
            if not is_false_positive:
                real_findings.append(finding)
        
        if real_findings:
            raise Exception(f"Found {len(real_findings)} potential hardcoded API keys: {real_findings[0]}")

    def test_hardcoded_webhook_urls(self):
        """Test for hardcoded webhook URLs in source files"""
        all_files = []
        result = subprocess.run(['find', str(self.repo_root), '-type', 'f', '-name', '*.sh', 
                                '-o', '-name', '*.ps1', '-o', '-name', '*.md', '-o', '-name', '*.txt'], 
                              capture_output=True, text=True)
        all_files = [f for f in result.stdout.strip().split('\n') if f and 'tests/' not in f]
        
        webhook_patterns = {
            'webhook_urls': self.secret_patterns['webhook_url']
        }
        
        findings = []
        for file_path in all_files:
            if os.path.exists(file_path):
                file_findings = self.scan_file_for_secrets(file_path, webhook_patterns)
                findings.extend(file_findings)
        
        # Filter out documentation examples
        real_findings = []
        doc_indicators = ['example', 'replace_with', 'your_webhook', 'WEBHOOK_URL', 'xxx', '***']
        
        for finding in findings:
            is_documentation = any(indicator in finding['match'] for indicator in doc_indicators)
            # Also check if it's in a documentation file
            is_doc_file = any(doc_path in finding['file'] for doc_path in ['README', 'docs/', 'CHANGELOG'])
            
            if not (is_documentation or is_doc_file):
                real_findings.append(finding)
        
        if real_findings:
            raise Exception(f"Found {len(real_findings)} potential hardcoded webhook URLs")

    def test_exposed_passwords(self):
        """Test for exposed passwords in configuration files"""
        config_files = []
        result = subprocess.run(['find', str(self.repo_root), '-name', '*.env*', '-o', '-name', '*.conf',
                                '-o', '-name', '*.config', '-o', '-name', '*.ini'], 
                              capture_output=True, text=True)
        config_files = [f for f in result.stdout.strip().split('\n') if f]
        
        password_patterns = {
            'passwords': self.secret_patterns['password']
        }
        
        findings = []
        for file_path in config_files:
            if os.path.exists(file_path):
                file_findings = self.scan_file_for_secrets(file_path, password_patterns)
                findings.extend(file_findings)
        
        # Filter out example files
        real_findings = []
        for finding in findings:
            if '.example' not in finding['file'] and 'template' not in finding['file'].lower():
                real_findings.append(finding)
        
        if real_findings:
            raise Exception(f"Found {len(real_findings)} potential exposed passwords")

    def test_private_keys_exposure(self):
        """Test for exposed private keys"""
        all_files = []
        result = subprocess.run(['find', str(self.repo_root), '-type', 'f'], 
                              capture_output=True, text=True)
        all_files = [f for f in result.stdout.strip().split('\n') if f and 'tests/' not in f]
        
        key_patterns = {
            'private_keys': self.secret_patterns['private_key']
        }
        
        findings = []
        for file_path in all_files:
            if os.path.exists(file_path) and os.path.getsize(file_path) < 1024 * 1024:  # Skip large files
                file_findings = self.scan_file_for_secrets(file_path, key_patterns)
                findings.extend(file_findings)
        
        if findings:
            raise Exception(f"Found {len(findings)} potential private key exposures")

    def test_git_history_secrets(self):
        """Test for secrets in git history"""
        # Only test if we're in a git repository
        if not (self.repo_root / '.git').exists():
            return
            
        try:
            # Get all commits
            result = subprocess.run(['git', 'log', '--all', '--full-history', '--grep=password', 
                                   '--grep=secret', '--grep=key', '--oneline'], 
                                  cwd=self.repo_root, capture_output=True, text=True)
            
            suspicious_commits = result.stdout.strip().split('\n')
            suspicious_commits = [line for line in suspicious_commits if line.strip()]
            
            if len(suspicious_commits) > 0:
                print(f"⚠️  Warning: Found {len(suspicious_commits)} commits with suspicious keywords")
                for commit in suspicious_commits[:3]:  # Show first 3
                    print(f"    {commit}")
                    
            # Check for large file additions (might be secrets)
            result = subprocess.run(['git', 'log', '--all', '--numstat', '--pretty=format:', '--since=1.year.ago'], 
                                  cwd=self.repo_root, capture_output=True, text=True)
            
            large_additions = []
            for line in result.stdout.split('\n'):
                if line.strip() and '\t' in line:
                    parts = line.split('\t')
                    if len(parts) >= 3 and parts[0].isdigit():
                        additions = int(parts[0])
                        if additions > 10000:  # Very large addition
                            large_additions.append(line)
            
            if large_additions:
                print(f"⚠️  Warning: Found {len(large_additions)} commits with large file additions")
                
        except Exception as e:
            print(f"⚠️  Could not scan git history: {e}")

    def test_environment_variable_exposure(self):
        """Test for environment variables that might expose secrets"""
        script_files = []
        result = subprocess.run(['find', str(self.repo_root), '-name', '*.sh', '-o', '-name', '*.ps1'], 
                              capture_output=True, text=True)
        script_files = [f for f in result.stdout.strip().split('\n') if f and 'tests/' not in f]
        
        dangerous_env_patterns = [
            r'export\s+[A-Z_]*(?:SECRET|KEY|TOKEN|PASSWORD)[A-Z_]*\s*=\s*["\'][^"\']+["\']',
            r'set\s+[A-Z_]*(?:SECRET|KEY|TOKEN|PASSWORD)[A-Z_]*=[^&\n]+',
            r'echo\s+\$[A-Z_]*(?:SECRET|KEY|TOKEN|PASSWORD)[A-Z_]*',
        ]
        
        findings = []
        for file_path in script_files:
            if os.path.exists(file_path):
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    for pattern in dangerous_env_patterns:
                        matches = re.finditer(pattern, content, re.IGNORECASE)
                        for match in matches:
                            line_num = content[:match.start()].count('\n') + 1
                            # Check if this looks like it's exposing a real secret
                            match_text = match.group()
                            if not any(word in match_text.lower() for word in ['example', 'test', 'dummy']):
                                findings.append({
                                    'file': file_path,
                                    'line': line_num,
                                    'match': match_text[:100]
                                })
                except:
                    pass
        
        if findings:
            print(f"⚠️  Warning: Found {len(findings)} potential environment variable exposures")

    def test_log_file_secrets(self):
        """Test that secrets don't appear in log files"""
        # Create test log scenario
        log_dir = os.path.join(self.test_dir, ".portableralph", "logs")
        os.makedirs(log_dir, exist_ok=True)
        
        # Simulate logging with potential secrets
        test_messages = [
            "Processing with API key: sk-ant-api03-secret123",
            "Webhook URL configured: https://hooks.slack.com/services/secret/webhook",
            "Authentication token: bearer_token_123456",
        ]
        
        log_file = os.path.join(log_dir, "ralph.log")
        
        # Test that notify.sh doesn't log secrets
        config_file = os.path.join(self.test_dir, ".ralph.env")
        with open(config_file, 'w') as f:
            f.write('export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T123/B123/SECRET"\n')
            f.write('export CLAUDE_API_KEY="sk-ant-api03-secret123456"\n')
        os.chmod(config_file, 0o600)

        # Run notification with logging
        result = subprocess.run([
            'bash', '-c',
            f'cd {self.repo_root} && HOME={self.test_dir} ./notify.sh --test 2>&1 | tee {log_file}'
        ], capture_output=True, text=True, timeout=10)

        # Check log file for secrets
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                log_content = f.read()
            
            # Check for secret exposure
            if "SECRET" in log_content or "secret123456" in log_content:
                raise Exception("Secrets found in log file output")

    def test_base64_encoded_secrets(self):
        """Test for base64 encoded secrets that might be hiding in plain sight"""
        script_files = []
        result = subprocess.run(['find', str(self.repo_root), '-name', '*.sh', '-o', '-name', '*.ps1', 
                                '-o', '-name', '*.py', '-o', '-name', '*.json'], 
                              capture_output=True, text=True)
        script_files = [f for f in result.stdout.strip().split('\n') if f and 'tests/' not in f]
        
        # Pattern for base64 strings
        base64_pattern = r'[A-Za-z0-9+/]{20,}={0,2}'
        
        findings = []
        for file_path in script_files:
            if os.path.exists(file_path):
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    matches = re.finditer(base64_pattern, content)
                    for match in matches:
                        b64_string = match.group()
                        # Try to decode and see if it looks like a secret
                        try:
                            decoded = base64.b64decode(b64_string + '==').decode('utf-8', errors='ignore')
                            if any(keyword in decoded.lower() for keyword in ['key', 'secret', 'token', 'password']):
                                findings.append({
                                    'file': file_path,
                                    'base64': b64_string[:50] + '...',
                                    'decoded': decoded[:50] + '...'
                                })
                        except:
                            pass
                except:
                    pass
        
        if findings:
            print(f"⚠️  Warning: Found {len(findings)} potential base64 encoded secrets")

    def test_backup_file_secrets(self):
        """Test that backup files don't contain exposed secrets"""
        backup_patterns = ['*.backup', '*.bak', '*.old', '*.orig', '*~']
        backup_files = []
        
        for pattern in backup_patterns:
            result = subprocess.run(['find', str(self.repo_root), '-name', pattern], 
                                  capture_output=True, text=True)
            backup_files.extend(result.stdout.strip().split('\n'))
        
        backup_files = [f for f in backup_files if f]
        
        secret_patterns = {
            'all_secrets': (self.secret_patterns['api_key'] + 
                           self.secret_patterns['webhook_url'] + 
                           self.secret_patterns['token'])
        }
        
        findings = []
        for file_path in backup_files:
            if os.path.exists(file_path):
                file_findings = self.scan_file_for_secrets(file_path, secret_patterns)
                findings.extend(file_findings)
        
        if findings:
            raise Exception(f"Found secrets in {len(findings)} backup files")

    def test_temporary_file_secrets(self):
        """Test that temporary files don't expose secrets"""
        temp_patterns = ['/tmp/ralph*', '/tmp/*ralph*', '*.tmp', '*.temp']
        temp_files = []
        
        for pattern in temp_patterns:
            try:
                result = subprocess.run(['find', '/tmp', '-name', pattern.split('/')[-1], '2>/dev/null'], 
                                      shell=True, capture_output=True, text=True)
                temp_files.extend(result.stdout.strip().split('\n'))
            except:
                pass
        
        temp_files = [f for f in temp_files if f and os.path.exists(f)]
        
        if temp_files:
            print(f"⚠️  Warning: Found {len(temp_files)} temporary files - checking for secrets")
            
            secret_patterns = {
                'temp_secrets': self.secret_patterns['api_key'] + self.secret_patterns['token']
            }
            
            findings = []
            for file_path in temp_files:
                try:
                    file_findings = self.scan_file_for_secrets(file_path, secret_patterns)
                    findings.extend(file_findings)
                except:
                    pass
            
            if findings:
                raise Exception(f"Found secrets in temporary files: {findings}")

    def run_all_tests(self):
        """Run all secrets exposure security tests"""
        print("🔒 Running Secrets Exposure Security Tests for PortableRalph\n")
        
        try:
            self.setup()
            
            # Run all test methods
            self.run_test("Hardcoded API Keys", self.test_hardcoded_api_keys)
            self.run_test("Hardcoded Webhook URLs", self.test_hardcoded_webhook_urls)
            self.run_test("Exposed Passwords", self.test_exposed_passwords)
            self.run_test("Private Keys Exposure", self.test_private_keys_exposure)
            self.run_test("Git History Secrets", self.test_git_history_secrets)
            self.run_test("Environment Variable Exposure", self.test_environment_variable_exposure)
            self.run_test("Log File Secrets", self.test_log_file_secrets)
            self.run_test("Base64 Encoded Secrets", self.test_base64_encoded_secrets)
            self.run_test("Backup File Secrets", self.test_backup_file_secrets)
            self.run_test("Temporary File Secrets", self.test_temporary_file_secrets)

        finally:
            self.teardown()

        # Print summary
        print(f"\n{'='*60}")
        print("SECRETS EXPOSURE SECURITY TEST SUMMARY")
        print(f"{'='*60}")
        print(f"Total Tests: {self.total_tests}")
        print(f"Passed: {self.total_tests - self.failed_tests}")
        print(f"Failed: {self.failed_tests}")
        
        if self.failed_tests == 0:
            print("🎉 All secrets exposure security tests passed!")
            return True
        else:
            print(f"⚠️  {self.failed_tests} secrets exposure vulnerabilities found!")
            return False

if __name__ == "__main__":
    test_suite = SecretsExposureTests()
    success = test_suite.run_all_tests()
    sys.exit(0 if success else 1)
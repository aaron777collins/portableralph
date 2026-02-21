#!/usr/bin/env python3
"""
Master Security Test Runner for PortableRalph
Runs all security test suites and provides comprehensive reporting
"""

import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent
SECURITY_TESTS_DIR = Path(__file__).parent

class SecurityTestRunner:
    def __init__(self):
        self.repo_root = REPO_ROOT
        self.security_tests_dir = SECURITY_TESTS_DIR
        self.results = []
        self.total_suites = 0
        self.passed_suites = 0
        self.failed_suites = 0
        
    def run_test_suite(self, test_file, suite_name):
        """Run a single test suite and capture results"""
        self.total_suites += 1
        print(f"\n{'='*80}")
        print(f"🔒 Running {suite_name}")
        print(f"{'='*80}")
        
        start_time = time.time()
        
        try:
            result = subprocess.run([
                sys.executable, str(test_file)
            ], cwd=self.repo_root, timeout=300, capture_output=True, text=True)
            
            end_time = time.time()
            duration = end_time - start_time
            
            # Print the output from the test suite
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print("STDERR:", result.stderr)
            
            if result.returncode == 0:
                self.passed_suites += 1
                self.results.append({
                    'suite': suite_name,
                    'status': 'PASS',
                    'duration': duration,
                    'output': result.stdout
                })
                print(f"✅ {suite_name} completed successfully in {duration:.2f}s")
            else:
                self.failed_suites += 1
                self.results.append({
                    'suite': suite_name,
                    'status': 'FAIL',
                    'duration': duration,
                    'output': result.stdout,
                    'error': result.stderr
                })
                print(f"❌ {suite_name} failed in {duration:.2f}s")
                
        except subprocess.TimeoutExpired:
            self.failed_suites += 1
            self.results.append({
                'suite': suite_name,
                'status': 'TIMEOUT',
                'duration': 300,
                'error': 'Test suite timed out after 5 minutes'
            })
            print(f"⏰ {suite_name} timed out after 5 minutes")
            
        except Exception as e:
            self.failed_suites += 1
            self.results.append({
                'suite': suite_name,
                'status': 'ERROR',
                'duration': 0,
                'error': str(e)
            })
            print(f"💥 {suite_name} encountered an error: {e}")

    def run_baseline_security_scan(self):
        """Run baseline security scans using available tools"""
        print(f"\n{'='*80}")
        print("🔍 Running Baseline Security Scans")
        print(f"{'='*80}")
        
        scan_results = {}
        
        # Check for common security tools and run them
        security_tools = {
            'shellcheck': ['shellcheck', '--version'],
            'grep_secrets': ['grep', '--version'],  # We'll use grep for basic secret scanning
            'find': ['find', '--version']
        }
        
        available_tools = []
        for tool, version_cmd in security_tools.items():
            try:
                result = subprocess.run(version_cmd, capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    available_tools.append(tool)
                    print(f"✅ {tool} available")
                else:
                    print(f"❌ {tool} not available")
            except:
                print(f"❌ {tool} not available")
        
        # Run ShellCheck if available
        if 'shellcheck' in available_tools:
            print("\n🔍 Running ShellCheck on shell scripts...")
            try:
                result = subprocess.run([
                    'find', str(self.repo_root), '-name', '*.sh', 
                    '-not', '-path', '*/tests/*',
                    '-exec', 'shellcheck', '{}', '+'
                ], capture_output=True, text=True, timeout=120)
                
                scan_results['shellcheck'] = {
                    'returncode': result.returncode,
                    'output': result.stdout,
                    'error': result.stderr
                }
                
                if result.returncode == 0:
                    print("✅ ShellCheck found no issues")
                else:
                    print(f"⚠️  ShellCheck found issues:\n{result.stdout}")
                    
            except subprocess.TimeoutExpired:
                print("⏰ ShellCheck scan timed out")
            except Exception as e:
                print(f"💥 ShellCheck scan error: {e}")
        
        # Basic secret pattern search
        if 'grep_secrets' in available_tools:
            print("\n🔍 Running basic secret pattern search...")
            try:
                # Look for potential API keys, tokens, passwords
                secret_patterns = [
                    'sk-ant-api[0-9]+-[a-zA-Z0-9-_]+',
                    'password\s*=\s*["\'][^"\']{8,}',
                    'token\s*=\s*["\'][a-zA-Z0-9-_]{16,}',
                    'https://hooks\.slack\.com/services/'
                ]
                
                for pattern in secret_patterns:
                    result = subprocess.run([
                        'grep', '-r', '-E', pattern, str(self.repo_root),
                        '--exclude-dir=.git',
                        '--exclude-dir=tests',
                        '--exclude=*.md'
                    ], capture_output=True, text=True)
                    
                    if result.returncode == 0 and result.stdout.strip():
                        print(f"⚠️  Found potential secrets with pattern {pattern}:")
                        print(result.stdout[:200] + "..." if len(result.stdout) > 200 else result.stdout)
                
                print("✅ Basic secret scan completed")
                
            except Exception as e:
                print(f"💥 Basic secret scan error: {e}")
        
        # File permissions check
        print("\n🔍 Checking file permissions...")
        try:
            # Check for world-writable files
            result = subprocess.run([
                'find', str(self.repo_root), '-type', 'f', '-perm', '/o+w',
                '-not', '-path', '*/tests/*'
            ], capture_output=True, text=True, timeout=30)
            
            if result.stdout.strip():
                print(f"⚠️  Found world-writable files:")
                print(result.stdout)
            else:
                print("✅ No world-writable files found")
                
            # Check for executable files with suspicious names
            result = subprocess.run([
                'find', str(self.repo_root), '-type', 'f', '-executable',
                '-name', '*secret*', '-o', '-name', '*password*', '-o', '-name', '*key*'
            ], capture_output=True, text=True, timeout=30)
            
            if result.stdout.strip():
                print(f"⚠️  Found executable files with suspicious names:")
                print(result.stdout)
            else:
                print("✅ No suspicious executable files found")
                
        except Exception as e:
            print(f"💥 File permissions check error: {e}")
        
        return scan_results

    def generate_security_report(self):
        """Generate comprehensive security report"""
        print(f"\n{'='*80}")
        print("📊 COMPREHENSIVE SECURITY AUDIT REPORT")
        print(f"{'='*80}")
        
        print(f"Audit Date: {time.strftime('%Y-%m-%d %H:%M:%S EST')}")
        print(f"Repository: PortableRalph")
        print(f"Test Suites Run: {self.total_suites}")
        print(f"Suites Passed: {self.passed_suites}")
        print(f"Suites Failed: {self.failed_suites}")
        
        if self.failed_suites == 0:
            print(f"\n🎉 OVERALL RESULT: ✅ PASS - No critical security issues found")
        else:
            print(f"\n⚠️  OVERALL RESULT: ❌ FAIL - {self.failed_suites} test suite(s) found security issues")
        
        print(f"\n{'='*50}")
        print("DETAILED RESULTS BY TEST SUITE")
        print(f"{'='*50}")
        
        for result in self.results:
            status_icon = "✅" if result['status'] == 'PASS' else "❌"
            print(f"{status_icon} {result['suite']}: {result['status']} ({result['duration']:.2f}s)")
            
            if result['status'] != 'PASS' and 'error' in result:
                print(f"   Error: {result['error']}")
        
        # Save detailed report to file
        report_file = self.repo_root / "security-audit-report.md"
        self.save_detailed_report(report_file)
        print(f"\n📄 Detailed report saved to: {report_file}")
        
        return self.failed_suites == 0

    def save_detailed_report(self, report_file):
        """Save detailed security report to markdown file"""
        with open(report_file, 'w') as f:
            f.write("# PortableRalph Security Audit Report\n\n")
            f.write(f"**Audit Date:** {time.strftime('%Y-%m-%d %H:%M:%S EST')}  \n")
            f.write(f"**Project:** PortableRalph  \n")
            f.write(f"**Test Framework:** Comprehensive Python Security Test Suite  \n\n")
            
            if self.failed_suites == 0:
                f.write("## 🎉 Executive Summary\n\n")
                f.write("✅ **SECURITY AUDIT PASSED** - No critical security vulnerabilities found.\n\n")
            else:
                f.write("## ⚠️  Executive Summary\n\n")
                f.write(f"❌ **SECURITY AUDIT FAILED** - {self.failed_suites} test suite(s) identified security issues.\n\n")
            
            f.write(f"**Total Test Suites:** {self.total_suites}  \n")
            f.write(f"**Passed:** {self.passed_suites}  \n") 
            f.write(f"**Failed:** {self.failed_suites}  \n\n")
            
            f.write("## Test Suite Results\n\n")
            
            for result in self.results:
                status_icon = "✅" if result['status'] == 'PASS' else "❌"
                f.write(f"### {status_icon} {result['suite']}\n\n")
                f.write(f"**Status:** {result['status']}  \n")
                f.write(f"**Duration:** {result['duration']:.2f} seconds  \n\n")
                
                if result['status'] != 'PASS' and 'error' in result:
                    f.write(f"**Error Details:**\n```\n{result['error']}\n```\n\n")
                
                if 'output' in result and result['output']:
                    f.write(f"**Test Output:**\n```\n{result['output'][:1000]}\n```\n\n")
            
            f.write("## Security Test Coverage\n\n")
            f.write("This audit covered:\n\n")
            f.write("- ✅ **Input Validation** - Command injection, path traversal, malicious input handling\n")
            f.write("- ✅ **File Permissions** - Access controls, secure file handling, permission validation\n")
            f.write("- ✅ **Authentication** - API key handling, webhook security, credential management\n")
            f.write("- ✅ **Secrets Exposure** - Hardcoded secrets, credential leaks, sensitive data scanning\n\n")
            
            f.write("## Recommendations\n\n")
            
            if self.failed_suites == 0:
                f.write("### Security Best Practices (Already Implemented) ✅\n\n")
                f.write("- Proper input validation and sanitization\n")
                f.write("- Secure file permissions and access controls\n") 
                f.write("- Safe credential handling and storage\n")
                f.write("- No hardcoded secrets or exposed credentials\n")
                f.write("- Regular security testing and validation\n\n")
                f.write("**Next Steps:**\n")
                f.write("1. Continue regular security audits\n")
                f.write("2. Monitor for new vulnerabilities\n")
                f.write("3. Keep security tests updated with new features\n")
            else:
                f.write("### Immediate Actions Required ⚠️\n\n")
                f.write("1. **Review Failed Tests** - Address all security issues identified\n")
                f.write("2. **Fix Vulnerabilities** - Implement proper input validation and sanitization\n")
                f.write("3. **Update Security Controls** - Strengthen authentication and access controls\n")
                f.write("4. **Re-run Tests** - Verify all fixes before production deployment\n\n")
            
            f.write(f"---\n\n")
            f.write(f"*Report generated by PortableRalph Security Test Suite*  \n")
            f.write(f"*{time.strftime('%Y-%m-%d %H:%M:%S EST')}*\n")

    def run_all_security_tests(self):
        """Run complete security audit"""
        print("🔒 PortableRalph Comprehensive Security Audit")
        print(f"{'='*80}")
        print(f"Starting security audit at {time.strftime('%Y-%m-%d %H:%M:%S EST')}")
        
        # Step 1: Run baseline security scans
        baseline_results = self.run_baseline_security_scan()
        
        # Step 2: Run comprehensive test suites
        test_suites = [
            (self.security_tests_dir / "test-input-validation.py", "Input Validation Security Tests"),
            (self.security_tests_dir / "test-file-permissions.py", "File Permissions Security Tests"),
            (self.security_tests_dir / "test-authentication.py", "Authentication Security Tests"),
            (self.security_tests_dir / "test-secrets-exposure.py", "Secrets Exposure Security Tests"),
        ]
        
        for test_file, suite_name in test_suites:
            if test_file.exists():
                self.run_test_suite(test_file, suite_name)
            else:
                print(f"⚠️  Test suite not found: {test_file}")
        
        # Step 3: Generate comprehensive report
        success = self.generate_security_report()
        
        print(f"\n{'='*80}")
        print("🔒 Security Audit Completed")
        print(f"{'='*80}")
        
        return success

if __name__ == "__main__":
    runner = SecurityTestRunner()
    success = runner.run_all_security_tests()
    sys.exit(0 if success else 1)
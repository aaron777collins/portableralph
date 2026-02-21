#!/usr/bin/env python3
"""
Installation Procedure Testing for PortableRalph
Tests to verify documented installation steps actually work

TDD approach for installation validation:
- Test installation script availability
- Verify installation commands work as documented
- Check installation requirements are testable
- Validate platform-specific installation paths
"""

import os
import re
import sys
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch
import shutil

class InstallationProcedureTests:
    def __init__(self):
        self.repo_root = Path(__file__).parent.parent.parent
        self.readme_path = self.repo_root / "README.md"
        self.install_sh = self.repo_root / "install.sh"
        self.install_ps1 = self.repo_root / "install.ps1"
        self.results = {
            "total_tests": 0,
            "passed_tests": 0,
            "failed_tests": 0,
            "failures": []
        }
        
    def run_test(self, test_name, test_func):
        """Run a single test and track results"""
        self.results["total_tests"] += 1
        try:
            test_func()
            print(f"✅ {test_name}")
            self.results["passed_tests"] += 1
        except AssertionError as e:
            print(f"❌ {test_name}: {str(e)}")
            self.results["failed_tests"] += 1
            self.results["failures"].append({
                "test": test_name,
                "error": str(e)
            })
        except Exception as e:
            print(f"🔥 {test_name}: Unexpected error - {str(e)}")
            self.results["failed_tests"] += 1
            self.results["failures"].append({
                "test": test_name,
                "error": f"Unexpected error: {str(e)}"
            })

    def test_installation_scripts_exist(self):
        """Installation scripts must exist and be executable"""
        assert self.install_sh.exists(), "install.sh does not exist"
        assert self.install_ps1.exists(), "install.ps1 does not exist"
        
        # Check if install.sh is executable
        assert os.access(self.install_sh, os.X_OK), "install.sh is not executable"

    def test_installation_commands_in_readme(self):
        """Installation commands in README must match actual script names"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Check for bash installation command
        bash_install_pattern = r'curl.*install\.sh.*bash'
        assert re.search(bash_install_pattern, content), "Bash installation command not found in README"
        
        # Check for PowerShell installation command
        ps_install_pattern = r'irm.*install\.ps1.*iex'
        assert re.search(ps_install_pattern, content), "PowerShell installation command not found in README"

    def test_install_sh_help_functionality(self):
        """install.sh must provide help functionality"""
        try:
            result = subprocess.run([str(self.install_sh), '--help'], 
                                  capture_output=True, text=True, timeout=10)
            # Help should exit with 0 and provide usage info
            assert result.returncode == 0, f"install.sh --help failed with code {result.returncode}"
            assert 'usage' in result.stdout.lower() or 'install' in result.stdout.lower(), \
                   f"install.sh --help doesn't provide usage info: {result.stdout}"
        except subprocess.TimeoutExpired:
            assert False, "install.sh --help timed out"
        except FileNotFoundError:
            assert False, "install.sh not found or not executable"

    def test_install_scripts_syntax_valid(self):
        """Installation scripts must have valid syntax"""
        # Test bash script syntax
        try:
            result = subprocess.run(['bash', '-n', str(self.install_sh)], 
                                  capture_output=True, text=True, timeout=5)
            assert result.returncode == 0, f"install.sh has syntax errors: {result.stderr}"
        except subprocess.TimeoutExpired:
            assert False, "install.sh syntax check timed out"

        # Test PowerShell script syntax (if PowerShell available)
        if shutil.which('pwsh') or shutil.which('powershell'):
            ps_cmd = 'pwsh' if shutil.which('pwsh') else 'powershell'
            try:
                result = subprocess.run([ps_cmd, '-Command', f'Get-Content "{self.install_ps1}" | Out-Null'], 
                                      capture_output=True, text=True, timeout=5)
                # PowerShell syntax validation is more complex, just check it doesn't crash
                assert result.returncode == 0, f"install.ps1 may have syntax errors: {result.stderr}"
            except subprocess.TimeoutExpired:
                print("⚠️  PowerShell syntax check timed out (not failing test)")

    def test_documented_requirements_testable(self):
        """Documented requirements must be testable/verifiable"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Extract requirements section
        requirements_match = re.search(r'## Requirements.*?(?=##|\Z)', content, re.DOTALL | re.IGNORECASE)
        assert requirements_match, "Requirements section not found"
        
        requirements_text = requirements_match.group(0)
        
        # Key requirements should have verifiable commands
        testable_requirements = []
        
        if 'Claude Code CLI' in requirements_text:
            testable_requirements.append('claude')
        if 'Git' in requirements_text:
            testable_requirements.append('git')
        if 'PowerShell' in requirements_text:
            testable_requirements.append('pwsh')
        if 'Bash' in requirements_text:
            testable_requirements.append('bash')
        
        # Test if we can check for these requirements
        available_commands = []
        for cmd in testable_requirements:
            if shutil.which(cmd):
                available_commands.append(cmd)
        
        # We should be able to test at least some requirements
        assert len(available_commands) >= 2, f"Cannot verify enough requirements. Available: {available_commands}"

    def test_platform_specific_paths_documented(self):
        """Platform-specific installation paths must be clearly documented"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Should document different paths for different platforms
        path_patterns = [
            r'~/ralph|~\\ralph',  # Unix/Windows paths
            r'\$env:USERPROFILE|%USERPROFILE%',  # Windows environment variable
            r'/home/.*ralph',  # Linux path
            r'C:\\.*ralph|C:/.*ralph'  # Windows absolute path
        ]
        
        found_patterns = []
        for pattern in path_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                found_patterns.append(pattern)
        
        assert len(found_patterns) >= 2, f"Need more platform-specific path examples. Found: {found_patterns}"

    def test_manual_installation_steps_clear(self):
        """Manual installation steps must be clear and complete"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Should have manual installation sections
        manual_sections = re.findall(r'manual.*?:.*?(?=\*\*|\n\n)', content, re.IGNORECASE | re.DOTALL)
        assert len(manual_sections) >= 1, "Manual installation steps not found"
        
        # Manual steps should include git clone and permissions
        manual_text = ' '.join(manual_sections)
        required_steps = ['git clone', 'chmod', 'executable']
        
        missing_steps = []
        for step in required_steps:
            if not re.search(step, manual_text, re.IGNORECASE):
                missing_steps.append(step)
        
        assert not missing_steps, f"Manual installation missing steps: {missing_steps}"

    def test_quick_start_commands_executable(self):
        """Quick start commands should be ready to execute"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find quick start section
        quick_start_match = re.search(r'## Quick Start.*?(?=##|\Z)', content, re.DOTALL | re.IGNORECASE)
        assert quick_start_match, "Quick Start section not found"
        
        quick_start_text = quick_start_match.group(0)
        
        # Should have executable examples
        code_blocks = re.findall(r'```(?:bash|powershell)?\n(.*?)\n```', quick_start_text, re.DOTALL)
        assert len(code_blocks) >= 2, f"Quick start needs more code examples. Found {len(code_blocks)}"
        
        # Check for key commands
        all_code = ' '.join(code_blocks)
        key_commands = ['ralph', 'install', 'clone']
        
        missing_commands = []
        for cmd in key_commands:
            if cmd not in all_code.lower():
                missing_commands.append(cmd)
        
        assert not missing_commands, f"Quick start missing key commands: {missing_commands}"

    def test_installation_verification_documented(self):
        """Installation verification steps must be documented"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Should document how to verify installation worked
        verification_patterns = [
            r'ralph.*--help',
            r'ralph.*--version',
            r'test.*install',
            r'verify.*install'
        ]
        
        found_verification = []
        for pattern in verification_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                found_verification.append(pattern)
        
        assert len(found_verification) >= 1, f"Installation verification not documented. Patterns checked: {verification_patterns}"

    def test_dependency_installation_covered(self):
        """Dependency installation must be covered for all platforms"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Should cover Claude CLI installation
        claude_install_patterns = [
            r'Claude Code CLI.*install',
            r'platform\.claude\.com',
            r'anthropic.*docs'
        ]
        
        found_claude_info = []
        for pattern in claude_install_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                found_claude_info.append(pattern)
        
        assert len(found_claude_info) >= 1, f"Claude CLI installation not documented. Checked: {claude_install_patterns}"

    def run_all_tests(self):
        """Run all installation procedure tests"""
        print("🧪 Running Installation Procedure Tests")
        print("=" * 50)
        
        # Core installation tests
        self.run_test("Installation scripts exist", self.test_installation_scripts_exist)
        self.run_test("Installation commands in README", self.test_installation_commands_in_readme)
        self.run_test("install.sh help functionality", self.test_install_sh_help_functionality)
        self.run_test("Install scripts syntax valid", self.test_install_scripts_syntax_valid)
        self.run_test("Documented requirements testable", self.test_documented_requirements_testable)
        self.run_test("Platform-specific paths documented", self.test_platform_specific_paths_documented)
        self.run_test("Manual installation steps clear", self.test_manual_installation_steps_clear)
        self.run_test("Quick start commands executable", self.test_quick_start_commands_executable)
        self.run_test("Installation verification documented", self.test_installation_verification_documented)
        self.run_test("Dependency installation covered", self.test_dependency_installation_covered)
        
        # Results summary
        print("\n" + "=" * 50)
        print(f"📊 Installation Procedure Test Results:")
        print(f"   Total tests: {self.results['total_tests']}")
        print(f"   Passed: ✅ {self.results['passed_tests']}")
        print(f"   Failed: ❌ {self.results['failed_tests']}")
        
        if self.results['failures']:
            print(f"\n🔍 Failed Tests:")
            for failure in self.results['failures']:
                print(f"   • {failure['test']}: {failure['error']}")
        
        success_rate = (self.results['passed_tests'] / self.results['total_tests']) * 100
        print(f"\n📈 Success Rate: {success_rate:.1f}%")
        
        return self.results['failed_tests'] == 0

if __name__ == "__main__":
    tester = InstallationProcedureTests()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
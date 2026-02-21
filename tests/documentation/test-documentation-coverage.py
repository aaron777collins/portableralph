#!/usr/bin/env python3
"""
Documentation Coverage Testing for PortableRalph
Tests to verify comprehensive and production-ready documentation

Based on p4-1 security audit and p4-2 code quality review findings:
- Ensure all features are documented
- Verify installation requirements are clear
- Check troubleshooting section completeness
- Validate performance recommendations
- Confirm security best practices inclusion
"""

import os
import re
import sys
import json
import subprocess
from pathlib import Path

class DocumentationCoverageTests:
    def __init__(self):
        self.repo_root = Path(__file__).parent.parent.parent
        self.readme_path = self.repo_root / "README.md"
        self.docs_dir = self.repo_root / "docs"
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

    def test_readme_exists_and_readable(self):
        """README.md must exist and be readable"""
        assert self.readme_path.exists(), "README.md does not exist"
        content = self.readme_path.read_text(encoding='utf-8')
        assert len(content) > 1000, f"README.md too short ({len(content)} chars), needs comprehensive content"

    def test_features_documented(self):
        """All major features must be documented in README"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        required_features = [
            "Autonomous AI development loop",
            "Plan mode", 
            "Build mode",
            "Notification",
            "Cross-platform",
            "Windows support",
            "PowerShell",
            "Security",
            "Testing"
        ]
        
        missing_features = []
        for feature in required_features:
            if not re.search(feature, content, re.IGNORECASE):
                missing_features.append(feature)
        
        assert not missing_features, f"Missing feature documentation: {missing_features}"

    def test_installation_requirements_clear(self):
        """Installation requirements must be clearly documented"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Must have platform-specific requirements
        assert re.search(r"## Requirements", content), "Requirements section missing"
        
        required_items = [
            "Claude Code CLI",
            "PowerShell",
            "Bash",
            "Git"
        ]
        
        missing_items = []
        for item in required_items:
            if not re.search(item, content, re.IGNORECASE):
                missing_items.append(item)
                
        assert not missing_items, f"Missing installation requirements: {missing_items}"

    def test_troubleshooting_section_comprehensive(self):
        """Troubleshooting section must cover common issues from p4-2 findings"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Must have troubleshooting section
        assert re.search(r"## Troubleshooting|# Troubleshooting", content), "Troubleshooting section missing from README"
        
        # Should cover key issues from quality review
        expected_issues = [
            "PowerShell.*blocked|execution.*policy",
            "command not found",
            "line ending|\\\\r",
            "path.*issue"
        ]
        
        missing_issues = []
        for issue_pattern in expected_issues:
            if not re.search(issue_pattern, content, re.IGNORECASE):
                missing_issues.append(issue_pattern.replace(".*", " "))
                
        assert not missing_issues, f"Troubleshooting missing common issues: {missing_issues}"

    def test_security_best_practices_included(self):
        """Security best practices from p4-1 audit must be included"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Must have security section
        assert re.search(r"## Security|# Security", content), "Security section missing from README"
        
        # Must include key security practices from audit
        security_practices = [
            "environment variables",
            "HTTPS",
            "credential.*mask",
            "input validation",
            "secure.*permissions"
        ]
        
        missing_practices = []
        for practice_pattern in security_practices:
            if not re.search(practice_pattern, content, re.IGNORECASE):
                missing_practices.append(practice_pattern.replace(".*", " "))
                
        assert not missing_practices, f"Missing security practices: {missing_practices}"

    def test_performance_recommendations_present(self):
        """Performance recommendations based on audit findings must be present"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Should have performance guidance
        performance_topics = [
            "iteration.*limit",
            "batch",
            "frequency",
            "resource"
        ]
        
        found_topics = []
        for topic_pattern in performance_topics:
            if re.search(topic_pattern, content, re.IGNORECASE):
                found_topics.append(topic_pattern)
        
        assert len(found_topics) >= 2, f"Need more performance recommendations. Found: {found_topics}"

    def test_windows_documentation_comprehensive(self):
        """Windows documentation must be comprehensive (from Phase 3 work)"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Must have detailed Windows section
        assert re.search(r"## Windows Support|# Windows Support", content), "Windows Support section missing"
        
        windows_requirements = [
            "PowerShell.*5\\.1|PowerShell 5.1",
            "execution.*policy|ExecutionPolicy",
            "WSL",
            "Git.*Windows",
            "line ending"
        ]
        
        missing_requirements = []
        for req_pattern in windows_requirements:
            if not re.search(req_pattern, content, re.IGNORECASE):
                missing_requirements.append(req_pattern.replace(".*", " "))
                
        assert not missing_requirements, f"Missing Windows requirements: {missing_requirements}"

    def test_configuration_options_documented(self):
        """Configuration options must be thoroughly documented"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Must document key configuration options
        config_options = [
            "CLAUDE_API_KEY",
            "RALPH_.*",
            "\\.env",
            "environment.*variable"
        ]
        
        missing_options = []
        for option_pattern in config_options:
            if not re.search(option_pattern, content, re.IGNORECASE):
                missing_options.append(option_pattern.replace(".*", " "))
                
        assert not missing_options, f"Missing configuration documentation: {missing_options}"

    def test_api_documentation_current(self):
        """API/command documentation must be current and complete"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Must document all major commands and parameters
        command_docs = [
            "ralph.*plan.*mode",
            "ralph.*build.*mode", 
            "ralph notify",
            "max.*iteration",
            "launcher\\.bat"
        ]
        
        missing_commands = []
        for cmd_pattern in command_docs:
            if not re.search(cmd_pattern, content, re.IGNORECASE):
                missing_commands.append(cmd_pattern.replace(".*", " "))
                
        assert not missing_commands, f"Missing command documentation: {missing_commands}"

    def test_comprehensive_examples_provided(self):
        """Comprehensive usage examples must be provided"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Count code blocks
        code_blocks = re.findall(r'```[^`]*```', content, re.MULTILINE | re.DOTALL)
        assert len(code_blocks) >= 10, f"Need more code examples. Found {len(code_blocks)} code blocks"
        
        # Must have platform-specific examples
        bash_examples = re.findall(r'```bash[^`]*```', content, re.MULTILINE | re.DOTALL)
        ps_examples = re.findall(r'```powershell[^`]*```', content, re.MULTILINE | re.DOTALL)
        
        assert len(bash_examples) >= 3, f"Need more bash examples. Found {len(bash_examples)}"
        assert len(ps_examples) >= 3, f"Need more PowerShell examples. Found {len(ps_examples)}"

    def test_documentation_links_working(self):
        """All documentation links must be valid (basic structure check)"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find markdown links
        links = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content)
        
        broken_links = []
        for link_text, link_url in links:
            # Check relative links exist
            if not link_url.startswith('http') and not link_url.startswith('#'):
                link_path = self.repo_root / link_url
                if not link_path.exists():
                    broken_links.append(f"{link_text} -> {link_url}")
        
        assert not broken_links, f"Broken documentation links: {broken_links}"

    def run_all_tests(self):
        """Run all documentation coverage tests"""
        print("🧪 Running Documentation Coverage Tests")
        print("=" * 50)
        
        # Core documentation tests
        self.run_test("README exists and readable", self.test_readme_exists_and_readable)
        self.run_test("Features documented", self.test_features_documented)
        self.run_test("Installation requirements clear", self.test_installation_requirements_clear)
        self.run_test("Troubleshooting comprehensive", self.test_troubleshooting_section_comprehensive)
        self.run_test("Security best practices included", self.test_security_best_practices_included)
        self.run_test("Performance recommendations present", self.test_performance_recommendations_present)
        self.run_test("Windows documentation comprehensive", self.test_windows_documentation_comprehensive)
        self.run_test("Configuration options documented", self.test_configuration_options_documented)
        self.run_test("API documentation current", self.test_api_documentation_current)
        self.run_test("Comprehensive examples provided", self.test_comprehensive_examples_provided)
        self.run_test("Documentation links working", self.test_documentation_links_working)
        
        # Results summary
        print("\n" + "=" * 50)
        print(f"📊 Documentation Coverage Test Results:")
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
    tester = DocumentationCoverageTests()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
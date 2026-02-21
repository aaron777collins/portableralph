#!/usr/bin/env python3
"""
Markdown Quality and Link Validation Testing for PortableRalph
Tests to verify markdown quality and link integrity

TDD approach for documentation validation:
- Markdown linting and structure validation
- Link checking (internal and external basic validation)
- Code block syntax validation
- Documentation formatting consistency
"""

import os
import re
import sys
import json
from pathlib import Path
from urllib.parse import urlparse

class MarkdownQualityTests:
    def __init__(self):
        self.repo_root = Path(__file__).parent.parent.parent
        self.readme_path = self.repo_root / "README.md"
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

    def test_markdown_structure_valid(self):
        """Markdown structure must be valid and well-formed"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Check for proper heading hierarchy
        headings = re.findall(r'^(#+)\s+(.+)$', content, re.MULTILINE)
        
        prev_level = 0
        heading_errors = []
        for heading_match in headings:
            level = len(heading_match[0])
            title = heading_match[1]
            
            # Don't skip more than one level
            if level > prev_level + 1:
                heading_errors.append(f"Heading level jump: {title} (level {level} after level {prev_level})")
            
            prev_level = level
        
        assert not heading_errors, f"Markdown heading structure errors: {heading_errors}"

    def test_code_blocks_properly_formatted(self):
        """Code blocks must be properly formatted with language tags"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find all code blocks
        code_blocks = re.findall(r'```([^\n]*)\n([^`]*?)```', content, re.MULTILINE | re.DOTALL)
        
        untagged_blocks = []
        invalid_languages = []
        
        valid_languages = ['bash', 'powershell', 'cmd', 'markdown', 'json', 'yaml', 'diff', 'text', '']
        
        for i, (lang, code) in enumerate(code_blocks):
            lang = lang.strip()
            if not lang and code.strip():  # Only flag non-empty blocks without language
                untagged_blocks.append(f"Block {i+1}: {code[:50]}...")
            elif lang and lang not in valid_languages:
                invalid_languages.append(f"Block {i+1}: '{lang}'")
        
        assert len(untagged_blocks) <= 2, f"Too many untagged code blocks: {untagged_blocks}"
        assert not invalid_languages, f"Invalid language tags: {invalid_languages}"

    def test_internal_links_valid(self):
        """Internal markdown links must point to existing files or sections"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find internal links (not starting with http)
        links = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content)
        internal_links = [(text, url) for text, url in links if not url.startswith('http')]
        
        broken_internal_links = []
        
        for link_text, link_url in internal_links:
            if link_url.startswith('#'):
                # Section link - check if section exists
                section_id = link_url[1:].lower().replace(' ', '-').replace('/', '')
                section_pattern = re.compile(rf'^#+\s+.*{re.escape(link_text)}', re.IGNORECASE | re.MULTILINE)
                if not section_pattern.search(content):
                    # More lenient search for section headers
                    all_headers = re.findall(r'^#+\s+(.+)$', content, re.MULTILINE)
                    header_ids = [h.lower().replace(' ', '-').replace('/', '').replace('(', '').replace(')', '') for h in all_headers]
                    if section_id not in ' '.join(header_ids):
                        broken_internal_links.append(f"Section link: {link_text} -> {link_url}")
            else:
                # File link
                file_path = self.repo_root / link_url
                if not file_path.exists():
                    broken_internal_links.append(f"File link: {link_text} -> {link_url}")
        
        assert not broken_internal_links, f"Broken internal links: {broken_internal_links}"

    def test_external_links_basic_format(self):
        """External links must be properly formatted (basic validation)"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find external links
        links = re.findall(r'\[([^\]]+)\]\((https?://[^)]+)\)', content)
        
        malformed_links = []
        
        for link_text, link_url in links:
            try:
                parsed = urlparse(link_url)
                if not parsed.scheme or not parsed.netloc:
                    malformed_links.append(f"{link_text} -> {link_url}")
            except Exception:
                malformed_links.append(f"{link_text} -> {link_url}")
        
        assert not malformed_links, f"Malformed external links: {malformed_links}"

    def test_table_formatting_consistent(self):
        """Tables must be consistently formatted"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find all tables
        table_pattern = re.compile(r'^\|.*\|$', re.MULTILINE)
        table_lines = table_pattern.findall(content)
        
        if not table_lines:
            return  # No tables, test passes
        
        # Check for proper table structure
        table_errors = []
        current_table = []
        
        lines = content.split('\n')
        in_table = False
        
        for i, line in enumerate(lines):
            if re.match(r'^\|.*\|$', line):
                if not in_table:
                    in_table = True
                    current_table = []
                current_table.append(line)
            else:
                if in_table:
                    # End of table, validate it
                    if len(current_table) >= 2:
                        # Check separator row
                        if not re.match(r'^\|[\s\-:]*\|$', current_table[1]):
                            table_errors.append(f"Line {i-len(current_table)+2}: Invalid table separator")
                    in_table = False
                    current_table = []
        
        assert not table_errors, f"Table formatting errors: {table_errors}"

    def test_list_formatting_consistent(self):
        """List formatting must be consistent"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find numbered lists
        numbered_lists = re.findall(r'^\d+\.\s+(.+)$', content, re.MULTILINE)
        
        # Find bullet lists  
        bullet_lists = re.findall(r'^[\*\-]\s+(.+)$', content, re.MULTILINE)
        
        # Both should exist for comprehensive documentation
        assert len(numbered_lists) >= 3, f"Need more numbered lists for step-by-step instructions. Found {len(numbered_lists)}"
        assert len(bullet_lists) >= 10, f"Need more bullet lists for feature lists. Found {len(bullet_lists)}"

    def test_no_common_markdown_errors(self):
        """Check for common markdown formatting errors"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        errors = []
        
        # Check for unescaped special characters in regular text
        if re.search(r'(?<!\`)[_]{1}(?!\S)|(?<!\S)[_]{1}(?!\`)', content):
            errors.append("Unescaped underscore characters found")
        
        # Check for inconsistent emphasis (prefer ** over __)
        double_underscore = len(re.findall(r'__[^_]+__', content))
        double_asterisk = len(re.findall(r'\*\*[^*]+\*\*', content))
        
        if double_underscore > 0 and double_asterisk > double_underscore * 2:
            errors.append("Inconsistent bold formatting (mix of __ and **)")
        
        # Check for proper spacing around headers
        bad_headers = re.findall(r'^\#+[^\s]', content, re.MULTILINE)
        if bad_headers:
            errors.append(f"Headers without space after #: {bad_headers}")
        
        assert not errors, f"Markdown formatting errors: {errors}"

    def test_badges_functional(self):
        """Badges must be properly formatted and functional"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Find badge patterns
        badges = re.findall(r'\[\!\[([^\]]+)\]\(([^)]+)\)\]\(([^)]+)\)', content)
        
        badge_errors = []
        
        for alt_text, badge_url, link_url in badges:
            # Badge URL should be a valid image URL
            if not badge_url.startswith('https://'):
                badge_errors.append(f"Non-HTTPS badge URL: {badge_url}")
            
            # Link URL should be valid
            if not link_url.startswith('https://'):
                badge_errors.append(f"Non-HTTPS badge link: {link_url}")
        
        # Should have CI badges
        assert len(badges) >= 2, f"Need CI status badges. Found {len(badges)} badges"
        assert not badge_errors, f"Badge formatting errors: {badge_errors}"

    def test_documentation_completeness_metrics(self):
        """Documentation should meet completeness metrics"""
        content = self.readme_path.read_text(encoding='utf-8')
        
        # Count various elements
        word_count = len(content.split())
        section_count = len(re.findall(r'^##\s+', content, re.MULTILINE))
        code_block_count = len(re.findall(r'```', content)) // 2
        link_count = len(re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content))
        
        print(f"📊 Documentation Metrics:")
        print(f"   Words: {word_count}")
        print(f"   Sections: {section_count}")
        print(f"   Code blocks: {code_block_count}")
        print(f"   Links: {link_count}")
        
        # Minimum thresholds for production readiness
        assert word_count >= 3000, f"Documentation too short ({word_count} words), need comprehensive content"
        assert section_count >= 15, f"Need more sections ({section_count}), documentation should be comprehensive"
        assert code_block_count >= 15, f"Need more code examples ({code_block_count}), users need clear guidance"
        assert link_count >= 10, f"Need more links ({link_count}), documentation should be well-connected"

    def run_all_tests(self):
        """Run all markdown quality tests"""
        print("🧪 Running Markdown Quality Tests")
        print("=" * 50)
        
        # Core markdown quality tests
        self.run_test("Markdown structure valid", self.test_markdown_structure_valid)
        self.run_test("Code blocks properly formatted", self.test_code_blocks_properly_formatted)
        self.run_test("Internal links valid", self.test_internal_links_valid)
        self.run_test("External links basic format", self.test_external_links_basic_format)
        self.run_test("Table formatting consistent", self.test_table_formatting_consistent)
        self.run_test("List formatting consistent", self.test_list_formatting_consistent)
        self.run_test("No common markdown errors", self.test_no_common_markdown_errors)
        self.run_test("Badges functional", self.test_badges_functional)
        self.run_test("Documentation completeness metrics", self.test_documentation_completeness_metrics)
        
        # Results summary
        print("\n" + "=" * 50)
        print(f"📊 Markdown Quality Test Results:")
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
    tester = MarkdownQualityTests()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
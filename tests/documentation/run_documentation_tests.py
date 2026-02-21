#!/usr/bin/env python3
"""
Master Documentation Test Runner for PortableRalph
Runs all documentation tests and provides comprehensive reporting

TDD approach for p4-4 documentation production readiness:
- Run all documentation validation tests
- Provide comprehensive reporting
- Generate actionable improvement recommendations
"""

import sys
import os
import json
import subprocess
from pathlib import Path
from datetime import datetime

# Add current directory to path to import test modules
sys.path.insert(0, str(Path(__file__).parent))

try:
    from test_documentation_coverage import DocumentationCoverageTests
    from test_markdown_quality import MarkdownQualityTests
    from test_installation_procedures import InstallationProcedureTests
except ImportError as e:
    print(f"❌ Failed to import test modules: {e}")
    sys.exit(1)

class DocumentationTestRunner:
    def __init__(self):
        self.repo_root = Path(__file__).parent.parent.parent
        self.test_results = {}
        self.overall_results = {
            "total_tests": 0,
            "passed_tests": 0,
            "failed_tests": 0,
            "test_suites": 0,
            "passed_suites": 0,
            "failed_suites": 0
        }

    def run_test_suite(self, suite_name, test_class):
        """Run a test suite and collect results"""
        print(f"\n🚀 Running {suite_name}")
        print("=" * 60)
        
        try:
            tester = test_class()
            success = tester.run_all_tests()
            
            self.test_results[suite_name] = {
                "success": success,
                "results": tester.results
            }
            
            # Update overall results
            self.overall_results["test_suites"] += 1
            self.overall_results["total_tests"] += tester.results["total_tests"]
            self.overall_results["passed_tests"] += tester.results["passed_tests"]
            self.overall_results["failed_tests"] += tester.results["failed_tests"]
            
            if success:
                self.overall_results["passed_suites"] += 1
            else:
                self.overall_results["failed_suites"] += 1
                
            return success
        except Exception as e:
            print(f"❌ Test suite {suite_name} crashed: {e}")
            self.test_results[suite_name] = {
                "success": False,
                "error": str(e),
                "results": {"total_tests": 0, "passed_tests": 0, "failed_tests": 1, "failures": []}
            }
            self.overall_results["test_suites"] += 1
            self.overall_results["failed_suites"] += 1
            self.overall_results["failed_tests"] += 1
            return False

    def generate_detailed_report(self):
        """Generate detailed test report"""
        print("\n" + "=" * 80)
        print("📋 COMPREHENSIVE DOCUMENTATION TEST REPORT")
        print("=" * 80)
        
        print(f"🕐 Test Run: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"📁 Repository: {self.repo_root}")
        
        print(f"\n📊 Overall Results:")
        print(f"   Test Suites: {self.overall_results['test_suites']}")
        print(f"   Passed Suites: ✅ {self.overall_results['passed_suites']}")
        print(f"   Failed Suites: ❌ {self.overall_results['failed_suites']}")
        print(f"   Total Tests: {self.overall_results['total_tests']}")
        print(f"   Passed Tests: ✅ {self.overall_results['passed_tests']}")
        print(f"   Failed Tests: ❌ {self.overall_results['failed_tests']}")
        
        suite_success_rate = (self.overall_results["passed_suites"] / self.overall_results["test_suites"]) * 100
        test_success_rate = (self.overall_results["passed_tests"] / max(self.overall_results["total_tests"], 1)) * 100
        
        print(f"   Suite Success Rate: {suite_success_rate:.1f}%")
        print(f"   Test Success Rate: {test_success_rate:.1f}%")
        
        # Detailed suite results
        print(f"\n📋 Suite-by-Suite Results:")
        for suite_name, results in self.test_results.items():
            status = "✅ PASSED" if results["success"] else "❌ FAILED"
            print(f"   {suite_name}: {status}")
            
            if "results" in results:
                r = results["results"]
                print(f"      Tests: {r['passed_tests']}/{r['total_tests']} passed")
                if r["failures"]:
                    print(f"      Failures: {len(r['failures'])}")
        
        # Failure analysis
        if self.overall_results["failed_tests"] > 0:
            print(f"\n🔍 Failure Analysis:")
            for suite_name, results in self.test_results.items():
                if not results["success"]:
                    print(f"\n   {suite_name} Failures:")
                    if "results" in results and results["results"]["failures"]:
                        for failure in results["results"]["failures"]:
                            print(f"      • {failure['test']}: {failure['error']}")
                    elif "error" in results:
                        print(f"      • Suite crashed: {results['error']}")
        
        # Recommendations
        print(f"\n💡 Recommendations:")
        if test_success_rate >= 90:
            print("   🎉 Excellent! Documentation is production-ready.")
        elif test_success_rate >= 75:
            print("   🔧 Good foundation. Address the failing tests for full production readiness.")
        elif test_success_rate >= 50:
            print("   ⚠️ Moderate issues. Significant documentation improvements needed.")
        else:
            print("   🚨 Major issues. Comprehensive documentation updates required.")
        
        return test_success_rate

    def save_results_json(self):
        """Save results to JSON file for CI/CD integration"""
        results_file = self.repo_root / "tests" / "documentation" / "test_results.json"
        
        json_results = {
            "timestamp": datetime.now().isoformat(),
            "overall_results": self.overall_results,
            "test_suites": self.test_results,
            "success": self.overall_results["failed_tests"] == 0,
            "success_rate": (self.overall_results["passed_tests"] / max(self.overall_results["total_tests"], 1)) * 100
        }
        
        try:
            with open(results_file, 'w') as f:
                json.dump(json_results, f, indent=2)
            print(f"\n💾 Results saved to: {results_file}")
        except Exception as e:
            print(f"⚠️  Failed to save results JSON: {e}")

    def run_all_documentation_tests(self):
        """Run all documentation test suites"""
        print("🧪 PORTABLERALPH DOCUMENTATION TEST SUITE")
        print("=" * 80)
        print("Testing documentation for production readiness based on:")
        print("  • p4-1: Security audit findings")
        print("  • p4-2: Code quality review findings")
        print("  • Phase 3: Windows compatibility requirements")
        print("=" * 80)
        
        # Run all test suites
        test_suites = [
            ("Documentation Coverage", DocumentationCoverageTests),
            ("Markdown Quality", MarkdownQualityTests),
            ("Installation Procedures", InstallationProcedureTests)
        ]
        
        all_passed = True
        for suite_name, test_class in test_suites:
            success = self.run_test_suite(suite_name, test_class)
            if not success:
                all_passed = False
        
        # Generate comprehensive report
        success_rate = self.generate_detailed_report()
        
        # Save results for CI/CD
        self.save_results_json()
        
        # Return overall success
        return all_passed and success_rate >= 85  # 85% minimum for production readiness

if __name__ == "__main__":
    runner = DocumentationTestRunner()
    success = runner.run_all_documentation_tests()
    
    print(f"\n{'='*80}")
    if success:
        print("🎉 ALL DOCUMENTATION TESTS PASSED - PRODUCTION READY!")
    else:
        print("❌ DOCUMENTATION TESTS FAILED - IMPROVEMENTS NEEDED")
    print(f"{'='*80}")
    
    sys.exit(0 if success else 1)
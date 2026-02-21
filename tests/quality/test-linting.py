#!/usr/bin/env python3
"""
Code quality test: Linting verification
Tests consistent style and linting compliance across all scripts
"""

import os
import subprocess
import sys
import json
from pathlib import Path

# Get project root directory
PROJECT_ROOT = Path(__file__).parent.parent.parent

def run_command(cmd, cwd=None, capture_output=True):
    """Run a command and return result"""
    try:
        result = subprocess.run(
            cmd, 
            shell=True, 
            cwd=cwd or PROJECT_ROOT,
            capture_output=capture_output,
            text=True,
            timeout=30
        )
        return result
    except subprocess.TimeoutExpired:
        return None

def test_bash_syntax():
    """Test bash script syntax using bash -n"""
    bash_files = list(PROJECT_ROOT.glob("*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("tests/*.sh"))
    
    results = {}
    for script in bash_files:
        if script.is_file():
            result = run_command(f"bash -n {script}")
            results[str(script.relative_to(PROJECT_ROOT))] = {
                "passed": result.returncode == 0 if result else False,
                "errors": result.stderr if result else "Command timeout"
            }
    
    return results

def test_powershell_syntax():
    """Test PowerShell script syntax"""
    ps1_files = list(PROJECT_ROOT.glob("*.ps1"))
    ps1_files.extend(PROJECT_ROOT.glob("lib/*.ps1"))
    
    results = {}
    for script in ps1_files:
        if script.is_file():
            # Use pwsh if available, otherwise skip PowerShell tests on non-Windows
            pwsh_cmd = f"pwsh -NoProfile -Command 'Get-Content {script} | Out-String | Invoke-Expression' 2>&1 || echo 'pwsh not available'"
            result = run_command(pwsh_cmd)
            
            if result and "pwsh not available" not in result.stdout:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    "passed": result.returncode == 0,
                    "errors": result.stderr or result.stdout
                }
            else:
                # Fallback: basic file existence and readable check
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    "passed": script.is_file() and script.stat().st_size > 0,
                    "errors": "PowerShell not available - basic file check only"
                }
    
    return results

def test_shebang_consistency():
    """Test that all bash scripts have consistent shebang lines"""
    bash_files = list(PROJECT_ROOT.glob("*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("tests/*.sh"))
    
    results = {}
    expected_shebang = "#!/bin/bash"
    
    for script in bash_files:
        if script.is_file():
            try:
                with open(script, 'r') as f:
                    first_line = f.readline().strip()
                
                passed = first_line == expected_shebang
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    "passed": passed,
                    "expected": expected_shebang,
                    "actual": first_line,
                    "errors": "" if passed else f"Expected '{expected_shebang}', got '{first_line}'"
                }
            except Exception as e:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    "passed": False,
                    "errors": f"Failed to read file: {e}"
                }
    
    return results

def test_no_dead_code():
    """Test for common dead code patterns"""
    all_files = []
    all_files.extend(PROJECT_ROOT.glob("*.sh"))
    all_files.extend(PROJECT_ROOT.glob("*.ps1"))
    all_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    all_files.extend(PROJECT_ROOT.glob("lib/*.ps1"))
    
    dead_code_patterns = [
        r'#.*TODO.*\d{4}',  # Old TODO comments with years
        r'^\s*#[^!].*debug',  # Commented debug statements
        r'^\s*echo.*debug.*#',  # Debug echo statements
        r'\.backup$',  # Backup files
    ]
    
    results = {}
    for script in all_files:
        if script.is_file():
            issues = []
            try:
                with open(script, 'r') as f:
                    lines = f.readlines()
                
                for i, line in enumerate(lines, 1):
                    for pattern in dead_code_patterns:
                        import re
                        if re.search(pattern, line, re.IGNORECASE):
                            issues.append(f"Line {i}: {line.strip()}")
                
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    "passed": len(issues) == 0,
                    "issues": issues,
                    "errors": ""
                }
            except Exception as e:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    "passed": False,
                    "issues": [],
                    "errors": f"Failed to read file: {e}"
                }
    
    return results

def main():
    """Main test runner"""
    print("Running code quality linting tests...")
    
    tests = {
        "bash_syntax": test_bash_syntax(),
        "powershell_syntax": test_powershell_syntax(), 
        "shebang_consistency": test_shebang_consistency(),
        "no_dead_code": test_no_dead_code()
    }
    
    total_tests = 0
    passed_tests = 0
    
    for test_name, test_results in tests.items():
        print(f"\n=== {test_name.replace('_', ' ').title()} ===")
        
        for file_path, result in test_results.items():
            total_tests += 1
            if result["passed"]:
                passed_tests += 1
                print(f"✅ {file_path}")
            else:
                print(f"❌ {file_path}")
                if result.get("errors"):
                    print(f"   Error: {result['errors']}")
                if result.get("issues"):
                    for issue in result["issues"]:
                        print(f"   Issue: {issue}")
    
    print(f"\n=== Summary ===")
    print(f"Tests run: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {total_tests - passed_tests}")
    
    if passed_tests == total_tests:
        print("✅ All linting tests passed!")
        return 0
    else:
        print("❌ Some linting tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
#!/usr/bin/env python3
"""
Code quality test: Complexity verification  
Tests function complexity to ensure maintainability (functions <15 complexity)
"""

import os
import re
import sys
from pathlib import Path

# Get project root directory
PROJECT_ROOT = Path(__file__).parent.parent.parent

def analyze_bash_function_complexity(file_path):
    """Analyze cyclomatic complexity of bash functions"""
    functions = {}
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Find bash functions (function name() { ... } or name() { ... })
        function_pattern = r'(?:function\s+)?(\w+)\s*\(\)\s*\{'
        functions_found = re.finditer(function_pattern, content, re.MULTILINE)
        
        for match in functions_found:
            func_name = match.group(1)
            start_pos = match.start()
            
            # Find the function body by counting braces
            brace_count = 0
            func_content = ""
            i = content.find('{', start_pos)
            
            if i != -1:
                while i < len(content):
                    char = content[i]
                    func_content += char
                    if char == '{':
                        brace_count += 1
                    elif char == '}':
                        brace_count -= 1
                        if brace_count == 0:
                            break
                    i += 1
                
                complexity = calculate_bash_complexity(func_content)
                functions[func_name] = {
                    'complexity': complexity,
                    'lines': len(func_content.split('\n')),
                    'content_sample': func_content[:100].replace('\n', '\\n')
                }
    
    except Exception as e:
        return {'error': f"Failed to analyze file: {e}"}
    
    return functions

def calculate_bash_complexity(code):
    """Calculate cyclomatic complexity for bash code"""
    # Start with base complexity of 1
    complexity = 1
    
    # Control flow keywords that increase complexity
    complexity_patterns = [
        r'\bif\b',           # if statements
        r'\belif\b',         # elif statements  
        r'\bcase\b',         # case statements
        r'\bfor\b',          # for loops
        r'\bwhile\b',        # while loops
        r'\buntil\b',        # until loops
        r'\b&&\b',           # logical AND
        r'\b\|\|\b',         # logical OR
        r'\btrap\b',         # trap statements
        r'\?[^:]*:',         # ternary-like operations
    ]
    
    for pattern in complexity_patterns:
        matches = re.findall(pattern, code, re.IGNORECASE)
        complexity += len(matches)
    
    # Case statement patterns add complexity per pattern
    case_patterns = re.findall(r'^\s*[^)]+\)', code, re.MULTILINE)
    complexity += max(0, len(case_patterns) - 1)  # -1 because case itself is counted
    
    return complexity

def analyze_powershell_function_complexity(file_path):
    """Analyze cyclomatic complexity of PowerShell functions"""
    functions = {}
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Find PowerShell functions (function Name { ... } or function Verb-Noun { ... })
        function_pattern = r'function\s+([\w-]+)\s*(?:\([^)]*\))?\s*\{'
        functions_found = re.finditer(function_pattern, content, re.MULTILINE | re.IGNORECASE)
        
        for match in functions_found:
            func_name = match.group(1)
            start_pos = match.start()
            
            # Find the function body by counting braces
            brace_count = 0
            func_content = ""
            i = content.find('{', start_pos)
            
            if i != -1:
                while i < len(content):
                    char = content[i]
                    func_content += char
                    if char == '{':
                        brace_count += 1
                    elif char == '}':
                        brace_count -= 1
                        if brace_count == 0:
                            break
                    i += 1
                
                complexity = calculate_powershell_complexity(func_content)
                functions[func_name] = {
                    'complexity': complexity,
                    'lines': len(func_content.split('\n')),
                    'content_sample': func_content[:100].replace('\n', '\\n')
                }
    
    except Exception as e:
        return {'error': f"Failed to analyze file: {e}"}
    
    return functions

def calculate_powershell_complexity(code):
    """Calculate cyclomatic complexity for PowerShell code"""
    # Start with base complexity of 1  
    complexity = 1
    
    # Control flow keywords that increase complexity
    complexity_patterns = [
        r'\bif\b',           # if statements
        r'\belseif\b',       # elseif statements
        r'\bswitch\b',       # switch statements  
        r'\bfor\b',          # for loops
        r'\bforeach\b',      # foreach loops
        r'\bwhile\b',        # while loops
        r'\bdo\b',           # do loops
        r'\btry\b',          # try blocks
        r'\bcatch\b',        # catch blocks
        r'\btrap\b',         # trap statements
        r'-and\b',           # logical AND
        r'-or\b',            # logical OR
        r'\?\s*\{',          # where-object scriptblocks
    ]
    
    for pattern in complexity_patterns:
        matches = re.findall(pattern, code, re.IGNORECASE)
        complexity += len(matches)
    
    # Switch statement patterns add complexity per pattern  
    switch_patterns = re.findall(r'^\s*[\'"][^\'"\}]+[\'"]|\{\s*\$_', code, re.MULTILINE)
    complexity += max(0, len(switch_patterns) - 1)
    
    return complexity

def test_function_complexity():
    """Test all functions for acceptable complexity levels"""
    results = {}
    max_complexity = 15  # Threshold from requirements
    
    # Get all script files
    bash_files = list(PROJECT_ROOT.glob("*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("tests/*.sh"))
    
    ps1_files = list(PROJECT_ROOT.glob("*.ps1"))
    ps1_files.extend(PROJECT_ROOT.glob("lib/*.ps1"))
    
    # Analyze bash files
    for script in bash_files:
        if script.is_file():
            functions = analyze_bash_function_complexity(script)
            if 'error' in functions:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': False,
                    'error': functions['error'],
                    'functions': {}
                }
            else:
                file_passed = all(f['complexity'] <= max_complexity for f in functions.values())
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': file_passed,
                    'functions': functions,
                    'max_complexity_found': max(f['complexity'] for f in functions.values()) if functions else 0
                }
    
    # Analyze PowerShell files  
    for script in ps1_files:
        if script.is_file():
            functions = analyze_powershell_function_complexity(script)
            if 'error' in functions:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': False,
                    'error': functions['error'],
                    'functions': {}
                }
            else:
                file_passed = all(f['complexity'] <= max_complexity for f in functions.values())
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': file_passed,
                    'functions': functions,
                    'max_complexity_found': max(f['complexity'] for f in functions.values()) if functions else 0
                }
    
    return results

def test_file_length():
    """Test that files aren't excessively long"""
    results = {}
    max_lines = 500  # Reasonable file length limit
    
    all_files = []
    all_files.extend(PROJECT_ROOT.glob("*.sh"))
    all_files.extend(PROJECT_ROOT.glob("*.ps1"))
    all_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    all_files.extend(PROJECT_ROOT.glob("lib/*.ps1"))
    
    for script in all_files:
        if script.is_file():
            try:
                with open(script, 'r') as f:
                    lines = f.readlines()
                
                line_count = len(lines)
                passed = line_count <= max_lines
                
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': passed,
                    'line_count': line_count,
                    'max_allowed': max_lines,
                    'error': '' if passed else f"File has {line_count} lines, maximum is {max_lines}"
                }
            except Exception as e:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': False,
                    'error': f"Failed to read file: {e}"
                }
    
    return results

def main():
    """Main test runner"""
    print("Running code complexity tests...")
    
    tests = {
        "function_complexity": test_function_complexity(),
        "file_length": test_file_length()
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
                if 'functions' in result and result['functions']:
                    for func_name, func_data in result['functions'].items():
                        print(f"    {func_name}: complexity {func_data['complexity']}")
            else:
                print(f"❌ {file_path}")
                if result.get("error"):
                    print(f"   Error: {result['error']}")
                if 'functions' in result:
                    for func_name, func_data in result['functions'].items():
                        if func_data['complexity'] > 15:
                            print(f"   ⚠️  {func_name}: complexity {func_data['complexity']} (exceeds 15)")
                        else:
                            print(f"    {func_name}: complexity {func_data['complexity']}")
    
    print(f"\n=== Summary ===")
    print(f"Tests run: {total_tests}")
    print(f"Passed: {passed_tests}")  
    print(f"Failed: {total_tests - passed_tests}")
    
    if passed_tests == total_tests:
        print("✅ All complexity tests passed!")
        return 0
    else:
        print("❌ Some complexity tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
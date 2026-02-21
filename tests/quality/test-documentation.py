#!/usr/bin/env python3
"""
Code quality test: Documentation verification
Tests docstring coverage and documentation quality
"""

import os
import re
import sys
from pathlib import Path

# Get project root directory
PROJECT_ROOT = Path(__file__).parent.parent.parent

def analyze_bash_function_documentation(file_path):
    """Analyze documentation coverage of bash functions"""
    functions = {}
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Find bash functions and their preceding comments
        lines = content.split('\n')
        
        for i, line in enumerate(lines):
            # Look for function definitions
            func_match = re.match(r'^\s*(?:function\s+)?(\w+)\s*\(\)\s*\{?\s*$', line)
            if func_match:
                func_name = func_match.group(1)
                
                # Skip internal/private functions (starting with _)
                if func_name.startswith('_'):
                    continue
                
                # Look backwards for documentation comments
                doc_lines = []
                j = i - 1
                while j >= 0 and (lines[j].strip().startswith('#') or lines[j].strip() == ''):
                    if lines[j].strip().startswith('#') and not lines[j].strip().startswith('#!/'):
                        doc_lines.insert(0, lines[j].strip())
                    j -= 1
                
                # Analyze documentation quality
                has_description = any('Args:' not in line and 'Returns:' not in line and len(line) > 2 for line in doc_lines)
                has_args_section = any('Args:' in line or 'Arguments:' in line for line in doc_lines)
                has_returns_section = any('Returns:' in line or 'Return:' in line for line in doc_lines)
                
                # Check if function actually takes parameters or returns values
                function_start = i
                function_end = find_function_end(lines, function_start)
                function_body = '\n'.join(lines[function_start:function_end + 1])
                
                uses_params = bool(re.search(r'\$[1-9]|\$@|\$\*', function_body))
                has_return = bool(re.search(r'\breturn\b', function_body))
                
                functions[func_name] = {
                    'line_number': i + 1,
                    'has_description': has_description,
                    'has_args_section': has_args_section,
                    'has_returns_section': has_returns_section,
                    'uses_params': uses_params,
                    'has_return': has_return,
                    'doc_lines': len(doc_lines),
                    'documentation': '\n'.join(doc_lines) if doc_lines else '',
                    'needs_args_doc': uses_params and not has_args_section,
                    'needs_returns_doc': has_return and not has_returns_section
                }
    
    except Exception as e:
        return {'error': f"Failed to analyze file: {e}"}
    
    return functions

def analyze_powershell_function_documentation(file_path):
    """Analyze documentation coverage of PowerShell functions"""
    functions = {}
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Find PowerShell functions with comment-based help
        lines = content.split('\n')
        
        for i, line in enumerate(lines):
            # Look for function definitions
            func_match = re.match(r'^\s*function\s+([\w-]+)', line, re.IGNORECASE)
            if func_match:
                func_name = func_match.group(1)
                
                # Look backwards and forwards for comment-based help (<#...#>)
                help_block = find_powershell_help_block(lines, i)
                
                # Analyze help block content
                has_synopsis = '<#' in help_block and '.SYNOPSIS' in help_block.upper()
                has_description = '.DESCRIPTION' in help_block.upper()
                has_parameter = '.PARAMETER' in help_block.upper()
                has_example = '.EXAMPLE' in help_block.upper()
                has_outputs = '.OUTPUTS' in help_block.upper()
                
                # Check if function has parameters
                function_start = i
                function_end = find_powershell_function_end(lines, function_start)
                function_body = '\n'.join(lines[function_start:function_end + 1])
                
                has_params = bool(re.search(r'\[Parameter\(|\$\w+', function_body))
                has_return_statement = bool(re.search(r'\breturn\b|\$PSCmdlet\.WriteObject', function_body, re.IGNORECASE))
                
                functions[func_name] = {
                    'line_number': i + 1,
                    'has_synopsis': has_synopsis,
                    'has_description': has_description,
                    'has_parameter': has_parameter,
                    'has_example': has_example,
                    'has_outputs': has_outputs,
                    'has_params': has_params,
                    'has_return_statement': has_return_statement,
                    'help_block_length': len(help_block.split('\n')),
                    'documentation': help_block,
                    'needs_parameter_doc': has_params and not has_parameter,
                    'needs_outputs_doc': has_return_statement and not has_outputs
                }
    
    except Exception as e:
        return {'error': f"Failed to analyze file: {e}"}
    
    return functions

def find_function_end(lines, start):
    """Find the end of a bash function by counting braces"""
    brace_count = 0
    in_function = False
    
    for i in range(start, len(lines)):
        line = lines[i].strip()
        if '{' in line:
            brace_count += line.count('{')
            in_function = True
        if '}' in line:
            brace_count -= line.count('}')
        
        if in_function and brace_count == 0:
            return i
    
    return len(lines) - 1

def find_powershell_function_end(lines, start):
    """Find the end of a PowerShell function by counting braces"""
    brace_count = 0
    in_function = False
    
    for i in range(start, len(lines)):
        line = lines[i].strip()
        if '{' in line:
            brace_count += line.count('{')
            in_function = True
        if '}' in line:
            brace_count -= line.count('}')
        
        if in_function and brace_count == 0:
            return i
    
    return len(lines) - 1

def find_powershell_help_block(lines, func_line):
    """Find PowerShell comment-based help block near function"""
    help_block = ""
    
    # Look backwards for help block
    i = func_line - 1
    while i >= 0:
        line = lines[i].strip()
        if line.startswith('<#'):
            # Found start of help block, collect until #>
            j = i
            while j < len(lines):
                help_block = lines[j] + '\n' + help_block
                if '#>' in lines[j]:
                    break
                j += 1
            break
        elif line and not line.startswith('#'):
            # Hit non-comment line, stop looking
            break
        i -= 1
    
    # Look forwards if not found backwards
    if not help_block:
        i = func_line + 1
        while i < len(lines):
            line = lines[i].strip()
            if line.startswith('<#'):
                # Found start of help block
                while i < len(lines):
                    help_block += lines[i] + '\n'
                    if '#>' in lines[i]:
                        break
                    i += 1
                break
            elif line and not line.startswith('#'):
                break
            i += 1
    
    return help_block

def test_bash_documentation():
    """Test bash function documentation coverage"""
    results = {}
    
    bash_files = list(PROJECT_ROOT.glob("*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    
    for script in bash_files:
        if script.is_file():
            functions = analyze_bash_function_documentation(script)
            if 'error' in functions:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': False,
                    'error': functions['error'],
                    'functions': {}
                }
            else:
                # Calculate documentation score
                total_functions = len(functions)
                if total_functions == 0:
                    results[str(script.relative_to(PROJECT_ROOT))] = {
                        'passed': True,
                        'functions': {},
                        'score': 100,
                        'documented_functions': 0,
                        'total_functions': 0
                    }
                else:
                    documented_count = 0
                    issues = []
                    
                    for func_name, func_data in functions.items():
                        func_issues = []
                        
                        if not func_data['has_description']:
                            func_issues.append("Missing description")
                        if func_data['needs_args_doc']:
                            func_issues.append("Uses parameters but missing Args documentation")
                        if func_data['needs_returns_doc']:
                            func_issues.append("Has return statement but missing Returns documentation")
                        
                        if not func_issues:
                            documented_count += 1
                        else:
                            issues.append(f"{func_name}: {', '.join(func_issues)}")
                    
                    score = (documented_count / total_functions) * 100
                    passed = score >= 80  # 80% documentation threshold
                    
                    results[str(script.relative_to(PROJECT_ROOT))] = {
                        'passed': passed,
                        'functions': functions,
                        'score': score,
                        'documented_functions': documented_count,
                        'total_functions': total_functions,
                        'issues': issues
                    }
    
    return results

def test_powershell_documentation():
    """Test PowerShell function documentation coverage"""  
    results = {}
    
    ps1_files = list(PROJECT_ROOT.glob("*.ps1"))
    ps1_files.extend(PROJECT_ROOT.glob("lib/*.ps1"))
    
    for script in ps1_files:
        if script.is_file():
            functions = analyze_powershell_function_documentation(script)
            if 'error' in functions:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': False,
                    'error': functions['error'],
                    'functions': {}
                }
            else:
                # Calculate documentation score
                total_functions = len(functions)
                if total_functions == 0:
                    results[str(script.relative_to(PROJECT_ROOT))] = {
                        'passed': True,
                        'functions': {},
                        'score': 100,
                        'documented_functions': 0,
                        'total_functions': 0
                    }
                else:
                    documented_count = 0
                    issues = []
                    
                    for func_name, func_data in functions.items():
                        func_issues = []
                        
                        if not func_data['has_synopsis']:
                            func_issues.append("Missing .SYNOPSIS")
                        if func_data['needs_parameter_doc']:
                            func_issues.append("Has parameters but missing .PARAMETER documentation")  
                        if func_data['needs_outputs_doc']:
                            func_issues.append("Has return/output but missing .OUTPUTS documentation")
                        
                        if not func_issues:
                            documented_count += 1
                        else:
                            issues.append(f"{func_name}: {', '.join(func_issues)}")
                    
                    score = (documented_count / total_functions) * 100
                    passed = score >= 80  # 80% documentation threshold
                    
                    results[str(script.relative_to(PROJECT_ROOT))] = {
                        'passed': passed,
                        'functions': functions,
                        'score': score,
                        'documented_functions': documented_count,
                        'total_functions': total_functions,
                        'issues': issues
                    }
    
    return results

def test_file_headers():
    """Test that files have proper header documentation"""
    results = {}
    
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
                
                # Check first 20 lines for header elements
                header_content = ''.join(lines[:20])
                
                has_shebang = lines[0].strip().startswith('#!')
                has_description = any('Usage:' in line or 'Description:' in line or len(line.strip()) > 10 
                                    for line in lines[1:10] if line.strip().startswith('#'))
                has_usage = 'Usage:' in header_content or 'usage:' in header_content.lower()
                
                issues = []
                if not has_shebang and script.suffix in ['.sh']:
                    issues.append("Missing shebang line")
                if not has_description:
                    issues.append("Missing file description")
                if not has_usage and not script.name.startswith('lib'):
                    issues.append("Missing usage information")
                
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': len(issues) == 0,
                    'has_shebang': has_shebang,
                    'has_description': has_description,
                    'has_usage': has_usage,
                    'issues': issues
                }
                
            except Exception as e:
                results[str(script.relative_to(PROJECT_ROOT))] = {
                    'passed': False,
                    'error': f"Failed to read file: {e}"
                }
    
    return results

def main():
    """Main test runner"""
    print("Running documentation quality tests...")
    
    tests = {
        "bash_documentation": test_bash_documentation(),
        "powershell_documentation": test_powershell_documentation(),
        "file_headers": test_file_headers()
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
                if 'score' in result:
                    print(f"    Documentation score: {result['score']:.1f}% ({result['documented_functions']}/{result['total_functions']} functions)")
            else:
                print(f"❌ {file_path}")
                if result.get("error"):
                    print(f"   Error: {result['error']}")
                if result.get("issues"):
                    for issue in result["issues"]:
                        print(f"   Issue: {issue}")
                if 'score' in result:
                    print(f"    Documentation score: {result['score']:.1f}% ({result['documented_functions']}/{result['total_functions']} functions)")
    
    print(f"\n=== Summary ===")
    print(f"Tests run: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {total_tests - passed_tests}")
    
    if passed_tests == total_tests:
        print("✅ All documentation tests passed!")
        return 0
    else:
        print("❌ Some documentation tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
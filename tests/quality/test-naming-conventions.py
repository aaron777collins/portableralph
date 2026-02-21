#!/usr/bin/env python3
"""
Code quality test: Naming conventions verification
Tests consistent naming conventions across bash and PowerShell scripts
"""

import os
import re
import sys
from pathlib import Path

# Get project root directory
PROJECT_ROOT = Path(__file__).parent.parent.parent

def analyze_bash_naming_conventions(file_path):
    """Analyze bash naming conventions"""
    violations = []
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            lines = content.split('\n')
        
        # Check function names (should be snake_case)
        function_pattern = r'^\s*(?:function\s+)?(\w+)\s*\(\)'
        for i, line in enumerate(lines):
            match = re.match(function_pattern, line)
            if match:
                func_name = match.group(1)
                if not is_valid_bash_function_name(func_name):
                    violations.append({
                        'type': 'function_name',
                        'line': i + 1,
                        'name': func_name,
                        'issue': 'Function names should use snake_case'
                    })
        
        # Check variable assignments (local variables should be snake_case, constants UPPER_CASE)
        variable_pattern = r'^\s*(\w+)=([\'"][^\'"\n]*[\'"]|[^#\s]+)'
        for i, line in enumerate(lines):
            match = re.match(variable_pattern, line)
            if match:
                var_name = match.group(1)
                var_value = match.group(2)
                
                # Skip special bash variables
                if var_name in ['IFS', 'PATH', 'HOME', 'PWD', 'OLDPWD', 'SHELL', 'USER', 'UID']:
                    continue
                
                # Check if it's likely a constant (all caps, or readonly)
                is_constant = var_name.isupper() or 'readonly' in line
                
                if is_constant:
                    if not is_valid_bash_constant_name(var_name):
                        violations.append({
                            'type': 'constant_name',
                            'line': i + 1,
                            'name': var_name,
                            'issue': 'Constants should use UPPER_CASE_WITH_UNDERSCORES'
                        })
                else:
                    if not is_valid_bash_variable_name(var_name):
                        violations.append({
                            'type': 'variable_name',
                            'line': i + 1,
                            'name': var_name,
                            'issue': 'Local variables should use snake_case'
                        })
        
        # Check for inconsistent quote usage in echo statements
        echo_pattern = r'echo\s+([\'"][^\'"]*[\'"]|\$\w+|[^#\n]+)'
        for i, line in enumerate(lines):
            if 'echo' in line and not line.strip().startswith('#'):
                # Check for mixed quoting styles in same line
                single_quotes = line.count("'")
                double_quotes = line.count('"')
                if single_quotes > 0 and double_quotes > 0:
                    violations.append({
                        'type': 'mixed_quotes',
                        'line': i + 1,
                        'name': 'echo statement',
                        'issue': 'Mixed single and double quotes in same statement'
                    })
    
    except Exception as e:
        return [{'type': 'error', 'line': 0, 'name': str(file_path), 'issue': f"Failed to analyze: {e}"}]
    
    return violations

def analyze_powershell_naming_conventions(file_path):
    """Analyze PowerShell naming conventions"""
    violations = []
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            lines = content.split('\n')
        
        # Check function names (should use Verb-Noun or PascalCase)
        function_pattern = r'^\s*function\s+([\w-]+)'
        for i, line in enumerate(lines):
            match = re.match(function_pattern, line, re.IGNORECASE)
            if match:
                func_name = match.group(1)
                if not is_valid_powershell_function_name(func_name):
                    violations.append({
                        'type': 'function_name',
                        'line': i + 1,
                        'name': func_name,
                        'issue': 'PowerShell functions should use Verb-Noun pattern or PascalCase'
                    })
        
        # Check variable names (should be $PascalCase or $camelCase)
        variable_pattern = r'\$(\w+)\s*='
        for i, line in enumerate(lines):
            matches = re.findall(variable_pattern, line)
            for var_name in matches:
                # Skip automatic variables
                if var_name in ['_', 'args', 'error', 'host', 'input', 'lastexitcode', 'matches', 'null', 'pscmdlet', 'pshome', 'psitem', 'psversiontable', 'pwd', 'true', 'false']:
                    continue
                
                if not is_valid_powershell_variable_name(var_name):
                    violations.append({
                        'type': 'variable_name',
                        'line': i + 1,
                        'name': var_name,
                        'issue': 'PowerShell variables should use PascalCase or camelCase'
                    })
        
        # Check parameter naming in function definitions
        param_pattern = r'\[Parameter.*?\]\s*\[.*?\]\s*\$(\w+)'
        for i, line in enumerate(lines):
            matches = re.findall(param_pattern, line, re.IGNORECASE)
            for param_name in matches:
                if not is_valid_powershell_parameter_name(param_name):
                    violations.append({
                        'type': 'parameter_name',
                        'line': i + 1,
                        'name': param_name,
                        'issue': 'PowerShell parameters should use PascalCase'
                    })
        
        # Check for inconsistent string quote usage
        for i, line in enumerate(lines):
            # Skip comments
            if line.strip().startswith('#'):
                continue
                
            # Count single vs double quotes in string contexts
            in_string = False
            quote_char = None
            mixed_quotes = False
            
            for j, char in enumerate(line):
                if not in_string and char in ['"', "'"]:
                    in_string = True
                    quote_char = char
                elif in_string and char == quote_char:
                    # Check if it's escaped
                    if j == 0 or line[j-1] != '`':
                        in_string = False
                        quote_char = None
                elif not in_string and char in ['"', "'"] and quote_char:
                    mixed_quotes = True
                    break
            
            if mixed_quotes:
                violations.append({
                    'type': 'mixed_quotes',
                    'line': i + 1,
                    'name': 'string literal',
                    'issue': 'Mixed quote styles in same line'
                })
    
    except Exception as e:
        return [{'type': 'error', 'line': 0, 'name': str(file_path), 'issue': f"Failed to analyze: {e}"}]
    
    return violations

def is_valid_bash_function_name(name):
    """Check if bash function name follows snake_case convention"""
    # Allow underscore prefixed private functions
    if name.startswith('_'):
        name = name[1:]
    
    # Should be all lowercase with underscores, no numbers at start
    return re.match(r'^[a-z][a-z0-9_]*$', name) is not None

def is_valid_bash_variable_name(name):
    """Check if bash variable name follows snake_case convention"""
    # Allow underscore prefixed variables
    if name.startswith('_'):
        name = name[1:]
    
    # Should be all lowercase with underscores for local variables
    return re.match(r'^[a-z][a-z0-9_]*$', name) is not None

def is_valid_bash_constant_name(name):
    """Check if bash constant name follows UPPER_CASE convention"""
    # Should be all uppercase with underscores
    return re.match(r'^[A-Z][A-Z0-9_]*$', name) is not None

def is_valid_powershell_function_name(name):
    """Check if PowerShell function name follows Verb-Noun or PascalCase convention"""
    # Check for Verb-Noun pattern (approved PowerShell verbs)
    approved_verbs = [
        'Get', 'Set', 'New', 'Remove', 'Clear', 'Add', 'Copy', 'Move', 'Rename',
        'Test', 'Invoke', 'Start', 'Stop', 'Enable', 'Disable', 'Install', 'Uninstall',
        'Write', 'Read', 'Send', 'Receive', 'Connect', 'Disconnect', 'Join', 'Split',
        'Convert', 'ConvertTo', 'ConvertFrom', 'Import', 'Export', 'Select', 'Where',
        'Sort', 'Group', 'Measure', 'Compare', 'Format', 'Out', 'Show', 'Hide',
        'Enter', 'Exit', 'Lock', 'Unlock', 'Submit', 'Block', 'Unblock', 'Grant',
        'Revoke', 'Resolve', 'Compress', 'Expand', 'Optimize', 'Backup', 'Restore',
        'Save', 'Sync', 'Publish', 'Unpublish', 'Search', 'Find', 'Use', 'Undo',
        'Trace', 'Debug', 'Measure', 'Ping', 'Repair', 'Watch', 'Wait'
    ]
    
    # Check Verb-Noun pattern
    if '-' in name:
        parts = name.split('-')
        if len(parts) == 2:
            verb, noun = parts
            return verb in approved_verbs and re.match(r'^[A-Z][A-Za-z0-9]*$', noun)
    
    # Check PascalCase (for legacy or internal functions)
    return re.match(r'^[A-Z][A-Za-z0-9]*$', name) is not None

def is_valid_powershell_variable_name(name):
    """Check if PowerShell variable name follows PascalCase or camelCase convention"""
    # Should start with uppercase (PascalCase) or lowercase (camelCase)
    return re.match(r'^[a-zA-Z][A-Za-z0-9]*$', name) is not None

def is_valid_powershell_parameter_name(name):
    """Check if PowerShell parameter name follows PascalCase convention"""
    # Parameters should be PascalCase
    return re.match(r'^[A-Z][A-Za-z0-9]*$', name) is not None

def test_bash_naming_conventions():
    """Test bash script naming conventions"""
    results = {}
    
    bash_files = list(PROJECT_ROOT.glob("*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    bash_files.extend(PROJECT_ROOT.glob("tests/*.sh"))
    
    for script in bash_files:
        if script.is_file():
            violations = analyze_bash_naming_conventions(script)
            results[str(script.relative_to(PROJECT_ROOT))] = {
                'passed': len(violations) == 0,
                'violations': violations,
                'violation_count': len(violations)
            }
    
    return results

def test_powershell_naming_conventions():
    """Test PowerShell script naming conventions"""
    results = {}
    
    ps1_files = list(PROJECT_ROOT.glob("*.ps1"))
    ps1_files.extend(PROJECT_ROOT.glob("lib/*.ps1"))
    
    for script in ps1_files:
        if script.is_file():
            violations = analyze_powershell_naming_conventions(script)
            results[str(script.relative_to(PROJECT_ROOT))] = {
                'passed': len(violations) == 0,
                'violations': violations,
                'violation_count': len(violations)
            }
    
    return results

def test_file_naming_conventions():
    """Test file naming conventions"""
    results = {}
    
    all_files = []
    all_files.extend(PROJECT_ROOT.glob("*.sh"))
    all_files.extend(PROJECT_ROOT.glob("*.ps1"))
    all_files.extend(PROJECT_ROOT.glob("lib/*.sh"))
    all_files.extend(PROJECT_ROOT.glob("lib/*.ps1"))
    
    for script in all_files:
        if script.is_file():
            violations = []
            filename = script.name
            
            # Check file naming conventions
            if script.suffix == '.sh':
                # Bash scripts should use kebab-case or snake_case
                basename = script.stem
                if not re.match(r'^[a-z][a-z0-9_-]*$', basename):
                    violations.append({
                        'type': 'filename',
                        'name': filename,
                        'issue': 'Bash script names should use lowercase with hyphens or underscores'
                    })
            
            elif script.suffix == '.ps1':
                # PowerShell scripts should use PascalCase or kebab-case
                basename = script.stem
                if not (re.match(r'^[A-Z][A-Za-z0-9]*$', basename) or re.match(r'^[a-z][a-z0-9-]*$', basename)):
                    violations.append({
                        'type': 'filename',
                        'name': filename,
                        'issue': 'PowerShell script names should use PascalCase or kebab-case'
                    })
            
            # Check for backup or temporary file patterns that shouldn't be in repo
            temp_patterns = [r'\.backup$', r'\.tmp$', r'\.temp$', r'~$', r'\.bak$']
            for pattern in temp_patterns:
                if re.search(pattern, filename, re.IGNORECASE):
                    violations.append({
                        'type': 'temp_file',
                        'name': filename,
                        'issue': 'Temporary or backup files should not be committed to repository'
                    })
            
            results[str(script.relative_to(PROJECT_ROOT))] = {
                'passed': len(violations) == 0,
                'violations': violations,
                'violation_count': len(violations)
            }
    
    return results

def main():
    """Main test runner"""
    print("Running naming conventions tests...")
    
    tests = {
        "bash_naming_conventions": test_bash_naming_conventions(),
        "powershell_naming_conventions": test_powershell_naming_conventions(),
        "file_naming_conventions": test_file_naming_conventions()
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
                print(f"❌ {file_path} ({result['violation_count']} violations)")
                for violation in result["violations"]:
                    if violation['type'] == 'error':
                        print(f"   Error: {violation['issue']}")
                    else:
                        line_info = f" (line {violation['line']})" if violation.get('line', 0) > 0 else ""
                        print(f"   {violation['type']}: {violation['name']}{line_info} - {violation['issue']}")
    
    print(f"\n=== Summary ===")
    print(f"Tests run: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {total_tests - passed_tests}")
    
    if passed_tests == total_tests:
        print("✅ All naming convention tests passed!")
        return 0
    else:
        print("❌ Some naming convention tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
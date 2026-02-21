#!/usr/bin/env python3
"""
PowerShell quote balance and syntax validator
Part of pr3-3 TDD approach - write tests first
"""

import sys
import re
import argparse

def analyze_powershell_quotes(content):
    """
    Analyze PowerShell file for quote balance issues.
    Returns (is_balanced, issues, total_quotes)
    """
    issues = []
    total_quotes = 0
    
    lines = content.split('\n')
    in_here_string = False
    here_string_start_line = 0
    
    for i, line in enumerate(lines, 1):
        line_quotes = line.count('"')
        total_quotes += line_quotes
        
        # Check for here-string patterns
        if re.match(r'.*@"$', line.rstrip()):
            if in_here_string:
                issues.append(f"Line {i}: Nested here-string start")
            else:
                in_here_string = True
                here_string_start_line = i
                line_quotes -= 1  # The @" counts as starting delimiter, not unmatched quote
        
        elif re.match(r'^"@', line.strip()):
            if not in_here_string:
                issues.append(f"Line {i}: Here-string end without start")
            else:
                in_here_string = False
                line_quotes -= 1  # The "@ counts as ending delimiter
        
        # For lines not in here-strings, check if quotes are balanced
        elif not in_here_string:
            if line_quotes % 2 != 0:
                issues.append(f"Line {i}: Odd number of quotes ({line_quotes}) - {repr(line.strip())}")
    
    if in_here_string:
        issues.append(f"Unclosed here-string started at line {here_string_start_line}")
    
    is_balanced = (total_quotes % 2 == 0) and len(issues) == 0
    
    return is_balanced, issues, total_quotes

def main():
    parser = argparse.ArgumentParser(description='PowerShell quote balance validator')
    parser.add_argument('file', help='PowerShell file to analyze')
    args = parser.parse_args()
    
    try:
        with open(args.file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        is_balanced, issues, total_quotes = analyze_powershell_quotes(content)
        
        print(f"Analyzing: {args.file}")
        print(f"Total double quotes: {total_quotes}")
        print(f"Quote balance: {'✅ BALANCED' if is_balanced else '❌ UNBALANCED'}")
        
        if issues:
            print("\nIssues found:")
            for issue in issues:
                print(f"  {issue}")
        
        return 0 if is_balanced else 1
        
    except FileNotFoundError:
        print(f"Error: File {args.file} not found")
        return 1
    except Exception as e:
        print(f"Error analyzing file: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
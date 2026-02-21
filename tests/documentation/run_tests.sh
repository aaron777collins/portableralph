#!/bin/bash
# Simple test runner for documentation tests

echo "🧪 Running Documentation Tests"
echo "=" * 50

cd "$(dirname "$0")"

echo "📋 Running Documentation Coverage Tests..."
python3 test-documentation-coverage.py
coverage_result=$?

echo ""
echo "📋 Running Markdown Quality Tests..."
python3 test-markdown-quality.py
markdown_result=$?

echo ""
echo "📋 Running Installation Procedure Tests..."
python3 test-installation-procedures.py
install_result=$?

echo ""
echo "=" * 50
echo "📊 Overall Results:"

total_failed=$((coverage_result + markdown_result + install_result))

if [ $total_failed -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED!"
    exit 0
else
    echo "❌ Some tests failed. Check output above."
    exit 1
fi
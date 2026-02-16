#!/bin/bash
#
# Test Graph Generation
#
# This script tests if LibreNMS can generate graphs properly
#

set -e

echo "=== Testing LibreNMS Graph Generation ==="
echo ""

# Wait for LibreNMS to be fully ready
echo "Waiting for LibreNMS to be ready..."
sleep 5

# Test device_bits graph
echo "1. Testing device_bits graph..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/graph.php?device=1&type=device_bits&from=-1d&legend=no&width=300&height=150")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ device_bits graph: OK (HTTP $HTTP_CODE)"
else
    echo "   ✗ device_bits graph: FAILED (HTTP $HTTP_CODE)"
fi

# Test device_processor graph
echo "2. Testing device_processor graph..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/graph.php?device=1&type=device_processor&from=-1d&legend=no&width=300&height=150")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ device_processor graph: OK (HTTP $HTTP_CODE)"
else
    echo "   ✗ device_processor graph: FAILED (HTTP $HTTP_CODE)"
fi

# Test device_mempool graph
echo "3. Testing device_mempool graph..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/graph.php?device=1&type=device_mempool&from=-1d&legend=no&width=300&height=150")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ device_mempool graph: OK (HTTP $HTTP_CODE)"
else
    echo "   ✗ device_mempool graph: FAILED (HTTP $HTTP_CODE)"
fi

# Test port_bits graph
echo "4. Testing port_bits graph..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/graph.php?id=1&type=port_bits&from=-1d&legend=yes&width=300&height=150")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ port_bits graph: OK (HTTP $HTTP_CODE)"
else
    echo "   ✗ port_bits graph: FAILED (HTTP $HTTP_CODE)"
fi

echo ""
echo "=== Graph Generation Test Complete ==="
echo ""
echo "If all tests show OK, graphs are working properly."
echo "If any test shows FAILED, check LibreNMS logs for errors."
echo ""


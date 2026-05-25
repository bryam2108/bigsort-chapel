#!/usr/bin/env bash
# Simple test harness for BigSort

set -e

echo "=== BigSort Quick Test ==="

if [ ! -x ./bigsort ]; then
  echo "Building bigsort..."
  make bigsort
fi

echo

echo "1. Small run with verification..."
./bigsort --n=100000 --verify --quiet

echo
echo "2. File mode (lexicographic)..."
./bigsort --file=examples/sample.txt --quiet

echo
echo "3. File mode (numeric) with output..."
./bigsort --file=examples/numbers.txt --numeric --output=/tmp/numeric.out --quiet
echo "   First 5 numeric sorted lines:"
head -5 /tmp/numeric.out || true

echo
echo "=== All basic tests passed! ==="

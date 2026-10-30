#!/usr/bin/env bash
set -euo pipefail

TARGET_LIB="${1:-/home/jov/git/prj/AstraToolbox.jl/deps/usr/lib/libastra.so}"
EXPECTED_SYMBOL_COUNT=114

echo "=== 1. Inspecting shared library: $TARGET_LIB ==="
if [ ! -f "$TARGET_LIB" ]; then
    echo "ERROR: Target library not found at $TARGET_LIB" >&2
    exit 1
fi

echo "--- NEEDED shared libraries ---"
readelf -d "$TARGET_LIB" | grep NEEDED || true

echo "--- SONAME ---"
readelf -d "$TARGET_LIB" | grep SONAME || true

echo "--- RPATH / RUNPATH ---"
readelf -d "$TARGET_LIB" | grep -E "RPATH|RUNPATH" || true

echo "=== 2. Exported astra_julia_* symbols ==="
SYMBOL_COUNT=$(nm -D --defined-only "$TARGET_LIB" | grep -c " astra_julia_" || true)
echo "Exported symbol count: $SYMBOL_COUNT (expected: $EXPECTED_SYMBOL_COUNT)"

if [ "$SYMBOL_COUNT" -ne "$EXPECTED_SYMBOL_COUNT" ]; then
    echo "ERROR: Exported symbol count mismatch!" >&2
    exit 1
fi

echo "=== 3. Wrapper source consistency check ==="
WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../wrapper" && pwd)"
ASTRA_WRAPPER_DIR="/home/jov/git/prj/AstraToolbox.jl/deps/wrapper"

if [ -d "$ASTRA_WRAPPER_DIR" ]; then
    echo "Comparing $WRAPPER_DIR with $ASTRA_WRAPPER_DIR..."
    diff -u "$WRAPPER_DIR/include/astra/julia_c_api.h" "$ASTRA_WRAPPER_DIR/include/astra/julia_c_api.h"
    diff -u "$WRAPPER_DIR/src/julia_c_api.cpp" "$ASTRA_WRAPPER_DIR/src/julia_c_api.cpp"
    echo "OK: Wrapper sources match exactly."
else
    echo "NOTE: $ASTRA_WRAPPER_DIR not found, skipping comparison."
fi

echo "All ABI checks passed successfully."

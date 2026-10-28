#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"

echo "==============================================================="
echo "  Moore Threads MTT S80 GPGPU Compute Benchmark Suite Runner   "
echo "==============================================================="

if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

cd "$BUILD_DIR"
echo "[*] Building benchmarks with CMake and MCC..."
cmake ..
make -j$(nproc)

echo ""
echo "[1/7] Running Memory Bandwidth Benchmark..."
./bandwidth_bench

echo ""
echo "[2/7] Running FP32 Compute FLOPS Benchmark (v1)..."
./compute_flops_bench

echo ""
echo "[3/7] Running FP32 Compute FLOPS Benchmark (v2 High-Density)..."
./compute_flops_bench_v2

echo ""
echo "[4/7] Running SHA-256 Crypto Benchmark (v1 Baseline)..."
./crypto_hash_bench

echo ""
echo "[5/7] Running SHA-256 Crypto Benchmark (v2 Circular Register)..."
./crypto_hash_bench_v2

echo ""
echo "[6/7] Running SHA-256 Password Fast-Path Benchmark (v4 Constant Folding)..."
./crypto_hash_bench_v4

echo ""
echo "[7/7] Running SHA-256 Hashcat-Enhanced Benchmark (v6 MITM Reverse Abort - 1066 MH/s)..."
./crypto_hash_bench_v6

echo ""
echo "==============================================================="
echo "  All MTT S80 Benchmarks completed successfully!               "
echo "==============================================================="

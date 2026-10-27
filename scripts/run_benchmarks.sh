#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
BUILD_DIR="$PROJECT_DIR/build"

if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    cmake ..
    make -j
fi

cd "$BUILD_DIR"

echo "========================================================================"
echo "    Moore Threads MTT S80 GPGPU Compute & Hashing Benchmark Suite"
echo "========================================================================"
echo ""

echo ">>> [1/3] Running Interconnect & GDDR6 Memory Bandwidth Benchmark..."
./bandwidth_bench
echo ""

echo ">>> [2/3] Running FP32 Floating-Point Arithmetic TFLOPS Benchmark..."
./compute_flops_bench
echo ""

echo ">>> [3/3] Running SHA-256 Cryptographic Hash Throughput Benchmark..."
./crypto_hash_bench
echo ""

echo "========================================================================"
echo "    Benchmark Execution Completed Successfully!"
echo "========================================================================"

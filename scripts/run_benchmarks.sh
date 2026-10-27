#!/bin/bash
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
BUILD_DIR="$PROJECT_DIR/build"

if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

cd "$BUILD_DIR"
cmake ..
make -j

echo "========================================================================"
echo "    Moore Threads MTT S80 GPGPU Compute & Hashing Benchmark Suite"
echo "========================================================================"
echo ""

echo ">>> [1/5] Running Interconnect & GDDR6 Memory Bandwidth Benchmark..."
./bandwidth_bench
echo ""

echo ">>> [2/5] Running FP32 Floating-Point Arithmetic Benchmark (v1 Baseline)..."
./compute_flops_bench
echo ""

echo ">>> [3/5] Running FP32 Floating-Point Arithmetic Benchmark (v2 Zero-Stall Pipeline)..."
./compute_flops_bench_v2
echo ""

echo ">>> [4/5] Running SHA-256 Hashing Throughput Benchmark (v1 Baseline)..."
./crypto_hash_bench
echo ""

echo ">>> [5/5] Running SHA-256 Hashing Throughput Benchmark (v2 Deeply-Optimized)..."
./crypto_hash_bench_v2
echo ""

echo "========================================================================"
echo "    All V1 & V2 Benchmark Executions Completed Successfully!"
echo "========================================================================"

cmake_minimum_required(VERSION 3.18)
project(musa_compute_benchmarks CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
find_package(MUSA REQUIRED)

include_directories(
    ${MUSA_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks
)

# Benchmark Targets
musa_add_executable(bandwidth_bench benchmarks/bandwidth_bench.mu)
musa_add_executable(compute_flops_bench benchmarks/compute_flops_bench.mu)
musa_add_executable(compute_flops_bench_v2 benchmarks/compute_flops_bench_v2.mu)
musa_add_executable(crypto_hash_bench benchmarks/crypto_hash_bench.mu)
musa_add_executable(crypto_hash_bench_v2 benchmarks/crypto_hash_bench_v2.mu)
musa_add_executable(crypto_hash_bench_v3 benchmarks/crypto_hash_bench_v3.mu)
musa_add_executable(crypto_hash_bench_v4 benchmarks/crypto_hash_bench_v4.mu)
musa_add_executable(crypto_hash_bench_v5 benchmarks/crypto_hash_bench_v5.mu)
musa_add_executable(crypto_hash_bench_v6 benchmarks/crypto_hash_bench_v6.mu)

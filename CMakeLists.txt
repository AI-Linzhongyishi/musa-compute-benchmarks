cmake_minimum_required(VERSION 3.16)
project(musa_compute_benchmarks LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(MUSA REQUIRED)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks
    ${MUSA_INCLUDE_DIRS}
)

# Benchmark Executables
musa_add_executable(bandwidth_bench ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks/bandwidth_bench.mu)
musa_add_executable(compute_flops_bench ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks/compute_flops_bench.mu)
musa_add_executable(crypto_hash_bench ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks/crypto_hash_bench.mu)

# Master build target
add_custom_target(benchmarks ALL
    DEPENDS build_bandwidth_bench build_compute_flops_bench build_crypto_hash_bench
)

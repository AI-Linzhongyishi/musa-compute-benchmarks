#include "common.h"
#include <vector>
#include <iomanip>
#include <iostream>

__global__ void copy_kernel(const float* __restrict__ src, float* __restrict__ dst, size_t n) {
    size_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = blockDim.x * gridDim.x;
    for (size_t i = idx; i < n; i += stride) {
        dst[i] = src[i];
    }
}

void benchmark_transfer(size_t bytes, int iterations = 10) {
    size_t count = bytes / sizeof(float);
    std::vector<float> h_src(count, 1.234f);
    std::vector<float> h_dst(count, 0.0f);

    float *d_src = nullptr, *d_dst = nullptr;
    MUSA_CHECK(musaMalloc(&d_src, bytes));
    MUSA_CHECK(musaMalloc(&d_dst, bytes));

    // Warm-up
    MUSA_CHECK(musaMemcpy(d_src, h_src.data(), bytes, musaMemcpyHostToDevice));
    MUSA_CHECK(musaDeviceSynchronize());

    // Host to Device
    Timer timer_h2d;
    for (int i = 0; i < iterations; ++i) {
        MUSA_CHECK(musaMemcpy(d_src, h_src.data(), bytes, musaMemcpyHostToDevice));
    }
    MUSA_CHECK(musaDeviceSynchronize());
    double h2d_ms = timer_h2d.elapsed_ms() / iterations;
    double h2d_gbps = (double)bytes / (h2d_ms * 1e6);

    // Device to Device (Direct memcpy)
    Timer timer_d2d;
    for (int i = 0; i < iterations; ++i) {
        MUSA_CHECK(musaMemcpy(d_dst, d_src, bytes, musaMemcpyDeviceToDevice));
    }
    MUSA_CHECK(musaDeviceSynchronize());
    double d2d_ms = timer_d2d.elapsed_ms() / iterations;
    double d2d_gbps = (double)bytes / (d2d_ms * 1e6);

    // Device to Device (Kernel stream read + write: 2 * bytes)
    int threads = 256;
    int blocks = 1024;
    Timer timer_kernel;
    for (int i = 0; i < iterations; ++i) {
        copy_kernel<<<blocks, threads>>>(d_src, d_dst, count);
    }
    MUSA_CHECK(musaDeviceSynchronize());
    double kern_ms = timer_kernel.elapsed_ms() / iterations;
    double kern_bw_gbps = (2.0 * (double)bytes) / (kern_ms * 1e6);

    // Device to Host
    Timer timer_d2h;
    for (int i = 0; i < iterations; ++i) {
        MUSA_CHECK(musaMemcpy(h_dst.data(), d_dst, bytes, musaMemcpyDeviceToHost));
    }
    MUSA_CHECK(musaDeviceSynchronize());
    double d2h_ms = timer_d2h.elapsed_ms() / iterations;
    double d2h_gbps = (double)bytes / (d2h_ms * 1e6);

    std::cout << std::setw(10) << (bytes / (1024 * 1024)) << " MB | "
              << std::fixed << std::setprecision(2)
              << std::setw(9) << h2d_gbps << " GB/s | "
              << std::setw(9) << d2h_gbps << " GB/s | "
              << std::setw(9) << d2d_gbps << " GB/s | "
              << std::setw(11) << kern_bw_gbps << " GB/s" << std::endl;

    MUSA_CHECK(musaFree(d_src));
    MUSA_CHECK(musaFree(d_dst));
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 Memory & Interconnect Bandwidth Benchmark <<" << std::endl;
    std::cout << "--------------------------------------------------------------------------------" << std::endl;
    std::cout << "  Size     |   H2D (PCIe)  |   D2H (PCIe)  |   D2D (Memcpy) |  D2D Kernel BW" << std::endl;
    std::cout << "--------------------------------------------------------------------------------" << std::endl;

    std::vector<size_t> sizes = {
        64 * 1024 * 1024,
        128 * 1024 * 1024,
        256 * 1024 * 1024,
        512 * 1024 * 1024,
        1024 * 1024 * 1024
    };

    for (size_t s : sizes) {
        benchmark_transfer(s, 10);
    }
    std::cout << "--------------------------------------------------------------------------------" << std::endl;
    return 0;
}

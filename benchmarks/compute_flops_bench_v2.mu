#include "common.h"
#include <iomanip>
#include <iostream>

// Zero-latency independent FMA pipelines: 16 parallel accumulators without serial dependencies
__global__ void fma_pipeline_kernel_v2(float* out, float c0, float c1, int iterations) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    
    float a0 = (float)tid * 0.0001f;
    float a1 = a0 + 0.1f;
    float a2 = a0 + 0.2f;
    float a3 = a0 + 0.3f;
    float a4 = a0 + 0.4f;
    float a5 = a0 + 0.5f;
    float a6 = a0 + 0.6f;
    float a7 = a0 + 0.7f;
    float a8 = a0 + 0.8f;
    float a9 = a0 + 0.9f;
    float a10 = a0 + 1.0f;
    float a11 = a0 + 1.1f;
    float a12 = a0 + 1.2f;
    float a13 = a0 + 1.3f;
    float a14 = a0 + 1.4f;
    float a15 = a0 + 1.5f;

    #pragma unroll 16
    for (int i = 0; i < iterations; ++i) {
        a0  = a0  * c0 + c1;
        a1  = a1  * c0 + c1;
        a2  = a2  * c0 + c1;
        a3  = a3  * c0 + c1;
        a4  = a4  * c0 + c1;
        a5  = a5  * c0 + c1;
        a6  = a6  * c0 + c1;
        a7  = a7  * c0 + c1;
        a8  = a8  * c0 + c1;
        a9  = a9  * c0 + c1;
        a10 = a10 * c0 + c1;
        a11 = a11 * c0 + c1;
        a12 = a12 * c0 + c1;
        a13 = a13 * c0 + c1;
        a14 = a14 * c0 + c1;
        a15 = a15 * c0 + c1;

        a0  = a0  * c1 + c0;
        a1  = a1  * c1 + c0;
        a2  = a2  * c1 + c0;
        a3  = a3  * c1 + c0;
        a4  = a4  * c1 + c0;
        a5  = a5  * c1 + c0;
        a6  = a6  * c1 + c0;
        a7  = a7  * c1 + c0;
        a8  = a8  * c1 + c0;
        a9  = a9  * c1 + c0;
        a10 = a10 * c1 + c0;
        a11 = a11 * c1 + c0;
        a12 = a12 * c1 + c0;
        a13 = a13 * c1 + c0;
        a14 = a14 * c1 + c0;
        a15 = a15 * c1 + c0;
    }

    if (tid == 0) {
        out[0] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11 + a12 + a13 + a14 + a15;
    }
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 FP32 Peak Arithmetic TFLOPS Benchmark (v2 Zero-Stall) <<" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int threads_per_block = 256;
    const int blocks = 4096; // 1,048,576 concurrent threads
    const size_t total_threads = (size_t)blocks * threads_per_block;
    const int iterations = 100000;
    // 32 FMAs per loop iteration, each FMA is 2 ops (1 mul + 1 add)
    const double ops_per_thread = (double)iterations * 32.0 * 2.0;
    const double total_ops = ops_per_thread * (double)total_threads;

    float* d_out = nullptr;
    MUSA_CHECK(musaMalloc(&d_out, sizeof(float)));

    // Warm-up
    fma_pipeline_kernel_v2<<<blocks, threads_per_block>>>(d_out, 1.000001f, 0.000001f, 1000);
    MUSA_CHECK(musaDeviceSynchronize());

    std::cout << "Executing " << (total_ops / 1e12) << " Tera-Operations on S80 (4096 Cores)..." << std::endl;

    const int repeat = 5;
    double max_tflops = 0.0;
    double avg_tflops = 0.0;

    for (int r = 1; r <= repeat; ++r) {
        Timer t;
        fma_pipeline_kernel_v2<<<blocks, threads_per_block>>>(d_out, 1.000001f, 0.000001f, iterations);
        MUSA_CHECK(musaDeviceSynchronize());
        double ms = t.elapsed_ms();
        double tflops = (total_ops / (ms * 1e-3)) / 1e12;

        if (tflops > max_tflops) max_tflops = tflops;
        avg_tflops += tflops;

        std::cout << "  [Run " << r << "] Time: " << std::fixed << std::setprecision(2)
                  << ms << " ms | Throughput: " << std::setprecision(3) << tflops << " TFLOPS" << std::endl;
    }
    avg_tflops /= repeat;

    std::cout << "----------------------------------------------------------------------------------" << std::endl;
    std::cout << " MTT S80 FP32 Peak Compute Performance (v2): " << std::fixed << std::setprecision(3)
              << max_tflops << " TFLOPS (Average: " << avg_tflops << " TFLOPS)" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    MUSA_CHECK(musaFree(d_out));
    return 0;
}

#include "common.h"
#include <iomanip>
#include <iostream>

// High-arithmetic-intensity FMA kernel with multiple independent accumulators to saturate FP32 pipelines
__global__ void fma_stress_kernel(float* out, float a, float b, int iterations) {
    size_t tid = blockIdx.x * blockDim.x + threadIdx.x;
    
    float acc0 = a + (float)tid * 0.0001f;
    float acc1 = b + (float)tid * 0.0002f;
    float acc2 = a * 0.5f;
    float acc3 = b * 0.5f;
    float acc4 = a + 1.0f;
    float acc5 = b + 1.0f;
    float acc6 = a - 0.5f;
    float acc7 = b - 0.5f;

    #pragma unroll 16
    for (int i = 0; i < iterations; ++i) {
        acc0 = acc0 * acc1 + acc2;
        acc1 = acc1 * acc2 + acc3;
        acc2 = acc2 * acc3 + acc4;
        acc3 = acc3 * acc4 + acc5;
        acc4 = acc4 * acc5 + acc6;
        acc5 = acc5 * acc6 + acc7;
        acc6 = acc6 * acc7 + acc0;
        acc7 = acc7 * acc0 + acc1;

        acc0 = acc0 * acc2 + acc4;
        acc1 = acc1 * acc3 + acc5;
        acc2 = acc2 * acc4 + acc6;
        acc3 = acc3 * acc5 + acc7;
        acc4 = acc4 * acc6 + acc0;
        acc5 = acc5 * acc7 + acc1;
        acc6 = acc6 * acc0 + acc2;
        acc7 = acc7 * acc1 + acc3;
    }

    if (tid == 0) {
        out[0] = acc0 + acc1 + acc2 + acc3 + acc4 + acc5 + acc6 + acc7;
    }
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 FP32 Peak Arithmetic TFLOPS Benchmark <<" << std::endl;
    std::cout << "----------------------------------------------------------------------" << std::endl;

    const int threads_per_block = 256;
    const int blocks = 4096; // 4096 blocks * 256 threads = 1,048,576 concurrent threads
    const size_t total_threads = (size_t)blocks * threads_per_block;
    const int iterations = 100000;
    // 16 FMAs per loop iteration, each FMA is 2 ops (1 mul + 1 add)
    const double ops_per_thread = (double)iterations * 16.0 * 2.0;
    const double total_ops = ops_per_thread * (double)total_threads;

    float* d_out = nullptr;
    MUSA_CHECK(musaMalloc(&d_out, sizeof(float)));

    // Warm-up
    fma_stress_kernel<<<blocks, threads_per_block>>>(d_out, 1.0001f, 1.0002f, 1000);
    MUSA_CHECK(musaDeviceSynchronize());

    std::cout << "Executing " << (total_ops / 1e12) << " Tera-Operations on S80 (4096 Cores)..." << std::endl;

    const int repeat = 5;
    double max_tflops = 0.0;
    double avg_tflops = 0.0;

    for (int r = 1; r <= repeat; ++r) {
        Timer t;
        fma_stress_kernel<<<blocks, threads_per_block>>>(d_out, 1.0001f, 1.0002f, iterations);
        MUSA_CHECK(musaDeviceSynchronize());
        double ms = t.elapsed_ms();
        double tflops = (total_ops / (ms * 1e-3)) / 1e12;

        if (tflops > max_tflops) max_tflops = tflops;
        avg_tflops += tflops;

        std::cout << "  [Run " << r << "] Time: " << std::fixed << std::setprecision(2)
                  << ms << " ms | Throughput: " << std::setprecision(3) << tflops << " TFLOPS" << std::endl;
    }
    avg_tflops /= repeat;

    std::cout << "----------------------------------------------------------------------" << std::endl;
    std::cout << " MTT S80 FP32 Peak Compute Performance: " << std::fixed << std::setprecision(3)
              << max_tflops << " TFLOPS (Average: " << avg_tflops << " TFLOPS)" << std::endl;
    std::cout << "----------------------------------------------------------------------" << std::endl;

    MUSA_CHECK(musaFree(d_out));
    return 0;
}

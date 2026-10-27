#include "common.h"
#include <cstdint>
#include <iomanip>
#include <iostream>

#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define SIGMA0(x) (ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22))
#define SIGMA1(x) (ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25))
#define SIG0(x) (ROTR(x, 7) ^ ROTR(x, 18) ^ ((x) >> 3))
#define SIG1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^ ((x) >> 10))

__constant__ uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f, 0xc67178f2
};

__device__ void sha256_transform(uint32_t state[8], const uint32_t data[16]) {
    uint32_t W[64];
    #pragma unroll
    for (int i = 0; i < 16; ++i) {
        W[i] = data[i];
    }
    #pragma unroll
    for (int i = 16; i < 64; ++i) {
        W[i] = SIG1(W[i - 2]) + W[i - 7] + SIG0(W[i - 15]) + W[i - 16];
    }

    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];

    #pragma unroll
    for (int i = 0; i < 64; ++i) {
        uint32_t T1 = h + SIGMA1(e) + CH(e, f, g) + K[i] + W[i];
        uint32_t T2 = SIGMA0(a) + MAJ(a, b, c);
        h = g;
        g = f;
        f = e;
        e = d + T1;
        d = c;
        c = b;
        b = a;
        a = T1 + T2;
    }

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

__global__ void sha256_benchmark_kernel(uint32_t* d_out, uint32_t seed, int iterations) {
    size_t tid = blockIdx.x * blockDim.x + threadIdx.x;

    uint32_t data[16];
    #pragma unroll
    for (int i = 0; i < 16; ++i) {
        data[i] = (uint32_t)(tid + i * 0x9e3779b9 + seed);
    }

    uint32_t state[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };

    for (int iter = 0; iter < iterations; ++iter) {
        data[0] = state[0] ^ (uint32_t)iter;
        sha256_transform(state, data);
    }

    if (tid == 0) {
        for (int i = 0; i < 8; ++i) {
            d_out[i] = state[i];
        }
    }
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 Parallel SHA-256 Hashing Throughput Benchmark <<" << std::endl;
    std::cout << "----------------------------------------------------------------------------" << std::endl;

    const int threads_per_block = 256;
    const int blocks = 2048; // 2048 * 256 = 524,288 concurrent threads
    const size_t total_threads = (size_t)blocks * threads_per_block;
    const int iterations = 1000;
    const double total_hashes = (double)total_threads * (double)iterations;

    uint32_t* d_out = nullptr;
    MUSA_CHECK(musaMalloc(&d_out, 8 * sizeof(uint32_t)));

    // Warm-up
    sha256_benchmark_kernel<<<blocks, threads_per_block>>>(d_out, 12345, 10);
    MUSA_CHECK(musaDeviceSynchronize());

    std::cout << "Active GPU Threads: " << total_threads << " | Iterations/thread: " << iterations << std::endl;
    std::cout << "Total SHA-256 Hashes Per Pass: " << (total_hashes / 1e6) << " MegaHashes" << std::endl;
    std::cout << "----------------------------------------------------------------------------" << std::endl;

    const int passes = 5;
    double max_mhs = 0.0;
    double avg_mhs = 0.0;

    for (int p = 1; p <= passes; ++p) {
        Timer timer;
        sha256_benchmark_kernel<<<blocks, threads_per_block>>>(d_out, 0x1337 + p, iterations);
        MUSA_CHECK(musaDeviceSynchronize());
        double ms = timer.elapsed_ms();
        double mhs = (total_hashes / (ms * 1e-3)) / 1e6; // MH/s

        if (mhs > max_mhs) max_mhs = mhs;
        avg_mhs += mhs;

        std::cout << "  [Pass " << p << "] Time: " << std::fixed << std::setprecision(2)
                  << ms << " ms | Hash Speed: " << std::setprecision(2) << mhs << " MH/s" << std::endl;
    }
    avg_mhs /= passes;

    std::cout << "----------------------------------------------------------------------------" << std::endl;
    std::cout << " MTT S80 SHA-256 Peak Compute Rate: " << std::fixed << std::setprecision(2)
              << max_mhs << " MH/s (Average: " << avg_mhs << " MH/s)" << std::endl;
    std::cout << "----------------------------------------------------------------------------" << std::endl;

    MUSA_CHECK(musaFree(d_out));
    return 0;
}

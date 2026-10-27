#include "common.h"
#include <cstdint>
#include <iomanip>
#include <iostream>

// Standard 32-bit bitwise rotation
#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))

// V2 Boolean Algebra Simplification:
// Standard Ch(x,y,z) = (x & y) ^ (~x & z)  [4 ops: AND, NOT, AND, XOR]
// Optimized Ch(x,y,z) = z ^ (x & (y ^ z))   [3 ops: XOR, AND, XOR -> saves 1 ALU op per round]
#define CH(x, y, z)  ((z) ^ ((x) & ((y) ^ (z))))

// Standard Maj(x,y,z) = (x & y) ^ (x & z) ^ (y & z)  [5 ops]
// Optimized Maj(x,y,z) = (x & y) ^ ((x ^ y) & z)     [4 ops -> saves 1 ALU op per round]
#define MAJ(x, y, z) (((x) & (y)) ^ (((x) ^ (y)) & (z)))

#define SIGMA0(x) (ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22))
#define SIGMA1(x) (ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25))
#define SIG0(x)   (ROTR(x, 7) ^ ROTR(x, 18) ^ ((x) >> 3))
#define SIG1(x)   (ROTR(x, 17) ^ ROTR(x, 19) ^ ((x) >> 10))

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

#define SHA256_ROUND(a, b, c, d, e, f, g, h, k_val, w_val) do { \
    uint32_t t1 = (h) + SIGMA1(e) + CH(e, f, g) + (k_val) + (w_val); \
    uint32_t t2 = SIGMA0(a) + MAJ(a, b, c); \
    (d) += t1; \
    (h) = t1 + t2; \
} while(0)

__global__ void sha256_kernel_v2_optimized(uint32_t* d_out, uint32_t seed, int iterations) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;

    uint32_t w[16];
    #pragma unroll
    for (int i = 0; i < 16; ++i) {
        w[i] = (uint32_t)(tid + (size_t)i * 0x9e3779b9 + seed);
    }

    uint32_t s0 = 0x6a09e667, s1 = 0xbb67ae85, s2 = 0x3c6ef372, s3 = 0xa54ff53a;
    uint32_t s4 = 0x510e527f, s5 = 0x9b05688c, s6 = 0x1f83d9ab, s7 = 0x5be0cd19;

    for (int iter = 0; iter < iterations; ++iter) {
        w[0] ^= s0 + (uint32_t)iter;

        uint32_t a = s0, b = s1, c = s2, d = s3;
        uint32_t e = s4, f = s5, g = s6, h = s7;

        #define R_0_15(i, a, b, c, d, e, f, g, h) \
            SHA256_ROUND(a, b, c, d, e, f, g, h, K[i], w[i])

        R_0_15( 0, a, b, c, d, e, f, g, h);
        R_0_15( 1, h, a, b, c, d, e, f, g);
        R_0_15( 2, g, h, a, b, c, d, e, f);
        R_0_15( 3, f, g, h, a, b, c, d, e);
        R_0_15( 4, e, f, g, h, a, b, c, d);
        R_0_15( 5, d, e, f, g, h, a, b, c);
        R_0_15( 6, c, d, e, f, g, h, a, b);
        R_0_15( 7, b, c, d, e, f, g, h, a);
        R_0_15( 8, a, b, c, d, e, f, g, h);
        R_0_15( 9, h, a, b, c, d, e, f, g);
        R_0_15(10, g, h, a, b, c, d, e, f);
        R_0_15(11, f, g, h, a, b, c, d, e);
        R_0_15(12, e, f, g, h, a, b, c, d);
        R_0_15(13, d, e, f, g, h, a, b, c);
        R_0_15(14, c, d, e, f, g, h, a, b);
        R_0_15(15, b, c, d, e, f, g, h, a);

        #define R_16_63(i, a, b, c, d, e, f, g, h) do { \
            w[(i) & 15] += SIG1(w[((i) - 2) & 15]) + w[((i) - 7) & 15] + SIG0(w[((i) - 15) & 15]); \
            SHA256_ROUND(a, b, c, d, e, f, g, h, K[i], w[(i) & 15]); \
        } while(0)

        R_16_63(16, a, b, c, d, e, f, g, h);
        R_16_63(17, h, a, b, c, d, e, f, g);
        R_16_63(18, g, h, a, b, c, d, e, f);
        R_16_63(19, f, g, h, a, b, c, d, e);
        R_16_63(20, e, f, g, h, a, b, c, d);
        R_16_63(21, d, e, f, g, h, a, b, c);
        R_16_63(22, c, d, e, f, g, h, a, b);
        R_16_63(23, b, c, d, e, f, g, h, a);
        R_16_63(24, a, b, c, d, e, f, g, h);
        R_16_63(25, h, a, b, c, d, e, f, g);
        R_16_63(26, g, h, a, b, c, d, e, f);
        R_16_63(27, f, g, h, a, b, c, d, e);
        R_16_63(28, e, f, g, h, a, b, c, d);
        R_16_63(29, d, e, f, g, h, a, b, c);
        R_16_63(30, c, d, e, f, g, h, a, b);
        R_16_63(31, b, c, d, e, f, g, h, a);

        R_16_63(32, a, b, c, d, e, f, g, h);
        R_16_63(33, h, a, b, c, d, e, f, g);
        R_16_63(34, g, h, a, b, c, d, e, f);
        R_16_63(35, f, g, h, a, b, c, d, e);
        R_16_63(36, e, f, g, h, a, b, c, d);
        R_16_63(37, d, e, f, g, h, a, b, c);
        R_16_63(38, c, d, e, f, g, h, a, b);
        R_16_63(39, b, c, d, e, f, g, h, a);
        R_16_63(40, a, b, c, d, e, f, g, h);
        R_16_63(41, h, a, b, c, d, e, f, g);
        R_16_63(42, g, h, a, b, c, d, e, f);
        R_16_63(43, f, g, h, a, b, c, d, e);
        R_16_63(44, e, f, g, h, a, b, c, d);
        R_16_63(45, d, e, f, g, h, a, b, c);
        R_16_63(46, c, d, e, f, g, h, a, b);
        R_16_63(47, b, c, d, e, f, g, h, a);

        R_16_63(48, a, b, c, d, e, f, g, h);
        R_16_63(49, h, a, b, c, d, e, f, g);
        R_16_63(50, g, h, a, b, c, d, e, f);
        R_16_63(51, f, g, h, a, b, c, d, e);
        R_16_63(52, e, f, g, h, a, b, c, d);
        R_16_63(53, d, e, f, g, h, a, b, c);
        R_16_63(54, c, d, e, f, g, h, a, b);
        R_16_63(55, b, c, d, e, f, g, h, a);
        R_16_63(56, a, b, c, d, e, f, g, h);
        R_16_63(57, h, a, b, c, d, e, f, g);
        R_16_63(58, g, h, a, b, c, d, e, f);
        R_16_63(59, f, g, h, a, b, c, d, e);
        R_16_63(60, e, f, g, h, a, b, c, d);
        R_16_63(61, d, e, f, g, h, a, b, c);
        R_16_63(62, c, d, e, f, g, h, a, b);
        R_16_63(63, b, c, d, e, f, g, h, a);

        s0 += a; s1 += b; s2 += c; s3 += d;
        s4 += e; s5 += f; s6 += g; s7 += h;
    }

    if (tid == 0) {
        d_out[0] = s0; d_out[1] = s1; d_out[2] = s2; d_out[3] = s3;
        d_out[4] = s4; d_out[5] = s5; d_out[6] = s6; d_out[7] = s7;
    }
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 SHA-256 Benchmark (v2 Deeply Optimized) <<" << std::endl;
    std::cout << " Features: Boolean logic simplification, 16-register circular window, full unroll" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int threads_per_block = 256;
    const int blocks = 4096; // 1,048,576 concurrent threads
    const size_t total_threads = (size_t)blocks * threads_per_block;
    const int iterations = 1000;
    const double total_hashes = (double)total_threads * (double)iterations;

    uint32_t* d_out = nullptr;
    MUSA_CHECK(musaMalloc(&d_out, 8 * sizeof(uint32_t)));

    // Warm-up
    sha256_kernel_v2_optimized<<<blocks, threads_per_block>>>(d_out, 12345, 10);
    MUSA_CHECK(musaDeviceSynchronize());

    std::cout << "Active GPU Threads: " << total_threads << " | Iterations: " << iterations << std::endl;
    std::cout << "Total SHA-256 Hashes Per Pass: " << (total_hashes / 1e6) << " MegaHashes" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int passes = 5;
    double max_mhs = 0.0;
    double avg_mhs = 0.0;

    for (int p = 1; p <= passes; ++p) {
        Timer timer;
        sha256_kernel_v2_optimized<<<blocks, threads_per_block>>>(d_out, 0x1337 + p, iterations);
        MUSA_CHECK(musaDeviceSynchronize());
        double ms = timer.elapsed_ms();
        double mhs = (total_hashes / (ms * 1e-3)) / 1e6; // MH/s

        if (mhs > max_mhs) max_mhs = mhs;
        avg_mhs += mhs;

        std::cout << "  [Pass " << p << "] Time: " << std::fixed << std::setprecision(2)
                  << ms << " ms | Hash Speed: " << std::setprecision(2) << mhs << " MH/s" << std::endl;
    }
    avg_mhs /= passes;

    std::cout << "----------------------------------------------------------------------------------" << std::endl;
    std::cout << " MTT S80 SHA-256 Peak Rate (v2 Optimized): " << std::fixed << std::setprecision(2)
              << max_mhs << " MH/s (Average: " << avg_mhs << " MH/s)" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    MUSA_CHECK(musaFree(d_out));
    return 0;
}

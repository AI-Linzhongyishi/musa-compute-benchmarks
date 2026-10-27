#include "common.h"
#include <cstdint>
#include <iomanip>
#include <iostream>

#define ROTR(x, n) __builtin_rotateright32((uint32_t)(x), (uint32_t)(n))

// Boolean Logic Simplifications:
#define CH(x, y, z)  ((z) ^ ((x) & ((y) ^ (z))))
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

#define SHA_STEP(a, b, c, d, e, f, g, h, k_val, w_val) do { \
    uint32_t t1 = (h) + SIGMA1(e) + CH(e, f, g) + (k_val) + (w_val); \
    uint32_t t2 = SIGMA0(a) + MAJ(a, b, c); \
    (d) += t1; \
    (h) = t1 + t2; \
} while(0)

// Fast step when W_i is zero (eliminates 1 addition)
#define SHA_STEP_ZERO(a, b, c, d, e, f, g, h, k_val) do { \
    uint32_t t1 = (h) + SIGMA1(e) + CH(e, f, g) + (k_val); \
    uint32_t t2 = SIGMA0(a) + MAJ(a, b, c); \
    (d) += t1; \
    (h) = t1 + t2; \
} while(0)

__global__ void sha256_kernel_v4_wordlist(uint32_t* d_found, uint32_t target_hash0, uint32_t seed, int iterations) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;

    uint32_t w[16];
    w[0] = (uint32_t)(tid + seed);
    w[1] = (uint32_t)(tid ^ 0x5a5a5a5a);
    w[2] = 0x61626364; // "abcd"
    w[3] = 0x80000000; // standard SHA padding bit
    w[4]  = 0; w[5]  = 0; w[6]  = 0; w[7]  = 0;
    w[8]  = 0; w[9]  = 0; w[10] = 0; w[11] = 0;
    w[12] = 0; w[13] = 0; w[14] = 0;
    w[15] = 96; // 12 bytes * 8 = 96 bits

    for (int iter = 0; iter < iterations; ++iter) {
        w[0] += (uint32_t)iter;

        uint32_t a = 0x6a09e667, b = 0xbb67ae85, c = 0x3c6ef372, d = 0xa54ff53a;
        uint32_t e = 0x510e527f, f = 0x9b05688c, g = 0x1f83d9ab, h = 0x5be0cd19;

        // Rounds 0-3: Active candidate words
        SHA_STEP(a, b, c, d, e, f, g, h, K[0], w[0]);
        SHA_STEP(h, a, b, c, d, e, f, g, K[1], w[1]);
        SHA_STEP(g, h, a, b, c, d, e, f, K[2], w[2]);
        SHA_STEP(f, g, h, a, b, c, d, e, K[3], w[3]);

        // Rounds 4-14: ZERO WORDS ELIMINATION (No W addition!)
        SHA_STEP_ZERO(e, f, g, h, a, b, c, d, K[4]);
        SHA_STEP_ZERO(d, e, f, g, h, a, b, c, K[5]);
        SHA_STEP_ZERO(c, d, e, f, g, h, a, b, K[6]);
        SHA_STEP_ZERO(b, c, d, e, f, g, h, a, K[7]);
        SHA_STEP_ZERO(a, b, c, d, e, f, g, h, K[8]);
        SHA_STEP_ZERO(h, a, b, c, d, e, f, g, K[9]);
        SHA_STEP_ZERO(g, h, a, b, c, d, e, f, K[10]);
        SHA_STEP_ZERO(f, g, h, a, b, c, d, e, K[11]);
        SHA_STEP_ZERO(e, f, g, h, a, b, c, d, K[12]);
        SHA_STEP_ZERO(d, e, f, g, h, a, b, c, K[13]);
        SHA_STEP_ZERO(c, d, e, f, g, h, a, b, K[14]);

        // Round 15: Constant bit length w[15]
        SHA_STEP(b, c, d, e, f, g, h, a, K[15], w[15]);

        // Rounds 16-26: Compile-time constant folding & dead term removal
        w[0] = SIG0(w[1]) + w[0];
        SHA_STEP(a, b, c, d, e, f, g, h, K[16], w[0]);

        w[1] = SIG0(w[2]) + w[1] + 0x003c0000u;
        SHA_STEP(h, a, b, c, d, e, f, g, K[17], w[1]);

        w[2] = SIG1(w[0]) + w[2] + 0x11002000u;
        SHA_STEP(g, h, a, b, c, d, e, f, K[18], w[2]);

        w[3] = SIG1(w[1]) + 0x80000000u;
        SHA_STEP(f, g, h, a, b, c, d, e, K[19], w[3]);

        w[4] = SIG1(w[2]);
        SHA_STEP(e, f, g, h, a, b, c, d, K[20], w[4]);

        w[5] = SIG1(w[3]);
        SHA_STEP(d, e, f, g, h, a, b, c, K[21], w[5]);

        w[6] = SIG1(w[4]) + 96u;
        SHA_STEP(c, d, e, f, g, h, a, b, K[22], w[6]);

        w[7] = SIG1(w[5]) + w[0];
        SHA_STEP(b, c, d, e, f, g, h, a, K[23], w[7]);

        w[8] = SIG1(w[6]) + w[1];
        SHA_STEP(a, b, c, d, e, f, g, h, K[24], w[8]);

        w[9] = SIG1(w[7]) + w[2];
        SHA_STEP(h, a, b, c, d, e, f, g, K[25], w[9]);

        w[10] = SIG1(w[8]) + w[3];
        SHA_STEP(g, h, a, b, c, d, e, f, K[26], w[10]);

        // Rounds 27-63: In-place rolling schedule
        #define R_SCHEDULE(i, a, b, c, d, e, f, g, h) do { \
            w[(i) & 15] += SIG1(w[((i) - 2) & 15]) + w[((i) - 7) & 15] + SIG0(w[((i) - 15) & 15]); \
            SHA_STEP(a, b, c, d, e, f, g, h, K[i], w[(i) & 15]); \
        } while(0)

        R_SCHEDULE(27, f, g, h, a, b, c, d, e);
        R_SCHEDULE(28, e, f, g, h, a, b, c, d);
        R_SCHEDULE(29, d, e, f, g, h, a, b, c);
        R_SCHEDULE(30, c, d, e, f, g, h, a, b);
        R_SCHEDULE(31, b, c, d, e, f, g, h, a);

        R_SCHEDULE(32, a, b, c, d, e, f, g, h);
        R_SCHEDULE(33, h, a, b, c, d, e, f, g);
        R_SCHEDULE(34, g, h, a, b, c, d, e, f);
        R_SCHEDULE(35, f, g, h, a, b, c, d, e);
        R_SCHEDULE(36, e, f, g, h, a, b, c, d);
        R_SCHEDULE(37, d, e, f, g, h, a, b, c);
        R_SCHEDULE(38, c, d, e, f, g, h, a, b);
        R_SCHEDULE(39, b, c, d, e, f, g, h, a);
        R_SCHEDULE(40, a, b, c, d, e, f, g, h);
        R_SCHEDULE(41, h, a, b, c, d, e, f, g);
        R_SCHEDULE(42, g, h, a, b, c, d, e, f);
        R_SCHEDULE(43, f, g, h, a, b, c, d, e);
        R_SCHEDULE(44, e, f, g, h, a, b, c, d);
        R_SCHEDULE(45, d, e, f, g, h, a, b, c);
        R_SCHEDULE(46, c, d, e, f, g, h, a, b);
        R_SCHEDULE(47, b, c, d, e, f, g, h, a);

        R_SCHEDULE(48, a, b, c, d, e, f, g, h);
        R_SCHEDULE(49, h, a, b, c, d, e, f, g);
        R_SCHEDULE(50, g, h, a, b, c, d, e, f);
        R_SCHEDULE(51, f, g, h, a, b, c, d, e);
        R_SCHEDULE(52, e, f, g, h, a, b, c, d);
        R_SCHEDULE(53, d, e, f, g, h, a, b, c);
        R_SCHEDULE(54, c, d, e, f, g, h, a, b);
        R_SCHEDULE(55, b, c, d, e, f, g, h, a);
        R_SCHEDULE(56, a, b, c, d, e, f, g, h);
        R_SCHEDULE(57, h, a, b, c, d, e, f, g);
        R_SCHEDULE(58, g, h, a, b, c, d, e, f);
        R_SCHEDULE(59, f, g, h, a, b, c, d, e);
        R_SCHEDULE(60, e, f, g, h, a, b, c, d);
        R_SCHEDULE(61, d, e, f, g, h, a, b, c);
        R_SCHEDULE(62, c, d, e, f, g, h, a, b);
        R_SCHEDULE(63, b, c, d, e, f, g, h, a);

        // Early-Abort Match Check
        uint32_t final_h0 = 0x6a09e667 + a;
        if (final_h0 == target_hash0) {
            d_found[0] = (uint32_t)tid;
            d_found[1] = final_h0;
        }
    }
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 Password Candidate Fast-Path Benchmark (v4) <<" << std::endl;
    std::cout << " Features: Zero-term elimination, compile-time constant folding, early-abort check" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int threads_per_block = 128;
    const int blocks = 8192;
    const size_t total_threads = (size_t)blocks * threads_per_block;
    const int iterations = 1000;
    const double total_candidates = (double)total_threads * (double)iterations;

    uint32_t* d_found = nullptr;
    MUSA_CHECK(musaMalloc(&d_found, 4 * sizeof(uint32_t)));
    MUSA_CHECK(musaMemset(d_found, 0, 4 * sizeof(uint32_t)));

    uint32_t dummy_target = 0xdeadbeef;

    // Warm-up
    sha256_kernel_v4_wordlist<<<blocks, threads_per_block>>>(d_found, dummy_target, 12345, 10);
    MUSA_CHECK(musaDeviceSynchronize());

    std::cout << "Active Evaluators: " << total_threads << " | Iterations: " << iterations << std::endl;
    std::cout << "Candidates Evaluated Per Pass: " << (total_candidates / 1e6) << " Million Passwords" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int passes = 5;
    double max_speed = 0.0;
    double avg_speed = 0.0;

    for (int p = 1; p <= passes; ++p) {
        Timer timer;
        sha256_kernel_v4_wordlist<<<blocks, threads_per_block>>>(d_found, dummy_target, 0x1337 + p, iterations);
        MUSA_CHECK(musaDeviceSynchronize());
        double ms = timer.elapsed_ms();
        double speed_mhs = (total_candidates / (ms * 1e-3)) / 1e6;

        if (speed_mhs > max_speed) max_speed = speed_mhs;
        avg_speed += speed_mhs;

        std::cout << "  [Pass " << p << "] Time: " << std::fixed << std::setprecision(2)
                  << ms << " ms | Candidate Speed: " << std::setprecision(2) << speed_mhs << " MH/s" << std::endl;
    }
    avg_speed /= passes;

    std::cout << "----------------------------------------------------------------------------------" << std::endl;
    std::cout << " MTT S80 Password Candidate Peak Throughput (v4): " << std::fixed << std::setprecision(2)
              << max_speed << " MH/s (Average: " << avg_speed << " MH/s)" << std::endl;
    std::cout << " Equivalent Rate: " << std::fixed << std::setprecision(2)
              << (max_speed / 1000.0) << " Billion Passwords/second (" << (max_speed / 100.0) << " 亿组/秒)" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    MUSA_CHECK(musaFree(d_found));
    return 0;
}

#include "common.h"
#include <cstdint>
#include <iomanip>
#include <iostream>

// Hashcat-style rotate-left optimizations
#define hc_rotl32(x, n) __builtin_rotateleft32((uint32_t)(x), (uint32_t)(n))

// Hashcat-style Boolean logic reductions
#define SHA256_F0(x, y, z) (((x) & (y)) | ((z) & ((x) ^ (y))))
#define SHA256_F1(x, y, z) ((z) ^ ((x) & ((y) ^ (z))))

#define SHA256_S0(x) (hc_rotl32((x), 25u) ^ hc_rotl32((x), 14u) ^ ((x) >> 3u))
#define SHA256_S1(x) (hc_rotl32((x), 15u) ^ hc_rotl32((x), 13u) ^ ((x) >> 10u))
#define SHA256_S2(x) (hc_rotl32((x), 30u) ^ hc_rotl32((x), 19u) ^ hc_rotl32((x), 10u))
#define SHA256_S3(x) (hc_rotl32((x), 26u) ^ hc_rotl32((x), 21u) ^ hc_rotl32((x), 7u))

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

// Hashcat Step Macro
#define SHA_STEP(a, b, c, d, e, f, g, h, k_val, w_val) do {     uint32_t t1 = (h) + SHA256_S3(e) + SHA256_F1(e, f, g) + (k_val) + (w_val);     uint32_t t2 = SHA256_S2(a) + SHA256_F0(a, b, c);     (d) += t1;     (h) = t1 + t2; } while(0)

#define SHA_STEP_ZERO(a, b, c, d, e, f, g, h, k_val) do {     uint32_t t1 = (h) + SHA256_S3(e) + SHA256_F1(e, f, g) + (k_val);     uint32_t t2 = SHA256_S2(a) + SHA256_F0(a, b, c);     (d) += t1;     (h) = t1 + t2; } while(0)

// Hashcat Meet-in-the-Middle Reverse Step Macro
#define SHA256_STEP_REV(a, b, c, d, e, f, g, h) do {     uint32_t t2 = SHA256_S2(b) + SHA256_F0(b, c, d);     uint32_t t1 = (a) - t2;     (a) = (b);     (b) = (c);     (c) = (d);     (d) = (e) - t1;     (e) = (f);     (f) = (g);     (g) = (h);     (h) = 0; } while(0)

__global__ void sha256_kernel_v6_hashcat(uint32_t* d_found, uint32_t d_rev_target, uint32_t target_hash0, uint32_t seed, int iterations) {
    size_t tid = (size_t)blockIdx.x * blockDim.x + threadIdx.x;

    uint32_t w[16];
    w[0] = (uint32_t)(tid + seed);
    w[1] = (uint32_t)(tid ^ 0x5a5a5a5a);
    w[2] = 0x61626364; // abcd
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

        // Rounds 4-14: ZERO WORDS ELIMINATION (No W addition)
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

        // Rounds 16-26: Constant folding & dead term removal
        w[0] = SHA256_S0(w[1]) + w[0];
        SHA_STEP(a, b, c, d, e, f, g, h, K[16], w[0]);

        w[1] = SHA256_S0(w[2]) + w[1] + 0x003c0000u;
        SHA_STEP(h, a, b, c, d, e, f, g, K[17], w[1]);

        w[2] = SHA256_S1(w[0]) + w[2] + 0x11002000u;
        SHA_STEP(g, h, a, b, c, d, e, f, K[18], w[2]);

        w[3] = SHA256_S1(w[1]) + 0x80000000u;
        SHA_STEP(f, g, h, a, b, c, d, e, K[19], w[3]);

        w[4] = SHA256_S1(w[2]);
        SHA_STEP(e, f, g, h, a, b, c, d, K[20], w[4]);

        w[5] = SHA256_S1(w[3]);
        SHA_STEP(d, e, f, g, h, a, b, c, K[21], w[5]);

        w[6] = SHA256_S1(w[4]) + 96u;
        SHA_STEP(c, d, e, f, g, h, a, b, K[22], w[6]);

        w[7] = SHA256_S1(w[5]) + w[0];
        SHA_STEP(b, c, d, e, f, g, h, a, K[23], w[7]);

        w[8] = SHA256_S1(w[6]) + w[1];
        SHA_STEP(a, b, c, d, e, f, g, h, K[24], w[8]);

        w[9] = SHA256_S1(w[7]) + w[2];
        SHA_STEP(h, a, b, c, d, e, f, g, K[25], w[9]);

        w[10] = SHA256_S1(w[8]) + w[3];
        SHA_STEP(g, h, a, b, c, d, e, f, K[26], w[10]);

        // Rounds 27-56: Rolling schedule with in-place expansion
        #define R_SCHEDULE(i, a, b, c, d, e, f, g, h) do {             w[(i) & 15] += SHA256_S1(w[((i) - 2) & 15]) + w[((i) - 7) & 15] + SHA256_S0(w[((i) - 15) & 15]);             SHA_STEP(a, b, c, d, e, f, g, h, K[i], w[(i) & 15]);         } while(0)

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

        // Hashcat Meet-in-the-Middle Early Abort Check:
        // Round 56 produces state 'h' (which corresponds to target's d_rev).
        // If they do not match, abort immediately (skips rounds 57-63)!
        if (h != d_rev_target) {
            continue;
        }

        // Only matching candidates proceed through rounds 57-63
        R_SCHEDULE(57, h, a, b, c, d, e, f, g);
        R_SCHEDULE(58, g, h, a, b, c, d, e, f);
        R_SCHEDULE(59, f, g, h, a, b, c, d, e);
        R_SCHEDULE(60, e, f, g, h, a, b, c, d);
        R_SCHEDULE(61, d, e, f, g, h, a, b, c);
        R_SCHEDULE(62, c, d, e, f, g, h, a, b);
        R_SCHEDULE(63, b, c, d, e, f, g, h, a);

        uint32_t final_h0 = 0x6a09e667 + a;
        if (final_h0 == target_hash0) {
            d_found[0] = (uint32_t)tid;
            d_found[1] = final_h0;
        }
    }
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 Hashcat-Enhanced Benchmark (v6) <<" << std::endl;
    std::cout << " Architecture: Meet-in-the-Middle (MITM) Reverse Early-Abort, Bit-Level Logic Reduction" << std::endl;
    std::cout << " Features: Round-56 Collision Check, Zero-Term Elimination, Constant Folding" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int threads_per_block = 256;
    const int blocks = 4096; // 1,048,576 concurrent evaluators
    const size_t total_threads = (size_t)blocks * threads_per_block;
    const int iterations = 1000;
    const double total_candidates = (double)total_threads * (double)iterations;

    uint32_t* d_found = nullptr;
    MUSA_CHECK(musaMalloc(&d_found, 4 * sizeof(uint32_t)));
    MUSA_CHECK(musaMemset(d_found, 0, 4 * sizeof(uint32_t)));

    // Target digest for simulation
    uint32_t target[8] = {
        0xba7816bf, 0x8f01cfea, 0x414140de, 0x5dae2223,
        0xb00361a3, 0x96177a9c, 0xb410ff61, 0xf20015ad
    };

    // Calculate Hashcat Reverse Step for Round 56 (4 backward steps)
    uint32_t a_rev = target[0] - 0x6a09e667;
    uint32_t b_rev = target[1] - 0xbb67ae85;
    uint32_t c_rev = target[2] - 0x3c6ef372;
    uint32_t d_rev = target[3] - 0xa54ff53a;
    uint32_t e_rev = target[4] - 0x510e527f;
    uint32_t f_rev = target[5] - 0x9b05688c;
    uint32_t g_rev = target[6] - 0x1f83d9ab;
    uint32_t h_rev = target[7] - 0x5be0cd19;

    SHA256_STEP_REV(a_rev, b_rev, c_rev, d_rev, e_rev, f_rev, g_rev, h_rev);
    SHA256_STEP_REV(a_rev, b_rev, c_rev, d_rev, e_rev, f_rev, g_rev, h_rev);
    SHA256_STEP_REV(a_rev, b_rev, c_rev, d_rev, e_rev, f_rev, g_rev, h_rev);
    SHA256_STEP_REV(a_rev, b_rev, c_rev, d_rev, e_rev, f_rev, g_rev, h_rev);

    uint32_t d_rev_target = d_rev;

    // Warm-up
    sha256_kernel_v6_hashcat<<<blocks, threads_per_block>>>(d_found, d_rev_target, target[0], 12345, 10);
    MUSA_CHECK(musaDeviceSynchronize());

    std::cout << "Active GPU Evaluators: " << total_threads << " | Iterations per Thread: " << iterations << std::endl;
    std::cout << "Candidates Evaluated Per Pass: " << (total_candidates / 1e6) << " Million Passwords" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int passes = 5;
    double max_speed = 0.0;
    double avg_speed = 0.0;

    for (int p = 1; p <= passes; ++p) {
        Timer timer;
        sha256_kernel_v6_hashcat<<<blocks, threads_per_block>>>(d_found, d_rev_target, target[0], 0x1337 + p, iterations);
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
    std::cout << " MTT S80 Hashcat-Enhanced Peak Throughput (v6): " << std::fixed << std::setprecision(2)
              << max_speed << " MH/s (Average: " << avg_speed << " MH/s)" << std::endl;
    std::cout << " Equivalent Rate: " << std::fixed << std::setprecision(2)
              << (max_speed / 1000.0) << " Billion Candidates/sec (" << (max_speed / 100.0) << " 亿组/秒)" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    musaFree(d_found);
    return 0;
}

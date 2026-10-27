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

// 2-Way ILP Macro: Interleaves candidate A and candidate B
#define SHA_STEP_2WAY(a0, b0, c0, d0, e0, f0, g0, h0, k0, w0,                       a1, b1, c1, d1, e1, f1, g1, h1, k1, w1) do {     uint32_t t1_0 = (h0) + SIGMA1(e0) + CH(e0, f0, g0) + (k0) + (w0);     uint32_t t1_1 = (h1) + SIGMA1(e1) + CH(e1, f1, g1) + (k1) + (w1);     uint32_t t2_0 = SIGMA0(a0) + MAJ(a0, b0, c0);     uint32_t t2_1 = SIGMA0(a1) + MAJ(a1, b1, c1);     (d0) += t1_0; (h0) = t1_0 + t2_0;     (d1) += t1_1; (h1) = t1_1 + t2_1; } while(0)

#define SHA_STEP_ZERO_2WAY(a0, b0, c0, d0, e0, f0, g0, h0, k0,                            a1, b1, c1, d1, e1, f1, g1, h1, k1) do {     uint32_t t1_0 = (h0) + SIGMA1(e0) + CH(e0, f0, g0) + (k0);     uint32_t t1_1 = (h1) + SIGMA1(e1) + CH(e1, f1, g1) + (k1);     uint32_t t2_0 = SIGMA0(a0) + MAJ(a0, b0, c0);     uint32_t t2_1 = SIGMA0(a1) + MAJ(a1, b1, c1);     (d0) += t1_0; (h0) = t1_0 + t2_0;     (d1) += t1_1; (h1) = t1_1 + t2_1; } while(0)

__global__ void sha256_kernel_v5_ilp2(uint32_t* d_found, uint32_t target_hash0, uint32_t seed, int iterations) {
    size_t tid = ((size_t)blockIdx.x * blockDim.x + threadIdx.x) * 2;

    uint32_t w0[16];
    uint32_t w1[16];

    uint32_t base0 = (uint32_t)(tid + seed);
    uint32_t base1 = (uint32_t)(tid + 1 + seed);

    w0[1] = (uint32_t)(tid ^ 0x5a5a5a5a);
    w1[1] = (uint32_t)((tid + 1) ^ 0x5a5a5a5a);

    w0[2] = 0x61626364; w1[2] = 0x61626364;
    w0[3] = 0x80000000; w1[3] = 0x80000000;
    w0[15] = 96;        w1[15] = 96;

    for (int iter = 0; iter < iterations; ++iter) {
        w0[0] = base0 + (uint32_t)iter;
        w1[0] = base1 + (uint32_t)iter;

        uint32_t a0 = 0x6a09e667, b0 = 0xbb67ae85, c0 = 0x3c6ef372, d0 = 0xa54ff53a;
        uint32_t e0 = 0x510e527f, f0 = 0x9b05688c, g0 = 0x1f83d9ab, h0 = 0x5be0cd19;

        uint32_t a1 = 0x6a09e667, b1 = 0xbb67ae85, c1 = 0x3c6ef372, d1 = 0xa54ff53a;
        uint32_t e1 = 0x510e527f, f1 = 0x9b05688c, g1 = 0x1f83d9ab, h1 = 0x5be0cd19;

        // Rounds 0-3
        SHA_STEP_2WAY(a0, b0, c0, d0, e0, f0, g0, h0, K[0], w0[0],
                      a1, b1, c1, d1, e1, f1, g1, h1, K[0], w1[0]);
        SHA_STEP_2WAY(h0, a0, b0, c0, d0, e0, f0, g0, K[1], w0[1],
                      h1, a1, b1, c1, d1, e1, f1, g1, K[1], w1[1]);
        SHA_STEP_2WAY(g0, h0, a0, b0, c0, d0, e0, f0, K[2], w0[2],
                      g1, h1, a1, b1, c1, d1, e1, f1, K[2], w1[2]);
        SHA_STEP_2WAY(f0, g0, h0, a0, b0, c0, d0, e0, K[3], w0[3],
                      f1, g1, h1, a1, b1, c1, d1, e1, K[3], w1[3]);

        // Rounds 4-14: Zero-term elimination (Dual)
        SHA_STEP_ZERO_2WAY(e0, f0, g0, h0, a0, b0, c0, d0, K[4],  e1, f1, g1, h1, a1, b1, c1, d1, K[4]);
        SHA_STEP_ZERO_2WAY(d0, e0, f0, g0, h0, a0, b0, c0, K[5],  d1, e1, f1, g1, h1, a1, b1, c1, K[5]);
        SHA_STEP_ZERO_2WAY(c0, d0, e0, f0, g0, h0, a0, b0, K[6],  c1, d1, e1, f1, g1, h1, a1, b1, K[6]);
        SHA_STEP_ZERO_2WAY(b0, c0, d0, e0, f0, g0, h0, a0, K[7],  b1, c1, d1, e1, f1, g1, h1, a1, K[7]);
        SHA_STEP_ZERO_2WAY(a0, b0, c0, d0, e0, f0, g0, h0, K[8],  a1, b1, c1, d1, e1, f1, g1, h1, K[8]);
        SHA_STEP_ZERO_2WAY(h0, a0, b0, c0, d0, e0, f0, g0, K[9],  h1, a1, b1, c1, d1, e1, f1, g1, K[9]);
        SHA_STEP_ZERO_2WAY(g0, h0, a0, b0, c0, d0, e0, f0, K[10], g1, h1, a1, b1, c1, d1, e1, f1, K[10]);
        SHA_STEP_ZERO_2WAY(f0, g0, h0, a0, b0, c0, d0, e0, K[11], f1, g1, h1, a1, b1, c1, d1, e1, K[11]);
        SHA_STEP_ZERO_2WAY(e0, f0, g0, h0, a0, b0, c0, d0, K[12], e1, f1, g1, h1, a1, b1, c1, d1, K[12]);
        SHA_STEP_ZERO_2WAY(d0, e0, f0, g0, h0, a0, b0, c0, K[13], d1, e1, f1, g1, h1, a1, b1, c1, K[13]);
        SHA_STEP_ZERO_2WAY(c0, d0, e0, f0, g0, h0, a0, b0, K[14], c1, d1, e1, f1, g1, h1, a1, b1, K[14]);

        // Round 15: Length padding
        SHA_STEP_2WAY(b0, c0, d0, e0, f0, g0, h0, a0, K[15], w0[15],
                      b1, c1, d1, e1, f1, g1, h1, a1, K[15], w1[15]);

        // Rounds 16-26: Constant folding + dual calculation
        w0[0] = SIG0(w0[1]) + w0[0];
        w1[0] = SIG0(w1[1]) + w1[0];
        SHA_STEP_2WAY(a0, b0, c0, d0, e0, f0, g0, h0, K[16], w0[0],
                      a1, b1, c1, d1, e1, f1, g1, h1, K[16], w1[0]);

        w0[1] = SIG0(w0[2]) + w0[1] + 0x003c0000u;
        w1[1] = SIG0(w1[2]) + w1[1] + 0x003c0000u;
        SHA_STEP_2WAY(h0, a0, b0, c0, d0, e0, f0, g0, K[17], w0[1],
                      h1, a1, b1, c1, d1, e1, f1, g1, K[17], w1[1]);

        w0[2] = SIG1(w0[0]) + w0[2] + 0x11002000u;
        w1[2] = SIG1(w1[0]) + w1[2] + 0x11002000u;
        SHA_STEP_2WAY(g0, h0, a0, b0, c0, d0, e0, f0, K[18], w0[2],
                      g1, h1, a1, b1, c1, d1, e1, f1, K[18], w1[2]);

        w0[3] = SIG1(w0[1]) + 0x80000000u;
        w1[3] = SIG1(w1[1]) + 0x80000000u;
        SHA_STEP_2WAY(f0, g0, h0, a0, b0, c0, d0, e0, K[19], w0[3],
                      f1, g1, h1, a1, b1, c1, d1, e1, K[19], w1[3]);

        w0[4] = SIG1(w0[2]);
        w1[4] = SIG1(w1[2]);
        SHA_STEP_2WAY(e0, f0, g0, h0, a0, b0, c0, d0, K[20], w0[4],
                      e1, f1, g1, h1, a1, b1, c1, d1, K[20], w1[4]);

        w0[5] = SIG1(w0[3]);
        w1[5] = SIG1(w1[3]);
        SHA_STEP_2WAY(d0, e0, f0, g0, h0, a0, b0, c0, K[21], w0[5],
                      d1, e1, f1, g1, h1, a1, b1, c1, K[21], w1[5]);

        w0[6] = SIG1(w0[4]) + 96u;
        w1[6] = SIG1(w1[4]) + 96u;
        SHA_STEP_2WAY(c0, d0, e0, f0, g0, h0, a0, b0, K[22], w0[6],
                      c1, d1, e1, f1, g1, h1, a1, b1, K[22], w1[6]);

        w0[7] = SIG1(w0[5]) + w0[0];
        w1[7] = SIG1(w1[5]) + w1[0];
        SHA_STEP_2WAY(b0, c0, d0, e0, f0, g0, h0, a0, K[23], w0[7],
                      b1, c1, d1, e1, f1, g1, h1, a1, K[23], w1[7]);

        w0[8] = SIG1(w0[6]) + w0[1];
        w1[8] = SIG1(w1[6]) + w1[1];
        SHA_STEP_2WAY(a0, b0, c0, d0, e0, f0, g0, h0, K[24], w0[8],
                      a1, b1, c1, d1, e1, f1, g1, h1, K[24], w1[8]);

        w0[9] = SIG1(w0[7]) + w0[2];
        w1[9] = SIG1(w1[7]) + w1[2];
        SHA_STEP_2WAY(h0, a0, b0, c0, d0, e0, f0, g0, K[25], w0[9],
                      h1, a1, b1, c1, d1, e1, f1, g1, K[25], w1[9]);

        w0[10] = SIG1(w0[8]) + w0[3];
        w1[10] = SIG1(w1[8]) + w1[3];
        SHA_STEP_2WAY(g0, h0, a0, b0, c0, d0, e0, f0, K[26], w0[10],
                      g1, h1, a1, b1, c1, d1, e1, f1, K[26], w1[10]);

        // Rounds 27-63: In-place rolling schedule (Dual ILP)
        #define R_SCHEDULE_2WAY(i, a0, b0, c0, d0, e0, f0, g0, h0,                                    a1, b1, c1, d1, e1, f1, g1, h1) do {             w0[(i) & 15] += SIG1(w0[((i) - 2) & 15]) + w0[((i) - 7) & 15] + SIG0(w0[((i) - 15) & 15]);             w1[(i) & 15] += SIG1(w1[((i) - 2) & 15]) + w1[((i) - 7) & 15] + SIG0(w1[((i) - 15) & 15]);             SHA_STEP_2WAY(a0, b0, c0, d0, e0, f0, g0, h0, K[i], w0[(i) & 15],                           a1, b1, c1, d1, e1, f1, g1, h1, K[i], w1[(i) & 15]);         } while(0)

        R_SCHEDULE_2WAY(27, f0, g0, h0, a0, b0, c0, d0, e0,  f1, g1, h1, a1, b1, c1, d1, e1);
        R_SCHEDULE_2WAY(28, e0, f0, g0, h0, a0, b0, c0, d0,  e1, f1, g1, h1, a1, b1, c1, d1);
        R_SCHEDULE_2WAY(29, d0, e0, f0, g0, h0, a0, b0, c0,  d1, e1, f1, g1, h1, a1, b1, c1);
        R_SCHEDULE_2WAY(30, c0, d0, e0, f0, g0, h0, a0, b0,  c1, d1, e1, f1, g1, h1, a1, b1);
        R_SCHEDULE_2WAY(31, b0, c0, d0, e0, f0, g0, h0, a0,  b1, c1, d1, e1, f1, g1, h1, a1);

        R_SCHEDULE_2WAY(32, a0, b0, c0, d0, e0, f0, g0, h0,  a1, b1, c1, d1, e1, f1, g1, h1);
        R_SCHEDULE_2WAY(33, h0, a0, b0, c0, d0, e0, f0, g0,  h1, a1, b1, c1, d1, e1, f1, g1);
        R_SCHEDULE_2WAY(34, g0, h0, a0, b0, c0, d0, e0, f0,  g1, h1, a1, b1, c1, d1, e1, f1);
        R_SCHEDULE_2WAY(35, f0, g0, h0, a0, b0, c0, d0, e0,  f1, g1, h1, a1, b1, c1, d1, e1);
        R_SCHEDULE_2WAY(36, e0, f0, g0, h0, a0, b0, c0, d0,  e1, f1, g1, h1, a1, b1, c1, d1);
        R_SCHEDULE_2WAY(37, d0, e0, f0, g0, h0, a0, b0, c0,  d1, e1, f1, g1, h1, a1, b1, c1);
        R_SCHEDULE_2WAY(38, c0, d0, e0, f0, g0, h0, a0, b0,  c1, d1, e1, f1, g1, h1, a1, b1);
        R_SCHEDULE_2WAY(39, b0, c0, d0, e0, f0, g0, h0, a0,  b1, c1, d1, e1, f1, g1, h1, a1);
        R_SCHEDULE_2WAY(40, a0, b0, c0, d0, e0, f0, g0, h0,  a1, b1, c1, d1, e1, f1, g1, h1);
        R_SCHEDULE_2WAY(41, h0, a0, b0, c0, d0, e0, f0, g0,  h1, a1, b1, c1, d1, e1, f1, g1);
        R_SCHEDULE_2WAY(42, g0, h0, a0, b0, c0, d0, e0, f0,  g1, h1, a1, b1, c1, d1, e1, f1);
        R_SCHEDULE_2WAY(43, f0, g0, h0, a0, b0, c0, d0, e0,  f1, g1, h1, a1, b1, c1, d1, e1);
        R_SCHEDULE_2WAY(44, e0, f0, g0, h0, a0, b0, c0, d0,  e1, f1, g1, h1, a1, b1, c1, d1);
        R_SCHEDULE_2WAY(45, d0, e0, f0, g0, h0, a0, b0, c0,  d1, e1, f1, g1, h1, a1, b1, c1);
        R_SCHEDULE_2WAY(46, c0, d0, e0, f0, g0, h0, a0, b0,  c1, d1, e1, f1, g1, h1, a1, b1);
        R_SCHEDULE_2WAY(47, b0, c0, d0, e0, f0, g0, h0, a0,  b1, c1, d1, e1, f1, g1, h1, a1);

        R_SCHEDULE_2WAY(48, a0, b0, c0, d0, e0, f0, g0, h0,  a1, b1, c1, d1, e1, f1, g1, h1);
        R_SCHEDULE_2WAY(49, h0, a0, b0, c0, d0, e0, f0, g0,  h1, a1, b1, c1, d1, e1, f1, g1);
        R_SCHEDULE_2WAY(50, g0, h0, a0, b0, c0, d0, e0, f0,  g1, h1, a1, b1, c1, d1, e1, f1);
        R_SCHEDULE_2WAY(51, f0, g0, h0, a0, b0, c0, d0, e0,  f1, g1, h1, a1, b1, c1, d1, e1);
        R_SCHEDULE_2WAY(52, e0, f0, g0, h0, a0, b0, c0, d0,  e1, f1, g1, h1, a1, b1, c1, d1);
        R_SCHEDULE_2WAY(53, d0, e0, f0, g0, h0, a0, b0, c0,  d1, e1, f1, g1, h1, a1, b1, c1);
        R_SCHEDULE_2WAY(54, c0, d0, e0, f0, g0, h0, a0, b0,  c1, d1, e1, f1, g1, h1, a1, b1);
        R_SCHEDULE_2WAY(55, b0, c0, d0, e0, f0, g0, h0, a0,  b1, c1, d1, e1, f1, g1, h1, a1);
        R_SCHEDULE_2WAY(56, a0, b0, c0, d0, e0, f0, g0, h0,  a1, b1, c1, d1, e1, f1, g1, h1);
        R_SCHEDULE_2WAY(57, h0, a0, b0, c0, d0, e0, f0, g0,  h1, a1, b1, c1, d1, e1, f1, g1);
        R_SCHEDULE_2WAY(58, g0, h0, a0, b0, c0, d0, e0, f0,  g1, h1, a1, b1, c1, d1, e1, f1);
        R_SCHEDULE_2WAY(59, f0, g0, h0, a0, b0, c0, d0, e0,  f1, g1, h1, a1, b1, c1, d1, e1);
        R_SCHEDULE_2WAY(60, e0, f0, g0, h0, a0, b0, c0, d0,  e1, f1, g1, h1, a1, b1, c1, d1);
        R_SCHEDULE_2WAY(61, d0, e0, f0, g0, h0, a0, b0, c0,  d1, e1, f1, g1, h1, a1, b1, c1);
        R_SCHEDULE_2WAY(62, c0, d0, e0, f0, g0, h0, a0, b0,  c1, d1, e1, f1, g1, h1, a1, b1);
        R_SCHEDULE_2WAY(63, b0, c0, d0, e0, f0, g0, h0, a0,  b1, c1, d1, e1, f1, g1, h1, a1);

        uint32_t final_h0_0 = 0x6a09e667 + a0;
        uint32_t final_h0_1 = 0x6a09e667 + a1;

        if (final_h0_0 == target_hash0) {
            d_found[0] = (uint32_t)tid;
            d_found[1] = final_h0_0;
        }
        if (final_h0_1 == target_hash0) {
            d_found[0] = (uint32_t)(tid + 1);
            d_found[1] = final_h0_1;
        }
    }
}

int main() {
    print_device_info();
    std::cout << "\n>>> Moore Threads MTT S80 Password Candidate Dual-ILP Benchmark (v5) <<" << std::endl;
    std::cout << " Features: 2-Way Instruction-Level Parallelism (ILP), Zero-Term Elimination, Pipeline Latency Hiding" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int threads_per_block = 256;
    const int blocks = 2048; // 524,288 threads * 2 candidates = 1,048,576 concurrent candidates
    const size_t total_threads = (size_t)blocks * threads_per_block;
    const size_t concurrent_candidates = total_threads * 2;
    const int iterations = 1000;
    const double total_candidates = (double)concurrent_candidates * (double)iterations;

    uint32_t* d_found = nullptr;
    MUSA_CHECK(musaMalloc(&d_found, 4 * sizeof(uint32_t)));
    MUSA_CHECK(musaMemset(d_found, 0, 4 * sizeof(uint32_t)));

    uint32_t dummy_target = 0xdeadbeef;

    // Warm-up
    sha256_kernel_v5_ilp2<<<blocks, threads_per_block>>>(d_found, dummy_target, 12345, 10);
    MUSA_CHECK(musaDeviceSynchronize());

    std::cout << "Active GPU Threads: " << total_threads << " | Concurrent Candidates: " << concurrent_candidates << " | Iterations: " << iterations << std::endl;
    std::cout << "Candidates Evaluated Per Pass: " << (total_candidates / 1e6) << " Million Passwords" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    const int passes = 5;
    double max_speed = 0.0;
    double avg_speed = 0.0;

    for (int p = 1; p <= passes; ++p) {
        Timer timer;
        sha256_kernel_v5_ilp2<<<blocks, threads_per_block>>>(d_found, dummy_target, 0x1337 + p, iterations);
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
    std::cout << " MTT S80 Password Candidate Peak Throughput (v5): " << std::fixed << std::setprecision(2)
              << max_speed << " MH/s (Average: " << avg_speed << " MH/s)" << std::endl;
    std::cout << " Equivalent Rate: " << std::fixed << std::setprecision(2)
              << (max_speed / 1000.0) << " Billion Passwords/second (" << (max_speed / 100.0) << " 亿组/秒)" << std::endl;
    std::cout << "----------------------------------------------------------------------------------" << std::endl;

    musaFree(d_found);
    return 0;
}

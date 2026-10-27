#pragma once

#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <string>
#include <musa_runtime.h>

#define MUSA_CHECK(call)                                                          do {                                                                              musaError_t err = (call);                                                     if (err != musaSuccess) {                                                         fprintf(stderr, "[MUSA ERROR] %s:%d: %s (%d)\n",                                    __FILE__, __LINE__, musaGetErrorString(err), (int)err);               exit(EXIT_FAILURE);                                                       }                                                                         } while (0)

inline void print_device_info(int device_id = 0) {
    musaDeviceProp prop;
    MUSA_CHECK(musaGetDeviceProperties(&prop, device_id));
    printf("===============================================================\n");
    printf(" GPU Device: %s (ID: %d)\n", prop.name, device_id);
    printf(" Total Global Memory: %.2f GB\n", (double)prop.totalGlobalMem / (1024.0 * 1024.0 * 1024.0));
    printf(" Multiprocessors (SMs): %d\n", prop.multiProcessorCount);
    printf(" Memory Bus Width: %d-bit\n", prop.memoryBusWidth);
    printf(" Memory Clock Rate: %.2f GHz\n", (double)prop.memoryClockRate / 1e6);
    printf("===============================================================\n");
}

class Timer {
public:
    Timer() { reset(); }
    void reset() { start_time_ = std::chrono::high_resolution_clock::now(); }
    double elapsed_ms() const {
        auto now = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(now - start_time_).count();
    }
    double elapsed_sec() const {
        return elapsed_ms() / 1000.0;
    }
private:
    std::chrono::time_point<std::chrono::high_resolution_clock> start_time_;
};

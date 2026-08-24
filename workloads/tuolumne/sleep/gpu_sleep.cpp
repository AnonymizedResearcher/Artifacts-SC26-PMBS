#include <hip/hip_runtime.h>

#include <cstdio>
#include <cstdlib>

// -----------------------------------------------------------------------------
// Launch enough thread blocks to occupy the GPU while each thread busy-waits
// for the requested number of clock cycles.
//
// This benchmark is intended for scheduling experiments, not performance
// measurements. It simply keeps the allocated GPU busy for approximately the
// requested duration.
//
// Compile:
//      ml rocm
//      hipcc -O2 ./gpu_sleep.cpp -o gpu_sleep
// -----------------------------------------------------------------------------
__global__ void gpu_sleep(unsigned long long cycles)
{
    unsigned long long start = clock64();

    while ((clock64() - start) < cycles) {
        // Busy wait
    }
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return EXIT_FAILURE;

    // Sleep time in seconds
    double seconds = atof(argv[1]);

    // Query GPU properties
    hipDeviceProp_t prop;
    hipError_t err = hipGetDeviceProperties(&prop, 0);
    if (err != hipSuccess) {
        fprintf(stderr, "hipGetDeviceProperties failed: %s\n",
                hipGetErrorString(err));
        return EXIT_FAILURE;
    }

    // clockRate is reported in kHz
    unsigned long long cycles =
        static_cast<unsigned long long>(seconds * prop.clockRate * 1000.0);

    // Launch enough blocks to occupy the GPU.
    //
    // On LLNL's MI300A systems (SPX mode), a GPU exposes 228 Compute Units.
    // We launch one block per CU with 256 threads per block (4 wavefronts),
    // which is sufficient for a simple scheduling benchmark.
    hipLaunchKernelGGL(
        gpu_sleep,
        dim3(228),
        dim3(256),
        0,
        0,
        cycles);

    err = hipGetLastError();
    if (err != hipSuccess) {
        fprintf(stderr, "Kernel launch failed: %s\n",
                hipGetErrorString(err));
        return EXIT_FAILURE;
    }

    err = hipDeviceSynchronize();
    if (err != hipSuccess) {
        fprintf(stderr, "hipDeviceSynchronize failed: %s\n",
                hipGetErrorString(err));
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
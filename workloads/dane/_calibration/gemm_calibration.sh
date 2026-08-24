#!/bin/bash
#SBATCH --job-name=gemm_calibrate
#SBATCH --partition=pdebug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --output=gemm_calibrate.out
#SBATCH --error=gemm_calibrate.err

set -euo pipefail

# Activate RAJAPerf environment
. "$HOME/Artifacts-SC26-PMBS/workloads/dane/raja-perf/spack/share/spack/setup-env.sh"

spack env activate \
    "$HOME/Artifacts-SC26-PMBS/workloads/dane/raja-perf/dane/raja-perf/workspace/software/spack/raja_perf"

export OMP_NUM_THREADS=1

for size in 350000 1100000 1750000; do
    echo "================================"
    echo "GEMM size = $size"
    echo "================================"

    time raja-perf.exe \
        --size "$size" \
        --kernels Polybench_GEMM \
        --variants Base_OpenMP \
        --outdir "gemm_${size}"
done
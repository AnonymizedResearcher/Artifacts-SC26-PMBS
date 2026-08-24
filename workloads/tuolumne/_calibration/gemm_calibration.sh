#!/bin/bash
# flux: --job-name=gemm_calibrate
# flux: --queue=pdebug
# flux: --nodes=1
# flux: --nslots=1
# flux: --cores-per-slot=24
# flux: --gpus-per-slot=1
# flux: --time-limit=2m
# flux: --output=/Artifacts-SC26-PMBS/workloads/tuolumne/_calibration/gemm_calibrate.out
# flux: --error=/Artifacts-SC26-PMBS/workloads/tuolumne/_calibration/gemm_calibrate.err

set -euo pipefail

# Activate the Benchpark/Spack environment
. "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/raja-perf/spack/share/spack/setup-env.sh"

spack env activate \
    "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/raja-perf/tuolumne/raja-perf/workspace/software/spack/raja_perf"


export OMP_NUM_THREADS=24

for size in 10000000 30000000 70000000; do
    echo "================================"
    echo "GEMM size = $size"
    echo "================================"

    time raja-perf.exe \
        --size "$size" \
        --kernels Polybench_GEMM \
        --variants Base_HIP \
        --outdir "gemm_${size}"
done
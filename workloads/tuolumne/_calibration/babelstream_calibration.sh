#!/bin/bash
# flux: --job-name=babel_calibrate
# flux: --queue=pdebug
# flux: --nodes=1
# flux: --nslots=1
# flux: --cores-per-slot=24
# flux: --gpus-per-slot=1
# flux: --time-limit=2m
# flux: --output=/Artifacts-SC26-PMBS/workloads/tuolumne/_calibration/babel_calibrate.out
# flux: --error=/Artifacts-SC26-PMBS/workloads/tuolumne/_calibration/babel_calibrate.err

set -euo pipefail

# Activate BabelStream environment
. "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/babelstream/spack/share/spack/setup-env.sh"

spack env activate \
    "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/babelstream/tuolumne/babelstream/workspace/software/spack/babelstream"

export OMP_NUM_THREADS=1

echo "=== 20M elements, 1000 iterations ==="
time hip-stream -n 10 -s 50000000

echo ""
echo "=== 20M elements, 5000 iterations ==="
time hip-stream -n 10 -s 250000000

echo ""
echo "=== 20M elements, 10000 iterations ==="
time hip-stream -n 10 -s 500000000
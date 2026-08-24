#!/bin/bash
#SBATCH --job-name=babel_calibrate
#SBATCH --partition=pdebug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --output=babel_calibrate.out
#SBATCH --error=babel_calibrate.err

set -euo pipefail

# Activate BabelStream environment
. "$HOME/Artifacts-SC26-PMBS/workloads/dane/babelstream/spack/share/spack/setup-env.sh"

spack env activate \
    "$HOME/Artifacts-SC26-PMBS/workloads/dane/babelstream/dane/babelstream/workspace/software/spack/babelstream"

export OMP_NUM_THREADS=1

echo "=== 20M elements, 10 iterations ==="
time omp-stream -n 8 -s 20000000

echo ""
echo "=== 20M elements, 50 iterations ==="
time omp-stream -n 40 -s 20000000

echo ""
echo "=== 20M elements, 100 iterations ==="
time omp-stream -n 80 -s 20000000

# Important:
# The baelstream output reports averages over iterations by kernel
# === 10M elements, 200 iterations ===
# BabelStream
# Version: 5.0
# Implementation: OpenMP
# Running  Classic kernels 200 times in  Classic order 
# Number of elements: 10000000
# Precision: double
# Array size: 80.0 MB
# Total size: 240.0 MB
# Function    MB/s        Min (sec)   Max         Average     
# Copy        17063.993   0.00938     0.00943     0.00940     
# Mul         16736.423   0.00956     0.00968     0.00958     
# Add         19972.662   0.01202     0.01214     0.01204     
# Triad       20053.441   0.01197     0.01208     0.01200     
# Dot         23710.097   0.00675     0.00685     0.00680     


# but the itereations change the execution time which we want
# real	0m1.157s
# user	0m1.105s
# sys	0m0.043s

# real	0m5.134s
# user	0m5.089s
# sys	0m0.043s

# real	0m11.859s
# user	0m10.073s
# sys	0m0.043s
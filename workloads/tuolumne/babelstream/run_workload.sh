#!/bin/bash

set -euo pipefail

source "$WORKLOADS_ROOT/common_func.sh"
parse_args "$@"

# -----------------------------------------------------------------------------
# Workload parameters
# we keep the memory footprint equal for all problem classes, but we change the number of iterations to get different execution times.
# memory is set to use like 20% of the max MEM/Core allowed: 5.33 GiB per core
M=1000000
case "$problem_class" in
    A)
        array_size=$((50 * M))
        iterations=10
        ;;
    B)
        array_size=$((250 * M))
        iterations=10
        ;;
    C)
        array_size=$((500 * M))
        iterations=10
        ;;
    *)
        echo "Unknown problem class: $problem_class"
        exit 1
        ;;
esac

# -----------------------------------------------------------------------------
# Activate the Benchpark/Spack environment
. "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/babelstream/spack/share/spack/setup-env.sh"

spack env activate \
    "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/babelstream/tuolumne/babelstream/workspace/software/spack/babelstream"

# -----------------------------------------------------------------------------
# Run BabelStream
export OMP_NUM_THREADS="$cores_per_mpi_rank"

# print configureation
echo "Configuration: BabelStream on Tuolumne"
conf_printer
echo

hip-stream \
    -n "$iterations" \
    -s "$array_size"

echo "------------------------------"
echo "Finished BabelStream workload."
echo "------------------------------"
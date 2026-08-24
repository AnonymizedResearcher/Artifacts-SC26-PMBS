#!/bin/bash

set -euo pipefail

source "$WORKLOADS_ROOT/common_func.sh"
parse_args "$@"

# -----------------------------------------------------------------------------
# Workload parameters
M=1000000
case "$problem_class" in
    A)
        array_size=$((10 * M))
        ;;
    B)
        array_size=$((30 * M))
        ;;
    C)
        array_size=$((70 * M))
        ;;
    *)
        echo "Unknown problem class: $problem_class"
        exit 1
        ;;
esac

# -----------------------------------------------------------------------------
# Activate the Benchpark/Spack environment
. "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/raja-perf/spack/share/spack/setup-env.sh"

spack env activate \
    "$HOME/Artifacts-SC26-PMBS/workloads/tuolumne/raja-perf/tuolumne/raja-perf/workspace/software/spack/raja_perf"

# -----------------------------------------------------------------------------
# Set output directory, but only for the first job of the bulsubmit
# --job-index is set by the submit_workload.sh script, and is used to determine if this is the first job of the bulk submission or not. The first job will create the output directory, and all other jobs will use a temporary directory that will be deleted after the job is done.
if [[ "$job_index" == "1" ]]; then
    raja_outdir="$outdir/raja-perf-output"
    mkdir -p "$raja_outdir"
else
    raja_outdir=$(mktemp -d /var/tmp/raja-perf.XXXXXX)
    # trap 'rm -rf "$raja_outdir"' EXIT
fi

# -----------------------------------------------------------------------------
# Run Raja-Perf
export OMP_NUM_THREADS="$cores_per_mpi_rank"

# print configureation
echo "----------------------------"
echo "Configuration: Raja-Perf on Tuolumne"
conf_printer
echo "----------------------------"

echo "----------------------------"
echo "Running:"
echo "raja-perf.exe --size $array_size --kernels $kernel --variants $variant"

raja-perf.exe \
    --size "$array_size" \
    --kernels "$kernel" \
    --variants "$variant" \
    --outdir "$raja_outdir"


echo "----------------------------"
echo "Finished Raja-Perf workload."
echo "----------------------------"
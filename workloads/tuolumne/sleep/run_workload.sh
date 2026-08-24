#!/bin/bash

set -euo pipefail

source "$WORKLOADS_ROOT/common_func.sh"
parse_args "$@"

# -----------------------------------------------------------------------------
# Workload parameters
case "$problem_class" in
    A)
        sleep_time=0
        ;;
    B)
        sleep_time=2
        ;;
    C)
        sleep_time=5
        ;;
    *)
        echo "Unknown problem class: $problem_class"
        exit 1
        ;;
esac

# -----------------------------------------------------------------------------
# Run Sleep
export OMP_NUM_THREADS="$cores_per_mpi_rank"

# print configureation
echo "Configuration: Sleep on Tuolumne"
conf_printer
echo

if [[ "$problem_class" == "A" ]]; then
    /bin/true
    echo "Zero-duration workload completed"
else
    $WORKLOADS_ROOT/tuolumne/sleep/gpu_sleep "$sleep_time"
    echo "Slept for $sleep_time seconds"
fi

echo "------------------------"
echo "Finished Sleep workload."
echo "------------------------"
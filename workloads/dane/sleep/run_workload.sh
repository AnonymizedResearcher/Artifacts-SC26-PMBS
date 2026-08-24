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
        sleep_time=5
        ;;
    C)
        sleep_time=10
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
echo "Configuration: Sleep on Dane"
conf_printer
echo

sleep "$sleep_time"
echo "Slept for $sleep_time seconds"

echo "------------------------"
echo "Finished Sleep workload."
echo "------------------------"
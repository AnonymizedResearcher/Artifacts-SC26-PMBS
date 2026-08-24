#!/bin/bash

set -euo pipefail

source "$WORKLOADS_ROOT/common_func.sh"
parse_args "$@"

# -----------------------------------------------------------------------------
# Workload parameters
TK=10000
case "$problem_class" in
    A)
        array_size=$((35 * TK))
        ;;
    B)
        array_size=$((110 * TK))
        ;;
    C)
        array_size=$((175 * TK))
        ;;
    *)
        echo "Unknown problem class: $problem_class"
        exit 1
        ;;
esac

# -----------------------------------------------------------------------------
# Activate the Benchpark/Spack environment
. "$HOME/Artifacts-SC26-PMBS/workloads/dane/raja-perf/spack/share/spack/setup-env.sh"

spack env activate \
    "$HOME/Artifacts-SC26-PMBS/workloads/dane/raja-perf/dane/raja-perf/workspace/software/spack/raja_perf"

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
echo "Configuration: Raja-Perf on Dane"
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


# Available kernels (<group name>_<kernel name>):
# -----------------------------------------
# Basic_ARRAY_OF_PTRS
# Basic_COPY8
# Basic_DAXPY
# Basic_DAXPY_ATOMIC
# Basic_EMPTY
# Basic_IF_QUAD
# Basic_INDEXLIST
# Basic_INDEXLIST_3LOOP
# Basic_INIT3
# Basic_INIT_VIEW1D
# Basic_INIT_VIEW1D_OFFSET
# Basic_MAT_MAT_SHARED
# Basic_MULADDSUB
# Basic_NESTED_INIT
# Basic_PI_ATOMIC
# Basic_PI_REDUCE
# Basic_REDUCE3_INT
# Basic_REDUCE_STRUCT
# Basic_TRAP_INT
# Basic_MULTI_REDUCE
# Lcals_DIFF_PREDICT
# Lcals_EOS
# Lcals_FIRST_DIFF
# Lcals_FIRST_MIN
# Lcals_FIRST_SUM
# Lcals_GEN_LIN_RECUR
# Lcals_HYDRO_1D
# Lcals_HYDRO_2D
# Lcals_INT_PREDICT
# Lcals_PLANCKIAN
# Lcals_TRIDIAG_ELIM
# Polybench_2MM
# Polybench_3MM
# Polybench_ADI
# Polybench_ATAX
# Polybench_FDTD_2D
# Polybench_FLOYD_WARSHALL
# Polybench_GEMM
# Polybench_GEMVER
# Polybench_GESUMMV
# Polybench_HEAT_3D
# Polybench_JACOBI_1D
# Polybench_JACOBI_2D
# Polybench_MVT
# Stream_ADD
# Stream_COPY
# Stream_DOT
# Stream_MUL
# Stream_TRIAD
# Apps_CONVECTION3DPA
# Apps_DEL_DOT_VEC_2D
# Apps_DIFFUSION3DPA
# Apps_EDGE3D
# Apps_ENERGY
# Apps_FEMSWEEP
# Apps_FIR
# Apps_INTSC_HEXHEX
# Apps_INTSC_HEXRECT
# Apps_LTIMES
# Apps_LTIMES_NOVIEW
# Apps_MASS3DEA
# Apps_MASS3DPA
# Apps_MASS3DPA_ATOMIC
# Apps_MASSVEC3DPA
# Apps_MATVEC_3D_STENCIL
# Apps_NODAL_ACCUMULATION_3D
# Apps_PRESSURE
# Apps_VOL3D
# Apps_ZONAL_ACCUMULATION_3D
# Algorithm_SCAN
# Algorithm_SORT
# Algorithm_SORTPAIRS
# Algorithm_REDUCE_SUM
# Algorithm_MEMSET
# Algorithm_MEMCPY
# Algorithm_ATOMIC
# Algorithm_HISTOGRAM
# Comm_HALO_PACKING
# Comm_HALO_PACKING_FUSED
# Comm_HALO_SENDRECV
# Comm_HALO_EXCHANGE
# Comm_HALO_EXCHANGE_FUSED

# Available variants (<set name>_<set name>):
# -----------------------------------------------
# Base_Seq
# Lambda_Seq
# RAJA_Seq
# Base_OpenMP
# Lambda_OpenMP
# RAJA_OpenMP
# Base_OpenMPTarget
# RAJA_OpenMPTarget
# Base_CUDA
# Lambda_CUDA
# RAJA_CUDA
# Base_HIP
# Lambda_HIP
# RAJA_HIP
# Kokkos_Lambda
# Base_SYCL
# RAJA_SYCL
# -----------------------------------------------------------------------------
# Argparsing function
parse_args() {

    problem_class=""
    nodes=""
    mpi_ranks_per_node=""
    cores_per_mpi_rank=""
    gpus_per_mpi_rank=""
    kernel=""
    variant=""

    # Parser loop
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --job-index)
                job_index="$2"
                shift 2
                ;;
            --outdir)
                outdir="$2"
                shift 2
                ;;
            --problem-class)
                problem_class="$2"
                shift 2
                ;;
            --nodes)
                nodes="$2"
                shift 2
                ;;
            --mpi-ranks-per-node)
                mpi_ranks_per_node="$2"
                shift 2
                ;;
            --cores-per-mpi-rank)
                cores_per_mpi_rank="$2"
                shift 2
                ;;
            --gpus-per-mpi-rank)
                gpus_per_mpi_rank="$2"
                shift 2
                ;;
            --kernel)
                kernel="$2"
                shift 2
                ;;
            --variant)
                variant="$2"
                shift 2
                ;;
            *)
                echo "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Configuration printer function
conf_printer() {
    if [ -n "${kernel:-}" ]; then
        echo "  Kernel          = ${kernel}"
    fi
    if [ -n "${variant:-}" ]; then
        echo "  Variant         = ${variant}"
    fi
    echo "  Nodes           = ${nodes}"
    echo "  MPI ranks/node  = ${mpi_ranks_per_node}"
    echo "  Cores/MPI rank  = ${cores_per_mpi_rank}"
    echo "  OMP_NUM_THREADS = ${OMP_NUM_THREADS:-unset}"
    echo "  GPUs/MPI rank   = ${gpus_per_mpi_rank}"
    echo "  Problem class   = ${problem_class}"
    # if [ -n "${outdir:-}" ]; then
    #     echo "  Output directory = ${outdir}"
    # fi
}

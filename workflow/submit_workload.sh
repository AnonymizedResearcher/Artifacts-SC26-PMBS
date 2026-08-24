#!/bin/bash

# Script to submit work to the flux hierarchy instances:
#   Check files
#   Submit to every instance
#   Write hierarchy.json

set -euo pipefail

EXPERIMENT_DIR="$1"
HASH="$2"

# input files
CONFIG_FILE="$EXPERIMENT_DIR/_config.json"
HIERARCHY_FILE="$EXPERIMENT_DIR/_hierarchy.json"
COMPUTING_CLUSTER=$(hostname -s | sed 's/[0-9]*$//')

# Output files (.err and .out) of the bulksubmit jobs
BULKJOBS_DIR="$EXPERIMENT_DIR/bulkjobs"
# Job IDs of the bulksubmit jobs
# per level, so defined in the loop below

# Create the output directory if it doesn't exist
mkdir -p "$BULKJOBS_DIR"

# -----------------------------------------------------------------------------
# Write the bulksubmit script
write_script() {
    local cmd="$1"
    local script="$2"

    {
        echo "#!/bin/bash"
        echo
        echo "set -euo pipefail"
        echo

        # restore line continuations
        printf '%s\n' "$cmd" | sed 's/\\[[:space:]]*/\\\
/g'
    } > "$script"

    chmod +x "$script"
}

# -----------------------------------------------------------------------------
# Read config.json
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: configuration file not found:"
    echo "  $CONFIG_FILE"
    exit 1
fi

# -----------------------------------------------------------------------------
# Read hierarchy.json
if [[ ! -f "$HIERARCHY_FILE" ]]; then
    echo "Error: hierarchy file not found:"
    echo "  $HIERARCHY_FILE"
    exit 1
fi

# -----------------------------------------------------------------------------
# Check the lowest level value in the configuration
LOWEST_LEVEL=$(jq -r ".instance_level | keys | map(tonumber) | max" "$CONFIG_FILE")
declare -A JOB_INSTANCE_PATHS

# -----------------------------------------------------------------------------
# Process every hierarchy level
for level in $(seq 0 ${LOWEST_LEVEL})
do

    # # x-x-x-x-x-x-x-x-x-x-x-x-x-x-x
    # # TEST: flux proxy on all levels
    # job_instance_path=$(jq -r --arg level "$level" \
    #     '.instance_level[$level].job_instance_path' "$HIERARCHY_FILE")
    # # needs case destinction, because technically, we are in the level 0, and can not proxy into it.
    # if [[ "$level" -eq 0 ]]; then
    #     flux jobs -a
    # else
    #     flux proxy "$job_instance_path" flux jobs -a
    # fi
    # echo "flux proxy $level works"
    # continue
    # # x-x-x-x-x-x-x-x-x-x-x-x-x-x-x

    echo "Processing level $level"

    # Skip levels that have no submission, meaning no n_jobs is missing
    n_jobs=$(jq -r --arg level "$level" \
        '.instance_level[$level].n_jobs // empty' "$CONFIG_FILE")
    if [[ -z "$n_jobs" ]]; then
        echo "Level $level has no submission, skipping."
        continue
    fi

    # parse the arguments
    job_instance_path=$(jq -r --arg level "$level" \
        '.instance_level[$level].job_instance_path' "$HIERARCHY_FILE")
    JOB_INSTANCE_PATHS[$level]="$job_instance_path"

    job_prefix="$HASH-L${level}"
    
    # Number of identical jobs to submit
    n_jobs=$(jq -r --arg level "$level" \
        '.instance_level[$level].n_jobs' "$CONFIG_FILE")
    time_limit=$(jq -r --arg level "$level" \
        '.instance_level[$level].job_request_time' "$CONFIG_FILE")
    # Resources requested per job
    nodes=$(jq -r --arg level "$level" \
        '.instance_level[$level].job_request_nodes' "$CONFIG_FILE")
    ntasks_per_node=$(jq -r --arg level "$level" \
        '.instance_level[$level].job_request_ntasks_per_node' "$CONFIG_FILE")
    cores_per_task=$(jq -r --arg level "$level" \
        '.instance_level[$level].job_request_cores_per_task' "$CONFIG_FILE")
    gpus_per_task=$(jq -r --arg level "$level" \
        '.instance_level[$level].job_request_gpus_per_task' "$CONFIG_FILE")
    # Workload and characteristics 
    workload=$(jq -r --arg level "$level" \
        '.instance_level[$level].workload' "$CONFIG_FILE")
    problem_class=$(jq -r --arg level "$level" \
        '.instance_level[$level].problem_class' "$CONFIG_FILE")

    # split workload if it contains %, like for specific kernels
    IFS='%' read -r workload kernel variant <<< "$workload"

    # echo "Workload: $workload, Kernel: $kernel, Variant: $variant"

    # -----------------------------------------------------------------------------
    # Build the command
    # flux run|submit|bulksubmit take either per task options as here (--ntasks), or resource options --cores=N & --tasks-per-node=N, etc.
    # The difference seems to be in how the resources are distributed. 
    # The first distributes tasks with resources equally over nodes, the second assigns cores to each task.
    ntasks=$(( $nodes * $ntasks_per_node ))

    # only pass if present
    kernel_arg=""
    [[ -n "$kernel" ]] && kernel_arg="--kernel $kernel"
    variant_arg=""
    [[ -n "$variant" ]] && variant_arg="--variant $variant"

   # -----------------------------------------------------------------------------
    # Flux bulksubmit job
    # cmd="
    # seq $n_jobs | flux bulksubmit \
    #     --job-name=$job_prefix-{} \
    #     --time-limit=$time_limit \
    #     --nodes=$nodes \
    #     --ntasks=$ntasks \
    #     --cores-per-task=$cores_per_task \
    #     --gpus-per-task=$gpus_per_task \
    #     --output=$BULKJOBS_DIR/L${level}_job{}.out \
    #     --error=$BULKJOBS_DIR/L${level}_job{}.err \
    #     $WORKLOADS_ROOT/$COMPUTING_CLUSTER/$workload/run_workload.sh \
    #         --outdir $BULKJOBS_DIR \
    #         --problem-class $problem_class \
    #         --nodes $nodes \
    #         --mpi-ranks-per-node $ntasks_per_node \
    #         --cores-per-mpi-rank $cores_per_task \
    #         --gpus-per-mpi-rank $gpus_per_task \
    #         $kernel_arg \
    #         $variant_arg
    # "

    # Basically, we only keep the output and error of the first job, and discard the rest.
    # This is because we are running identical jobs, and only need to see the output of one of them.
    # And avoid the creation, storage, and deletion of many output and error files, which can be a lot of data for many jobs.

    JOB_LIST="$BULKJOBS_DIR/jobs_L${level}.list"
    OUT_LIST="$BULKJOBS_DIR/outputs_L${level}.list"
    ERR_LIST="$BULKJOBS_DIR/errors_L${level}.list"

    seq "$n_jobs" > "$JOB_LIST"

    {
        echo "$BULKJOBS_DIR/L${level}_job1.out"
        for ((i=2; i<=n_jobs; i++)); do
            echo "/dev/null"
        done
    } > "$OUT_LIST"

    {
        echo "$BULKJOBS_DIR/L${level}_job1.err"
        for ((i=2; i<=n_jobs; i++)); do
            echo "/dev/null"
        done
    } > "$ERR_LIST"

    # bulksubmit can be blocked with --wait-event=start
    # https://flux-framework.readthedocs.io/projects/flux-core/en/stable/man1/flux-bulksubmit.html

    cmd="
    flux bulksubmit \
        --job-name=$job_prefix-{0} \
        --time-limit=$time_limit \
        --nodes=$nodes \
        --ntasks=$ntasks \
        --cores-per-task=$cores_per_task \
        --gpus-per-task=$gpus_per_task \
        --output={1} \
        --error={2} \
        $WORKLOADS_ROOT/$COMPUTING_CLUSTER/$workload/run_workload.sh \
            --job-index {0} \
            --outdir $BULKJOBS_DIR \
            --problem-class $problem_class \
            --nodes $nodes \
            --mpi-ranks-per-node $ntasks_per_node \
            --cores-per-mpi-rank $cores_per_task \
            --gpus-per-mpi-rank $gpus_per_task \
            $kernel_arg \
            $variant_arg \
        ::: \$(cat $JOB_LIST) \
        :::+ \$(cat $OUT_LIST) \
        :::+ \$(cat $ERR_LIST)
    "

    # write the bulksubmit script and make it executable
    write_script "$cmd" "$BULKJOBS_DIR/bulksubmit_L${level}.sh"

    # -----------------------------------------------------------------------------
    # Debug why bash: -c: option requires an argument error/warning occurs 
    # with the above command, despite executing correctly
    # # 1. Error to a file
    # if flux proxy "$job_instance_path" bash -c "$cmd" \
    #         > "$JOB_IDS_RAW" \
    #         2> "$EXPERIMENT_DIR/submit.err"; then
    #     echo "Submit succeeded."
    # else
    #     echo "Submit failed."
    # fi
    # echo "rc=$?"
    # # --> rc=0 and error message in submit.err

    # # 2. Test proxy and bash interaction
    # flux proxy "$job_instance_path" bash -c 'true' \
    #     2>"$EXPERIMENT_DIR/submit.err"
    # echo "rc=$?"
    # # --> rc=0 and error message in submit.err

    # # 3. Test bash and seq
    # flux proxy "$job_instance_path" bash -c '
    #     seq 5 | cat
    # ' 2>"$EXPERIMENT_DIR/submit.err"
    # echo "rc=$?"
    # # --> bash: -c: option requires an argument AND
    # # 1
    # # 2
    # # 3
    # # 4
    # # 5
    # # rc=0

    # # 4. Smallest bash command that issues it?
    # flux proxy "$job_instance_path" bash -c "seq 5" 2>"$EXPERIMENT_DIR/submit.err"
    # echo "rc=$?"
    # # --> fails: seq: missing operand

    # # 5. Smallest bash command that issues it?
    # flux proxy "$job_instance_path" bash -c 'seq 5' 2>"$EXPERIMENT_DIR/submit.err"
    # echo "rc=$?"
    # # # --> fails: seq: missing operand

    # # 6. strace it
    # strace -f -e execve \
    # flux proxy "$job_instance_path" bash -c 'seq 5'
    # # --> ["flux", "proxy", "fMnJw7M", "bash", "-c", "seq 5"]

    # # 7. Strace the child
    # flux proxy "$job_instance_path" strace -f -e execve bash -c 'seq 5'
    # # --> execve("/usr/bin/bash", ["bash", "-c", "seq", "5"] and then seq: missing operand
    # # YES: The issue is here

    # # 8. Strace the child with new line
    # flux proxy "$job_instance_path" strace -f -e execve bash -c '
    #     seq 5
    # '
    # # execve("/usr/bin/bash", ["bash", "-c"] and then bash: -c: option requires an argument, +++ exited with 2 +++

    # # 9. Test with a shell command: seq 5 inside a script
    # chmod +x test.sh
    # flux proxy "$job_instance_path" test.sh
    # #  --> works, so that is the way to go

    echo "Bulk submission script for level $level created"

done

# -----------------------------------------------------------------------------
# Process every hierarchy level
for level in $(seq 0 ${LOWEST_LEVEL})
do

    # check if a .sh exist, if not, no submission for this level, so skip it
    if [[ ! -f "$BULKJOBS_DIR/bulksubmit_L${level}.sh" ]]; then
        continue
    fi

    JOB_IDS_RAW="$BULKJOBS_DIR/jobids_L${level}.raw"

    # on level 0 no proxy possible to submit
    if [[ "$level" -eq 0 ]]; then
        bash "$BULKJOBS_DIR/bulksubmit_L${level}.sh" > "$JOB_IDS_RAW"
    else
        # execute the bulksubmit script
        flux proxy "${JOB_INSTANCE_PATHS[$level]}" $BULKJOBS_DIR/bulksubmit_L${level}.sh > "$JOB_IDS_RAW"
    fi

    echo "Level $level: Jobs submitted."

done

echo "All workload jobs submitted."
#!/bin/bash

# Script to finalize the flux hierarchy:
#   Check files
#   Process every instance (bottom-up)
#       Wait for jobs
#       Collect metrics
#       Shutdown instance

set -euo pipefail

EXPERIMENT_DIR="$1"
HASH="$2"

# input files
CONFIG_FILE="$EXPERIMENT_DIR/_config.json"
HIERARCHY_FILE="$EXPERIMENT_DIR/_hierarchy.json"
BULKJOBS_DIR="$EXPERIMENT_DIR/bulkjobs"

# output files
HIERARCHY_METRICS_FILE="$EXPERIMENT_DIR/metrics_hierarchy.json"
WORKLOAD_METRICS_FILE="$EXPERIMENT_DIR/metrics_workload.csv"
INSTANCE_METRICS_FILE="$EXPERIMENT_DIR/metrics_instance.csv"
# pstree, lstopo, and lscpus files in:
SYSTEM_DIR="$EXPERIMENT_DIR/system"
DESTRUCTION_LOG="$EXPERIMENT_DIR/flux/destruction.log"

mkdir -p "$SYSTEM_DIR"

# -----------------------------------------------------------------------------
# Function to get resource list fields
get_resource_field() {
    local level=$1
    local jobpath=$2
    local field=$3

    if [[ "$level" -eq 0 ]]; then
        flux resource list -no "{$field}"
    else
        flux proxy "$jobpath" flux resource list -no "{$field}"
    fi
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
# Initialize metrics JSON
METRICS='{"instance_level":{}}'

# -----------------------------------------------------------------------------
# Save final hierarchy once (this instance is the level 0, or experiment root ≠ system root)
flux pstree > $SYSTEM_DIR/pstree.out

# -----------------------------------------------------------------------------
# Check the lowest level value
LOWEST_LEVEL=$(jq -r '."instance_level" | keys | map(tonumber) | max' "$HIERARCHY_FILE")


# -----------------------------------------------------------------------------
# Collect results: Process every hierarchy level (bottom-up)
echo "Collect instance topologies, resources, and workload metrics (bottom-up)"
for level in $(seq "$LOWEST_LEVEL" -1 0)
do

    # Drain queue:
    # this needs to be inside the overall loop, we can't drain all
    # level queues first, because the child instance is
    # part of the queue of the parent. needs to be destroyed first.
    hierarchy=$(jq -c \
        --arg level "$level" \
        '.instance_level[$level]' \
        "$HIERARCHY_FILE")

    submission=$(jq -r '.submission' <<< "$hierarchy")
    job_instance_path=$(jq -r '.job_instance_path' <<< "$hierarchy")

    # Drain levels to which workload jobs were submitted
    if [[ "$submission" == "true" ]]; then
        if [[ "$level" -eq 0 ]]; then
            flux queue drain
        else
            flux proxy "$job_instance_path" flux queue drain
        fi

        echo "Level $level workload finished and queue drained."
    fi

    # PART 1: Collect topology, lscpu and resource state for all instances
    # ====================================================================
    echo "Collect topologies for level $level"

    # ----------------------------------------------------------
    # Get the HW topology of each instance
    if [[ "$level" -eq 0 ]]; then
        lstopo --no-io $SYSTEM_DIR/L${level}_topology.svg
        lscpu > $SYSTEM_DIR/L${level}_lscpu.txt
    else
        flux proxy "$job_instance_path" lstopo --no-io $SYSTEM_DIR/L${level}_topology.svg
        flux proxy "$job_instance_path" lscpu > $SYSTEM_DIR/L${level}_lscpu.txt
    fi

    # ----------------------------------------------------------
    # Collect resource state (always), REMEMBER, we can not proxy into the level 0
    nnodes=$(get_resource_field "$level" "$job_instance_path" nnodes)
    ncores=$(get_resource_field "$level" "$job_instance_path" ncores)
    ngpus=$(get_resource_field "$level" "$job_instance_path" ngpus)
    nodelist=$(get_resource_field "$level" "$job_instance_path" nodelist)

    resource_json=$(jq -n \
        --argjson nnodes "$nnodes" \
        --argjson ncores "$ncores" \
        --argjson ngpus "$ngpus" \
        '{nnodes:$nnodes,ncores:$ncores,ngpus:$ngpus}')

    # PART 2: Collect job metrics (if any jobs were submitted on this level)
    # ======================================================================
    # Collect job metrics
    if [[ "$submission" == "true" ]]; then

        JOB_IDS_RAW="$BULKJOBS_DIR/jobids_L${level}.raw"
        JOB_IDS_CSV="$BULKJOBS_DIR/jobids_L${level}.csv"

        # Handle all the job IDs from the bulksubmit jobs
        # Create file with header only once
        if [[ ! -f "$JOB_IDS_CSV" ]]; then
            echo "jobid,jobname,instance_level" > "$JOB_IDS_CSV"
        fi

        job_prefix="$HASH-L${level}"

        # Read job IDs and append formatted rows to CSV
        awk -v prefix="$job_prefix" -v level="$level" \
            '{print $0 "," prefix "-" NR "," level}' \
            "$JOB_IDS_RAW" >> "$JOB_IDS_CSV"

        rm -f "$JOB_IDS_RAW"

        echo "Collect workload metrics for level $level"
            python3 $WORKFLOW_ROOT/collect_workload_metrics.py \
                "$job_instance_path" \
                "$JOB_IDS_CSV" \
                "$WORKLOAD_METRICS_FILE"
    else
        echo "No submission on level $level, skipping workload metrics collection."
    fi

    # ----------------------------------------------------------
    # Collect remaining metrics
    if [[ "$level" -eq 0 ]]; then
        qmanager=$(flux module stats sched-fluxion-qmanager)
        resource=$(flux module stats sched-fluxion-resource)
        params=$(flux ion-resource params)
    else
        qmanager=$(flux proxy "$job_instance_path" flux module stats sched-fluxion-qmanager)
        resource=$(flux proxy "$job_instance_path" flux module stats sched-fluxion-resource)
        params=$(flux proxy "$job_instance_path" flux ion-resource params)
    fi

    METRICS=$(
        jq \
            --arg level "$level" \
            --argjson resource_json "$resource_json" \
            --argjson qmanager "$qmanager" \
            --argjson resource "$resource" \
            --argjson params "$params" \
            '
            .instance_level[$level] = {
                resource_list: $resource_json,
                qmanager_stats: $qmanager,
                resource_stats: $resource,
                resource_params: $params
            }
            ' <<< "$METRICS"
    )

    # PART 3: Collcet and destroy the flux hierarchy
    # ==============================================

    if [[ "$level" -eq 0 ]]; then
        echo "Level $level no destruction possible as root created with flux batch."
        continue
    fi
    # -------------------
    # Shutdown instance 
    hierarchy=$(jq -c --arg level "$level" '.instance_level[$level]' "$HIERARCHY_FILE")
    job_instance_path=$(jq -r '.job_instance_path' <<< "$hierarchy")

    echo "Level $level destruction ------------------------------" \
        >> "$DESTRUCTION_LOG"

    if flux proxy "$job_instance_path" flux shutdown \
            >> "$DESTRUCTION_LOG" 2>&1; then
        echo "Level $level instance destroyed."
    else
        echo "ERROR: Failed to destroy level $level instance. See:"
        echo "  $DESTRUCTION_LOG"
        exit 1
    fi

    # ----------------------------------------------------------
    # Collect instance metrics
    python3 $WORKFLOW_ROOT/collect_instance_metrics.py \
        "$HIERARCHY_FILE" \
        "$INSTANCE_METRICS_FILE" \
        "$level"

    echo "Level $level instance metrics collected."

    # ----------------------------------------------------------
    # Clear all .err and .out of the bulksubmit jobs files but 1: L${level}-1.out and L${level}-1.err
    # Not needed anymore as the submit job only creates one per bulksubmit job, but we keep it for safety
    # find "$BULKJOBS_DIR" \
    #     -name "L${level}_job*.out" \
    #     ! -name "L${level}_job1.out" \
    #     -delete

    # find "$BULKJOBS_DIR" \
    #     -name "L${level}_job*.err" \
    #     ! -name "L${level}_job1.err" \
    #     -delete

done

# -----------------------------------------------------------------------------
# Write metrics sorted by level
printf '%s\n' "$METRICS" |
jq '
.instance_level |= (
    to_entries
    | sort_by(.key | tonumber)
    | from_entries
)
' > "$HIERARCHY_METRICS_FILE"

echo "All hierarchy levels destroyed and metrics saved."
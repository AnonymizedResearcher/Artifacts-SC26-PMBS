#!/bin/bash

# Submits an experiment to the computing system
# Slurm system:
    # Slurm
    # └── sbatch
    #     └── srun flux start        (bootstrap only)
    #         └── flux batch    ← level 0
    #             ├── flux batch / flux alloc ← level 1
    #             └── ...
# Flux system:
    # Flux system broker
    # └── flux batch            ← level 0
    #     ├── flux batch / flux alloc ← level 1
    #     └── ...

set -euo pipefail

source "$(dirname "$0")/paths.sh"

EXPERIMENT_DIR="$1"
HASH="$2"
COMPUTING_CLUSTER=$(hostname -s | sed 's/[0-9]*$//')

# input files
RESOURCES_FILE="$EXPERIMENT_DIR/_system_resources.json"

# -----------------------------------------------------------------------------
# Check agg_resources.json
if [ ! -f "$RESOURCES_FILE" ]; then
    echo "Error: Resources file not found."
    exit 1
fi

# Extract the resources
nodes=$(jq -r '.sys_nodes // empty' "$RESOURCES_FILE")
queue=$(jq -r '.queue // empty' "$RESOURCES_FILE")
time_limit=$(jq -r '.slurm_time_limit // empty' "$RESOURCES_FILE")
# nodes=$(jq -r --arg level "$level" \
#     '.instance_level[$level].res_nodes // empty' \
#     "$RESOURCES_FILE")
# ntasks=$(jq -r --arg level "$level" \
#     '.instance_level[$level].res_ntasks // empty' \
#     "$RESOURCES_FILE")
# cores_per_task=$(jq -r --arg level "$level" \
#     '.instance_level[$level].res_cores_per_task // empty' \
#     "$RESOURCES_FILE")

# -----------------------------------------------------------------------------
# Submit the experiment with the extracted resources
# Dane is slurm managed, so sbatch and call the run-experiment.sh
if [[ $COMPUTING_CLUSTER = "dane" ]]; then
    OUTDIR="$EXPERIMENT_DIR/slurm"
    mkdir -p "$OUTDIR"

    sbatch \
        --partition="$queue" \
        --nodes="$nodes" \
        --time="$time_limit" \
        --exclusive \
        --output="$OUTDIR/slurm.out" \
        --error="$OUTDIR/slurm.err" \
        --job-name="exp_$HASH" \
        "$WORKFLOW_ROOT"/flux_starter.sh "$EXPERIMENT_DIR" "$HASH"
elif [[ $COMPUTING_CLUSTER = "tuolumne" ]]; then
    "$WORKFLOW_ROOT"/flux_driver.sh $EXPERIMENT_DIR $HASH
else
    echo "Error: Unknown system."
    exit 1
fi


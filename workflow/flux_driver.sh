#!/bin/bash

# Additional intermediate script to start Flux broker on a Slurm managed system:

set -euo pipefail

EXPERIMENT_DIR="$1"
HASH="$2"
COMPUTING_CLUSTER=$(hostname -s | sed 's/[0-9]*$//')

# input files
AGG_INSTANCE_RESOURCES_FILE="$EXPERIMENT_DIR/_agg_instance_resources.json"
RESOURCES_FILE="$EXPERIMENT_DIR/_system_resources.json"

# -----------------------------------------------------------------------------
# Check system_resources.json
if [[ ! -f "$RESOURCES_FILE" ]]; then
    echo "Error: system resources file not found:"
    echo "  $RESOURCES_FILE"
    exit 1
fi
# If this is on a Flux managed system
# We need to set time limit and queue for the flux batch job
queue=$(jq -r '.queue // empty' "$RESOURCES_FILE")
time_limit=$(jq -r '.flux_time_limit // empty' "$RESOURCES_FILE")

# -----------------------------------------------------------------------------
# Check agg_resources.json
if [ ! -f "$AGG_INSTANCE_RESOURCES_FILE" ]; then
    echo "Error: Aggregated instance resources file not found."
    exit 1
fi

level=0
nodes=$(jq -r --arg level "$level" \
    '.instance_level[$level].instance_nodes // empty' \
    "$AGG_INSTANCE_RESOURCES_FILE")
# instance_nslots=$(jq -r --arg level "$level" \
#     '.instance_level[$level].instance_slots // empty' \
#     "$AGG_INSTANCE_RESOURCES_FILE")
# instance_cores_per_slot=$(jq -r --arg level "$level" \
#     '.instance_level[$level].instance_cores_per_slot // empty' \
#     "$AGG_INSTANCE_RESOURCES_FILE")

OUTDIR="$EXPERIMENT_DIR/flux"
mkdir -p "$OUTDIR"

# -----------------------------------------------------------------------------
# Construct the command line arguments for the Flux batch job
params=(
    --nodes="$nodes"
    # --nslots="$instance_nslots"
    # --cores-per-slot="$instance_cores_per_slot"
    --exclusive
    --job-name="exp_$HASH"
    --output="$OUTDIR/flux-batch.out"
    --error="$OUTDIR/flux-batch.err"
)

if [ "$COMPUTING_CLUSTER" = "tuolumne" ]; then
    params+=(--queue="$queue")
    params+=(--time-limit="$time_limit")
fi

# -----------------------------------------------------------------------------
# Flux batch job
flux batch \
    "${params[@]}" \
    "$WORKFLOW_ROOT/run_experiment.sh" \
    "$EXPERIMENT_DIR" \
    "$HASH"

# -----------------------------------------------------------------------------
# Prevent the temporary broker from exiting before all queued jobs had been dispatched and completed.
# Not needed on Tuolumne, as the system flux is managed by the system.
if [ "$COMPUTING_CLUSTER" = "dane" ]; then
    flux queue drain
fi

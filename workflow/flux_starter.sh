#!/bin/bash

# the Flux driver script starting flux with srun inside a Slurm allocation

set -euo pipefail

EXPERIMENT_DIR="$1"
HASH="$2"

# input files
AGG_INSTANCE_RESOURCES_FILE="$EXPERIMENT_DIR/_agg_instance_resources.json"

# -----------------------------------------------------------------------------
# Check agg_resources.json
if [ ! -f "$AGG_INSTANCE_RESOURCES_FILE" ]; then
    echo "Error: Aggregated instance resources file not found."
    exit 1
fi

# Extract the resources
level=0
nodes=$(jq -r --arg level "$level" \
    '.instance_level[$level].instance_nodes // empty' \
    "$AGG_INSTANCE_RESOURCES_FILE")

# Start a 4-broker Flux instance inside this Slurm allocation.
# Flux exits when flux-driver.sh exits.
srun -N "${nodes}" \
    flux start "$WORKFLOW_ROOT"/flux_driver.sh "$EXPERIMENT_DIR" "$HASH"

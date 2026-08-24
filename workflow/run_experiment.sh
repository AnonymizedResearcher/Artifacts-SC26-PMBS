#!/bin/bash

# Coordinates each single experiments based on config file
#   Creates and configures flux hierarchy
#   Submits the workload to the instances
#   Destroys the flux hierarchy after the experiment is done
#   Collects the results of the experiment

set -euo pipefail

EXPERIMENT_DIR="$1"
HASH="$2"

# Configure hierarchy
echo "-----------------------"
echo "Configuring hierarchy..."
"$WORKFLOW_ROOT"/configure_hierarchy.sh $EXPERIMENT_DIR
echo "-----------------------"

# Submit the workload to the instances
echo "Submitting workload..."
"$WORKFLOW_ROOT"/submit_workload.sh $EXPERIMENT_DIR $HASH 
echo "-----------------------"

# Collect metrics and destroy the flux hierarchy after the experiment is done
echo "Collecting metrics and destroying hierarchy..."
"$WORKFLOW_ROOT"/collect_and_destroy.sh $EXPERIMENT_DIR $HASH 

# Check experiment results
echo "Checking experiment results..."
"$WORKFLOW_ROOT"/check_experiment.sh  "$EXPERIMENT_DIR"
echo "-----------------------"

echo "Experiment finished and results collected."
echo "==================="
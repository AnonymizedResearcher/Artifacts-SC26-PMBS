#!/bin/bash

set -u

# 1. Adapt the paths.py first, then run this.
EXPERIMENT_TYPES=("experiments")
# 2. Add experiment folders, each containing an experiments_generator.py
folders="SO_P SO_C SO_M SW_P SW_C SW_M" 
# folders="13Aug26_S_P"
# 3. Run this script, the cluster is determined by the hostname.

# create and source the paths
script_dir="$(dirname "$0")"

for EXPERIMENT_TYPE in "${EXPERIMENT_TYPES[@]}"; do
    python3 "$script_dir/paths.py" "$EXPERIMENT_TYPE"
    source "$script_dir/paths.sh"

    # read the system name from the hostname
    system=$(hostname -s | sed 's/[0-9]*$//')

    # always delet the Overview file, it will be newly generated and filled with all experiments of that run.
    rm -rf "$EXPERIMENT_ROOT/$system/experiments_overview.csv"

    # Call all generators in the subfolders
    # create the dir on vast
    for dir in ${folders[@]}; do 
        if [ -d "$EXPERIMENT_ROOT/$system/$dir" ]; then
            # create the dir on vast
            # rm -rf "$VAST_ROOT/$system/$dir"
            mkdir -p "$VAST_ROOT/$system/$dir"
            # run the experiment generator
            python3 $WORKFLOW_ROOT/experiments_generator.py $EXPERIMENT_ROOT $system $dir
        fi
    done

    # Call the overall runner
    python3 $WORKFLOW_ROOT/experiments_loop.py $EXPERIMENT_ROOT $VAST_ROOT $system $WORKFLOW_ROOT
done

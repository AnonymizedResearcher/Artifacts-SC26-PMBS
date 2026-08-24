#!/bin/bash

# Check whether an experiment completed successfully

set -euo pipefail

EXPERIMENT_DIR="$1"

HIERARCHY_FILE="$EXPERIMENT_DIR/_hierarchy.json"
BULKJOBS_DIR="$EXPERIMENT_DIR/bulkjobs"
DESTRUCTION_LOG="$EXPERIMENT_DIR/flux/destruction.log"
SUCCESS_FILE="$EXPERIMENT_DIR/finished.log"

SUBMITTING_LEVELS=$(
    jq '[.instance_level[] | select(.submission == "true")] | length' \
        "$HIERARCHY_FILE"
)

# -----------------------------------------------------------------------------
# 1. Check workload output/error files
#
# There must be exactly one .out and one .err file per submitting level.

shopt -s nullglob

out_files=("$BULKJOBS_DIR"/L*_job1.out)
err_files=("$BULKJOBS_DIR"/L*_job1.err)

n_out=${#out_files[@]}
n_err=${#err_files[@]}

if [[ "$n_out" -ne "$SUBMITTING_LEVELS" ]]; then
    echo "ERROR: Expected $SUBMITTING_LEVELS workload .out files, found $n_out."
    exit 1
fi

if [[ "$n_err" -ne "$SUBMITTING_LEVELS" ]]; then
    echo "ERROR: Expected $SUBMITTING_LEVELS workload .err files, found $n_err."
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. Check result files

for file in \
    metrics_instance.csv \
    metrics_hierarchy.json \
    metrics_workload.csv
do
    if [[ ! -f "$EXPERIMENT_DIR/$file" ]]; then
        echo "ERROR: Missing result file: $file"
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# 3. Check destruction log

if [[ ! -f "$DESTRUCTION_LOG" ]]; then
    echo "ERROR: Missing destruction log:"
    echo "  $DESTRUCTION_LOG"
    exit 1
fi

# -----------------------------------------------------------------------------
# All checks passed

touch "$SUCCESS_FILE"

echo "Experiment correctness check passed."
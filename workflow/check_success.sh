#!/bin/bash

# Script to check if the experiment was successful

# 1. Adapt the paths.py first, then run this.
EXPERIMENT_TYPE="01_PMBS"
# EXPERIMENT_TYPE="00_debug"
# 2. Add experiment folders, each containing an experiments_generator.py
folders="SO_P SO_C SO_M SW_P SW_C SW_M" # exclude _P, as it seems less and less interesting
# folders="12Aug26_SW_M"
# 3. Run this script, the cluster is determined by the hostname.

# create and source the paths
script_dir="$(dirname "$0")"
python3 "$script_dir/paths.py" "$EXPERIMENT_TYPE"
source "$script_dir/paths.sh"

# read the system name from the hostname
system=$(hostname -s | sed 's/[0-9]*$//')

# file to check for success
success_file="finished.log"

# success summary file
success_summary_file="$EXPERIMENT_ROOT/$system/success_summary.txt"
rm -f "$success_summary_file"
success_fail_list="$EXPERIMENT_ROOT/$system/fail_list.csv"
rm -f "$success_fail_list"
not_started_list="$EXPERIMENT_ROOT/$system/not_started_list.csv"
rm -f "$not_started_list"

experiments=0
failed=0
not_started=0
success=0

for dir in ${folders[@]}; do

    if [[ ! -d "$EXPERIMENT_ROOT/$system/$dir" ]]; then
        continue
    fi

    experiments_table="$EXPERIMENT_ROOT/$system/$dir/experiments_table.csv"

    # Number of experiments, excluding header
    length=$(($(wc -l < "$experiments_table") - 1))
    experiments=$((experiments + length))

    # Read hash, rep, and experiment_subdir using Python's CSV parser
    while IFS=, read -r hash_ rep experiment_subdir; do

        experiment_dir="$VAST_ROOT/$experiment_subdir/${hash_}_${rep}"

        # echo "Checking experiment: $experiment_dir"
        if [[ ! -d "$experiment_dir" ]]; then
            # NOT_STARTED
            subdir="${experiment_subdir#"$system"/}"
            echo "$system,$subdir,${hash_}_${rep}" >> "$not_started_list"
            not_started=$((not_started + 1))
        elif [[ -f "$experiment_dir/$success_file" ]]; then
            success=$((success + 1))
        else
            subdir="${experiment_subdir#"$system"/}"
            echo "$system,$subdir,${hash_}_${rep}" >> "$success_fail_list"
            failed=$((failed + 1))
            # no need for deletion, if unsuccesfull, it will be recreated in the next run of the experiment
            # rm -rf "$experiment_dir"
        fi

    done < <(
        python3 - "$experiments_table" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="") as f:
    for row in csv.DictReader(f):
        print(f'{row["hash"]},{row["rep"]},{row["experiment_subdir"]}')
PY
    )

done

echo "Experiments: $experiments, Success: $success, Not Started: $not_started, Failed: $failed" >> "$success_summary_file"

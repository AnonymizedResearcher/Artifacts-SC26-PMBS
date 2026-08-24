#!/bin/bash

# Script to create and configure the flux hierarchy:
#   Check files
#   Process every instance
#       Create if required
#       Configure every instance
#   Write hierarchy.json

set -euo pipefail

EXPERIMENT_DIR="$1"

# input files
CONFIG_FILE="$EXPERIMENT_DIR/_config.json"
RESOURCES_FILE="$EXPERIMENT_DIR/_agg_instance_resources.json"
SYSTEM_FILE="$EXPERIMENT_DIR/_system_resources.json"

# output files
HIERARCHY_FILE="$EXPERIMENT_DIR/_hierarchy.json"
AFFINITY_FILE="$EXPERIMENT_DIR/flux/affinity"

# -----------------------------------------------------------------------------
# Check config.json
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: configuration file not found:"
    echo "  $CONFIG_FILE"
    exit 1
fi

# -----------------------------------------------------------------------------
# Check agg_resources.json
if [[ ! -f "$RESOURCES_FILE" ]]; then
    echo "Error: aggregated resources file not found:"
    echo "  $RESOURCES_FILE"
    exit 1
fi

# -----------------------------------------------------------------------------
# Check system_resources.json
if [[ ! -f "$SYSTEM_FILE" ]]; then
    echo "Error: system resources file not found:"
    echo "  $SYSTEM_FILE"
    exit 1
fi

cpu_affinity="false"
cpu_affinity=$(jq -r 'if .cpu_affinity == null then "false" else .cpu_affinity end' "$SYSTEM_FILE")

# -----------------------------------------------------------------------------
# Initialize hierarchy (in memory)
HIERARCHY_JSON='{"instance_level":{}}'

# -----------------------------------------------------------------------------
# Check the lowest level value in the configuration
LOWEST_LEVEL=$(jq -r ".instance_level | keys | map(tonumber) | max" "$CONFIG_FILE")

# -----------------------------------------------------------------------------
# Process every hierarchy level
for level in $(seq 0 ${LOWEST_LEVEL})
do
    echo "Processing level $level"

    # ----------------------------------------------------------
    # Check what resources needed and create child instance (except for root)
    instance_nodes=$(jq -r --arg level "$level" \
        '.instance_level[$level].instance_nodes // empty' \
        "$RESOURCES_FILE")
    instance_nslots=$(jq -r --arg level "$level" \
        '.instance_level[$level].instance_slots // empty' \
        "$RESOURCES_FILE")
    instance_cores_per_slot=$(jq -r --arg level "$level" \
        '.instance_level[$level].instance_cores_per_slot // empty' \
        "$RESOURCES_FILE")
    instance_gpus_per_slot=$(jq -r --arg level "$level" \
        '.instance_level[$level].instance_gpus_per_slot // empty' \
        "$RESOURCES_FILE")

    # jobid of the current instance (level)
    current_job_id=$(flux getattr jobid)
    current_job_path=""

    # and the parent instance already written to the _hierarchy.json 
    previous_level=$((level - 1))
    child_job_path=$(
        jq -r \
            --arg level "$previous_level" \
            '.instance_level[$level].job_instance_path // empty' \
            <<< "$HIERARCHY_JSON"
    )

    if [[ "$level" -eq 1 ]]; then
        echo "Creating parent instance..."
        # --bg keeps the allocation alive:
        #   flux alloc returns the job ID as soon as the subinstance is ready
        #   to accept jobs. The broker remains alive without an initial program
        #   until it reaches its time limit, is canceled, or is shut down with
        #   `flux shutdown`.

        if [[ "$cpu_affinity" == "true" ]]; then
            alloc_job_id=$(flux alloc \
                                --bg \
                                --output="${AFFINITY_FILE}-${level}.out" \
                                --error="${AFFINITY_FILE}-${level}.err" \
                                -o cpu-affinity=verbose,on \
                                --nodes="$instance_nodes" \
                                --nslots="$instance_nslots" \
                                --cores-per-slot="$instance_cores_per_slot" \
                                --gpus-per-slot="$instance_gpus_per_slot")
        else
            alloc_job_id=$(flux alloc \
                                --bg \
                                --nodes="$instance_nodes" \
                                --nslots="$instance_nslots" \
                                --cores-per-slot="$instance_cores_per_slot" \
                                --gpus-per-slot="$instance_gpus_per_slot")
        fi

        
        # construct the correct job id needed for flux proxy:
        # https://flux-framework.readthedocs.io/projects/flux-core/en/latest/man1/flux-proxy.html
        current_job_path="jobid:$alloc_job_id"
        current_job_id="$alloc_job_id"

    elif [[ "$level" -gt 1 ]]; then
        #this needs tobe done in the child instance, so we proxy into it
        echo "Creating child instances..."
        
        if [[ "$cpu_affinity" == "true" ]]; then
            alloc_job_id=$(flux proxy "$child_job_path" \
                            flux alloc \
                                --bg \
                                --output="${AFFINITY_FILE}-${level}.out" \
                                --error="${AFFINITY_FILE}-${level}.err" \
                                -o cpu-affinity=verbose,on \
                                --nodes="$instance_nodes" \
                                --nslots="$instance_nslots" \
                                --cores-per-slot="$instance_cores_per_slot" \
                                --gpus-per-slot="$instance_gpus_per_slot")
        else

            alloc_job_id=$(flux proxy "$child_job_path" \
                                flux alloc \
                                    --bg \
                                    --nodes="$instance_nodes" \
                                    --nslots="$instance_nslots" \
                                    --cores-per-slot="$instance_cores_per_slot" \
                                    --gpus-per-slot="$instance_gpus_per_slot")
        fi
            
        # construct the correct job id needed for flux proxy:                        
        current_job_path="$child_job_path/$alloc_job_id"
        current_job_id="$alloc_job_id"
    fi
    
    # ----------------------------------------------------------
    # Read scheduler configuration
    instance=$(jq -r --arg level "$level" \
        '.instance_level[$level]' \
        "$CONFIG_FILE")
    match_policy=$(jq -r '.match_policy' <<< "$instance")
    queue_policy=$(jq -r '.queue_policy' <<< "$instance")
    queue_depth=$(jq -r '.queue_depth' <<< "$instance")
    reservation_depth=$(jq -r '.reservation_depth' <<< "$instance")
    
    # n_jobs, if not available no submission to that level
    n_jobs=$(jq -r '.n_jobs // empty' <<< "$instance")
    if [[ -z "$n_jobs" ]]; then
        submission=false
    else
        submission=true
    fi

    # ----------------------------------------------------------
    # Configure Flux instance (ORDER MATTERS!!!)
    # We can not proxy into the current instance (the root instance level 0)
    if [[ "$level" -eq 0 ]]; then
        # the root is set as well.
        flux module unload sched-fluxion-qmanager
        flux module unload sched-fluxion-resource
        flux module load sched-fluxion-resource match-policy="$match_policy"
        flux module load sched-fluxion-qmanager \
            queue-policy="$queue_policy" \
            policy-params=reservation-depth="$reservation_depth",queue-depth="$queue_depth"
    else
        flux proxy "$current_job_path" \
            flux module unload sched-fluxion-qmanager
        flux proxy "$current_job_path" \
            flux module unload sched-fluxion-resource

        flux proxy "$current_job_path" \
            flux module load sched-fluxion-resource \
            match-policy="$match_policy"

        flux proxy "$current_job_path" \
            flux module load sched-fluxion-qmanager \
                queue-policy="$queue_policy" \
                policy-params=reservation-depth="$reservation_depth",queue-depth="$queue_depth"
    fi

    # ----------------------------------------------------------
    # Store hierarchy information (in memory)
    if [[ "$level" -eq 0 ]]; then
        HIERARCHY_JSON=$(
            jq \
                --arg level "$level" \
                --arg jobid "$current_job_id" \
                --arg jobid_path "$current_job_path" \
                --arg submission "$submission" \
                --arg instance_nodes "$instance_nodes" \
                --arg mp "$match_policy" \
                --arg qp "$queue_policy" \
                --arg qd "$queue_depth" \
                --arg rd "$reservation_depth" \
                '
                .instance_level[$level] = {
                    job_instance_id: $jobid,
                    job_instance_path: $jobid_path,
                    submission: $submission,
                    instance_nodes: $instance_nodes,
                    match_policy: $mp,
                    queue_policy: $qp,
                    queue_depth: $qd,
                    reservation_depth: $rd
                }
                ' <<< "$HIERARCHY_JSON"
        )
    else
        HIERARCHY_JSON=$(
            jq \
                --arg level "$level" \
                --arg jobid "$current_job_id" \
                --arg jobid_path "$current_job_path" \
                --arg submission "$submission" \
                --arg instance_nodes "$instance_nodes" \
                --arg instance_nslots "$instance_nslots" \
                --arg instance_cores_per_slot "$instance_cores_per_slot" \
                --arg instance_gpus_per_slot "$instance_gpus_per_slot" \
                --arg mp "$match_policy" \
                --arg qp "$queue_policy" \
                --arg qd "$queue_depth" \
                --arg rd "$reservation_depth" \
                '
                .instance_level[$level] = {
                    job_instance_id: $jobid,
                    job_instance_path: $jobid_path,
                    submission: $submission,
                    instance_nodes: $instance_nodes,
                    instance_slots: $instance_nslots,
                    instance_cores_per_slot: $instance_cores_per_slot,
                    instance_gpus_per_slot: $instance_gpus_per_slot,
                    match_policy: $mp,
                    queue_policy: $qp,
                    queue_depth: $qd,
                    reservation_depth: $rd
                }
                ' <<< "$HIERARCHY_JSON"
        )
    fi

    echo "Level $level created and configured."

done

# -----------------------------------------------------------------------------
# Write hierarchy.json once
printf '%s\n' "$HIERARCHY_JSON" | jq . > "$HIERARCHY_FILE"

echo "Hierarchy written to: $HIERARCHY_FILE"
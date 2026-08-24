#!/usr/bin/env python3

from pathlib import Path
import pandas as pd
import shutil
from numpy import inf
import json
import subprocess

import argparse

# arguments parsing, just the experiment folder
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('experiment_root')
parser.add_argument('vast_root')
parser.add_argument('computing_cluster')
parser.add_argument('workflow_path')
args = parser.parse_args()

experiment_root = args.experiment_root
vast_root = args.vast_root
computing_cluster = args.computing_cluster
workflow_path = args.workflow_path

experiment_dir = Path(experiment_root) / computing_cluster 
bulkjob_dir = Path(experiment_dir) / 'bulkjobs'

# -----------------------------------------------------------------------------
# Table with experiment sets
overview = pd.read_csv(experiment_dir / 'experiments_overview.csv')

# -----------------------------------------------------------------------------
# Iterate over the experiment sets
for _, experiment in overview.iterrows():

    # folder names
    experiment_type = experiment['experiment']
    computing_cluster = experiment['computing_cluster']

    table_file = Path(experiment_root) / computing_cluster / experiment_type / 'experiments_table.csv'

    # read the experiments table
    table = pd.read_csv(table_file)

    # -----------------------------------------------------------------------------
    # iterate over each experiment, one per row
    for _, row in table.iterrows():

        hash_ = row['hash']
        rep = row['rep']
        experiment_subdir = row['experiment_subdir']

        experiment_dir = Path(vast_root) / experiment_subdir / f'{hash_}_{rep}'
        success_file = experiment_dir / 'finished.log'

        # already completed?
        if success_file.exists():
            continue

        # read the hashed value --> the experiment ID & experimental folder
        shutil.rmtree(experiment_dir, ignore_errors=True)
        experiment_dir.mkdir(exist_ok=True)

        # create the result and config files variables
        config_file = experiment_dir / '_config.json'
        system_resources_file = experiment_dir / '_system_resources.json'
        instance_resources_file = experiment_dir / '_instance_resources.json'
        agg_resource_file = experiment_dir / '_agg_instance_resources.json'

        # read the configuration column
        cfg = json.loads(row['config'])

        # write the configuration to a file
        with open(config_file, 'w') as f:
            json.dump(cfg.get('config'), f, indent=4) 

        # write the system resources to a file
        with open(system_resources_file, 'w') as f:
            json.dump(cfg.get('system'), f, indent=4)

        # -----------------------------------------------------------------------------
        # Create the aggregated resources file
        # Iterate thought the keys of cfg backwards, and sum the values for: nodes
        agg_resources = {'instance_level': {}}

        # get system resources
        system_nodes = cfg.get('system', {}).get('sys_nodes', 1)
        max_cores_per_node = cfg.get('system', {}).get('max_cores_per_node', 1)
        max_gpus_per_node = cfg.get('system', {}).get('max_gpus_per_node', 1)

        # Lowest level in the instance hierarchy
        LOWEST_LEVEL = max(int(level) for level in cfg['config']['instance_level'])
        SUBMITTING_LEVELS = 0
        for level in cfg['config']['instance_level']:
            SUBMITTING_LEVELS += 1 if cfg['config']['instance_level'].get(str(level), {}).get('n_jobs', 0) > 0 else 0
                
        for level in range(LOWEST_LEVEL, 0, -1):

            # Create dictionary for this level
            agg_resources['instance_level'][str(level)] = {}

            instance = cfg['config']['instance_level'].get(str(level), {})
            child = agg_resources['instance_level'].get(str(level + 1), {})

            # For the flux alloccations (flux alloc) we need for each level:
                # instance_nodes
                # instance_slots
                # instance_cores_per_slot
                # instance_gpus_per_slot
            # As it is hierarchical, we need to aggregate the resources from the child levels.
            # Nodes, cores, gpus:
                # For physical resources, summing is not the correct approach, as they should be scattered across the hierarchy.
                # So its rather taking the max to fulfill the workload job requirements.
                # If the variable was not specified in the experiments, use the values from job requests.
                # If the variable was not specified in the job requests, use 1

            # Nodes:
            agg_resources['instance_level'][str(level)]['instance_nodes'] = max(
                instance.get('instance_nodes', instance.get('job_request_nodes', 1)),
                child.get('instance_nodes', 0)
            )
            # Cores:
            agg_resources['instance_level'][str(level)]['instance_cores_per_slot'] = max(
                instance.get('instance_cores_per_slot', instance.get('job_request_cores_per_task', 1)),
                child.get('instance_cores_per_slot', 0)
            )
            # GPUs:
            agg_resources['instance_level'][str(level)]['instance_gpus_per_slot'] = max(
                instance.get('instance_gpus_per_slot', instance.get('job_request_gpus_per_task', 0)),
                child.get('instance_gpus_per_slot', 0)
            )

            # Slots:
                # For slots, we can sum them up as they represent the total available slots at each level.
                # But they should match the physical possibilities.

            # Compute the total number of slots available at each level.
            # Driven by the number of cores or gpus available on all nodes, and the number of levels.
            # If no gpus requested, we use the number of cores instead.
            # Examples:
            #   - If we have 1 node requested with 112 cores on a system node, and each job requires 2 cores, 
            #       we can run 56 slots.
            #   - But this is for the total system, if we have two brokers running, its half = 28.
            #   - If the system resources double, this doubles as well. 
            #   - If the requested nodes per instance double, this halves, but is distributed among more nodes.

            # The number of 'physical' slots available at each level.
            cpu_slots = ( (max_cores_per_node * system_nodes) // ( 
                        instance.get('job_request_nodes', 1) *
                        instance.get('job_request_ntasks_per_node', 1) *
                        instance.get('job_request_cores_per_task', 1))
            )
            # Set to 'inf' if not set by user
            try:
                gpus_slots = ( (max_gpus_per_node * system_nodes) // ( 
                            instance.get('job_request_nodes', 1) *
                            instance.get('job_request_ntasks_per_node', 1) *
                            instance.get('job_request_gpus_per_task', 0))
                ) 
            except ZeroDivisionError:
                gpus_slots = float('inf')

            # physical possible slots
            default_instance_slots = min(cpu_slots, gpus_slots)

            # Does this level submit jobs. 
            submits = "n_jobs" in instance

            if submits:
                # Either user set value or computed one
                # If computed, devide by the number of levels that submit
                # Because the slots are distributed among the submitting levels.
                own_slots = instance.get(
                    "instance_slots",
                    default_instance_slots // SUBMITTING_LEVELS, 
                )
            else:
                own_slots = 0

            # Aggregate for that level if not set by user in the experiment
            agg_resources['instance_level'][str(level)]['instance_slots'] = (
                own_slots + child.get('instance_slots', 0)
            )

        # Add level 0 (root, not aggregated but from system resources)    
        agg_resources['instance_level']['0'] = {
            'instance_nodes': system_nodes,
        }

        # reorder before dumping
        agg_resources['instance_level'] = dict(
            sorted(
                agg_resources['instance_level'].items(),
                key=lambda item: int(item[0])
            )
        )

        # write the aggregated resources to a file
        with open(agg_resource_file, 'w') as f:
            json.dump(agg_resources, f, indent=4)

        # -----------------------------------------------------------------------------
        # Call the workload submission script
        # it can't be checked if retrn i s0 or 1 for succesfull experiments
        # as the submission to Slurm/Flux might be successfull,
        subprocess.run(
            [
                str(Path(workflow_path) / 'submit_experiment.sh'),
                str(experiment_dir),
                str(hash_)
            ],
        )

print('Experiment loop done: All experiments submitted.')
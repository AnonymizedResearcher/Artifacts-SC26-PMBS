#!/usr/bin/env python3

# Script to generate the configuration of all experiments
import itertools
from pathlib import Path
import pandas as pd
import sys
import json
import hashlib

from importlib.util import spec_from_file_location, module_from_spec

# arguments parsing, just the experiment folder
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('experiment_root')
parser.add_argument('computing_cluster')
parser.add_argument('experiment')
args = parser.parse_args()

experiment_root = args.experiment_root
computing_cluster = args.computing_cluster
experiment = args.experiment

experiment_dir = Path(experiment_root) / computing_cluster / experiment

# output files
experiment_table_file = experiment_dir / 'experiments_table.csv'
overview_file = Path(experiment_root) / computing_cluster / 'experiments_overview.csv'

# --------------------------------------------------
# Source the factors file
doe_file = experiment_dir / 'doe.py'
spec = spec_from_file_location('doe', doe_file)
module = module_from_spec(spec)
spec.loader.exec_module(module)

# --------------------------------------------------
# Access the factors
system = module.system
instances = module.instances
repetitions = module.repetitions

# --------------------------------------------------
# Generate experiments: Cartesian product of instances
rows = []
for assignment in itertools.product(*instances):

    for rep in range(1, repetitions + 1):

        config = {
            'system': system,
            'config': {
                'instance_level': {}
            }
        }
    
        for level, cfg in enumerate(assignment):
            config['config']['instance_level'][str(level)] = cfg

        # Enforce some restircition
        # -------------------------
        # 1. for multilevel we restrict some parameters must be the same across all levels
            # otherwise the slot to cores aggregation across levels will not work, as the slot to cores mapping is not unique
            # same with GPUs
            # with workloads it would work, but we want to have them similar now
            # As the workloads have some variation in execution, they are not perfectly homogenous
        valid = True

        same_across_levels = [
            'workload',
            'problem_class',
            'job_request_nodes',
            'job_request_ntasks_per_node',            
            'job_request_cores_per_task',
            'job_request_gpus_per_task',
            'job_request_time'
        ]

        for parameter in same_across_levels:
            values = [
                cfg[parameter]
                for cfg in config['config']['instance_level'].values()
                if parameter in cfg
            ]

            if len(set(values)) > 1:
                valid = False
                break

        if not valid:
            continue

        # all restrictions are satisfied, we can add this configuration to the list of experiments
        # Make a string, use only the config[config], the affinity, and the  experiment system nodes.
        # the rest is fixed and the experiments are distinguish in different dane, and tuo direcotries
        # the time limit for an experiment is for execution only and can be set higher for the workload ones.
        hash_config = {
            'config': config['config'],
            'sys_nodes': system['sys_nodes'],
            'cpu_affinity': system['cpu_affinity'],
        }

        hash_string = json.dumps(hash_config, sort_keys=True)
        hash_value = hashlib.sha1(hash_string.encode()).hexdigest()[:10]

        rows.append({
            'hash': hash_value,
            'config': json.dumps(config, sort_keys=True),
            'rep': rep,
            'experiment_subdir': f'{computing_cluster}/{experiment}',
        })

# --------------------------------------------------
# DataFrame
df = pd.DataFrame(rows)

# --------------------------------------------------
# Export
df.to_csv(experiment_table_file, index=False)

# --------------------------------------------------
# Write the number of experiments into a csv file
# Number of generated experiments
n_experiments = len(df)

# Read existing overview
try:
    overview = pd.read_csv(overview_file)
except FileNotFoundError:
    overview = pd.DataFrame(columns=['computing_cluster', 'experiment', 'n_experiments'])

# Replace existing entry or append a new one
overview = overview[overview['experiment'] != experiment]
overview.loc[len(overview)] = {
    'computing_cluster': computing_cluster,
    'experiment': experiment,    
    'n_experiments': n_experiments,
}

# Save
overview.to_csv(overview_file, index=False)
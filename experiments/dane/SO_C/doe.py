#!/usr/bin/env python3
import itertools

# Here you set all the parameters for your experiments
# 1. It will genereat all possible combinations within an instance 
# 2. It will generate all possible combinations across all instances.
# Rules:
    # 1. Every level (also root) can be configured
    # 2. Every level but root can receive workloads.
    # 3. A level can be configured, but no workload can be submitted at that level.
    # 4. If a level is not configured {}, it will be skipped.
    # 5. If a level is configured, but any parent level is not configured, an error will be raised.

# --------------------------------------------------
# Hardware for this experiment, i.e., for all jobs on all hierarchy levels
system = {
    # 'queue': 'pdebug',
    'queue': 'pbatch',
    'slurm_time_limit': '00:03:00',  
    'flux_time_limit': '3m',  # on a flux managed system something like 0.5h=30m=1800s
    'sys_nodes': 1,
    'max_cores_per_node': 112,
    'max_gpus_per_node': 0,
    'cpu_affinity': True,    
    # # if the slots should be dirstibuted evenly across all nodes, if False, sum of instance_nodes will be used 
    # 'instance_node_dist_uniform': True,  
}

# For later, maybe change this and include submission = {}
# Then add submission to each instance submission_level_0 and so on

# --------------------------------------------------
# Level 0 (root) parameter space: The default values
# Used by flux
instance_level_0 = {
    'match_policy': ['first'],    
    'queue_policy': ['fcfs'],
    'queue_depth': [32], # 32 is the default, but setting it shows it in the config
    'reservation_depth': [64], # 64 is the default, but setting it shows it in the config   
}

# --------------------------------------------------
# Level 1 parameter space
instance_level_1 = {
    'match_policy': ['first', 'low'],   
    # 'match_policy': ['first'],   
    # 'match_policy': ['first', 'low', 'high', 'locality'],   
    'queue_policy': ['fcfs', 'hybrid'],
    # 'queue_policy': ['fcfs', 'easy', 'conservative', 'hybrid'],
    'queue_depth': [32], # 32 is the default, but setting it shows it in the config
    'reservation_depth': [64], # 64 is the default, but setting it shows it in the config   
    # 'n_jobs': [5],
    # 'workload': ['sleep','babelstream','raja-perf%Polybench_GEMM%Base_OpenMP'],
    # 'workload': ['sleep'],
    # 'problem_class': ['A'], # A, B, C
    # 'job_request_time': ['30s'],  # on a flux managed system something like 0.5h=30m=1800s
    # 'job_request_nodes': [1],
    # 'job_request_ntasks_per_node': [1],
    # 'job_request_cores_per_task': [2], # What a job requests in terms of resources, is needed for the flux bulksubmit for each job, as well as for the flux alloc instantiation
    # 'job_request_gpus_per_task': [0],    
}

# --------------------------------------------------
# Level 2 parameter space
instance_level_2 = {
    # # The following arguments specify how the instance is partitioned among the system nodes
    # # 1. either each instance has its own nodes --> sys_nodes=sum(instance_nodes),
    # # or they share nodes --> sys_nodes=instance_nodes
    # 'instance_nodes': [1],
    # # 2. the idea is, to use as many slot as possible for each slot to be big enough to hold a job
    # # Job requests (job_request_ntasks * job_request_cores_per_task), systam has max_cores_per_node cores
    # # evenly distributed = (max_cores_per_node) / nr_instances / (cores_per_job * ntasks_per_job)
    # 'instance_slots': [14],
    'match_policy': ['first', 'low'],   
    # 'match_policy': ['first'],   
    # 'match_policy': ['first', 'low', 'high', 'locality'],   
    'queue_policy': ['fcfs', 'hybrid'],
    # 'queue_policy': ['fcfs', 'easy', 'conservative', 'hybrid'],
    'queue_depth': [32], # 32 is the default, but setting it shows it in the config
    'reservation_depth': [64], # 64 is the default, but setting it shows it in the config
    # 'n_jobs': [500],
    'n_jobs': [1000],
    # 'workload': ['sleep','babelstream','raja-perf%Polybench_GEMM%Base_OpenMP'],
    'workload': ['sleep'],
    'problem_class': ['A'], # A, B, C
    'job_request_time': ['30s'],  # on a flux managed system something like 0.5h=30m=1800s
    'job_request_nodes': [1],
    'job_request_ntasks_per_node': [1],
    'job_request_cores_per_task': [
        1,      # single core
        # 2,
        # 4,
        # 7,      # half NUMA
        14,     # one NUMA domain
        # 28,     # two NUMA domains
        # 56,     # half node
        # 112     # full node
    ], # What a job requests in terms of resources, is needed for the flux bulksubmit for each job, as well as for the flux alloc instantiation
    'job_request_gpus_per_task': [0],
}

# --------------------------------------------------
# Level 3 parameter space
instance_level_3 = {}

# --------------------------------------------------
# Level 4 parameter space
instance_level_4 = {}

# --------------------------------------------------
# Cartesian product for each instance parameters
instances = []
levels = [
    instance_level_0,
    instance_level_1,
    instance_level_2,
    instance_level_3,
    instance_level_4,
]
seen_empty = False

for level, instance in enumerate(levels):

    # if no parameters are specified for this level, we mark it as empty
    if not instance:
        seen_empty = True
        continue
    # if there is one configured, but any parent was empty already --> Error
    elif seen_empty:
        raise ValueError(
            f"Level {level} is configured, but a parent level is missing."
        )

    keys = list(instance.keys())

    configs = [
        dict(zip(keys, values))
        for values in itertools.product(*instance.values())
    ]

    instances.append(configs)

# --------------------------------------------------
# Repetitions
repetitions = 5
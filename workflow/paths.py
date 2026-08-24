from pathlib import Path
import os

# arguments parsing, just the experiment folder
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("experiment_type")
args = parser.parse_args()
EXPERIMENT_TYPE = args.experiment_type

HOME = Path.home()

# Workflow pipeline dir
WORKFLOW_ROOT = HOME / "Artifacts-SC26-PMBS" / "workflow"
# Workloads
WORKLOADS_ROOT = HOME / "Artifacts-SC26-PMBS" / "workloads"
# Experiment dir
EXPERIMENT_ROOT = HOME / "Artifacts-SC26-PMBS" / EXPERIMENT_TYPE
USER_NAME = HOME.name
# Result parallel file system dir
VAST_ROOT = HOME / "Artifacts-SC26-PMBS" / EXPERIMENT_TYPE

from paths import *

with open(f"{WORKFLOW_ROOT}/paths.sh", "w") as f:
    f.write(f'export WORKFLOW_ROOT="{WORKFLOW_ROOT}"\n')
    f.write(f'export WORKLOADS_ROOT="{WORKLOADS_ROOT}"\n')
    f.write(f'export EXPERIMENT_ROOT="{EXPERIMENT_ROOT}"\n')
    f.write(f'export VAST_ROOT="{VAST_ROOT}"\n')
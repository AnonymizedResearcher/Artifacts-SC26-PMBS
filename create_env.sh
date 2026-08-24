#!/bin/bash

# Paths (Adapt to your needs)
cd /usr/workspace/$USER
mkdir -p local/$SYS_TYPE
cd local/$SYS_TYPE

# Install miniforge
if [[ ! -x "$PWD/miniforge3/bin/conda" ]]; then
    curl -LO https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
    bash Miniforge3-Linux-x86_64.sh -b -p "$PWD/miniforge3"
else
    echo "Miniforge already installed at $PWD/miniforge3"
fi

# Create environment
source "$PWD/miniforge3/bin/activate"
conda env create -f $HOME/Artifacts-SC26-PMBS/conda_envs/plotting.yaml

# Activate
source /usr/workspace/$USER/local/$SYS_TYPE/miniforge3/bin/activate
conda activate plotting
# source of benchpark
cd $HOME/Artifacts-SC26-PMBS/benchpark
. setup-env.sh

# init the system
benchpark list systems
# Systems - SYSTEM_DEFINITION CLUSTER/INSTANCE
#     aws-pcluster instance_type=[c6g.xlarge|c4.xlarge|hpc7a.48xlarge|hpc6a.48xlarge]
#     aws-tutorial instance_type=[c7i.48xlarge|c7i.metal-48xl|c7i.24xlarge|c7i.metal-24xl|c7i.12xlarge]
#     csc-lumi
#     cscs-daint
#     cscs-eiger
#     fluxtainer
#     generic-x86
#     jsc-juwels
#     lanl-rocinante cluster=[rocinante|tycho|crossroads]
#     lanl-venado cluster=[grace-hopper|grace-grace]
#     lbnl-perlmutter
#     llnl-cluster cluster=[magma|dane|rzgenie|ruby-deprecated|poodle-deprecated]
#     llnl-elcapitan cluster=[tioga|elcapitan|tuolumne]
#     llnl-matrix
#     llnl-sierra-deprecated
#     olcf-frontier cluster=[frontier]
#     riken-dgx
#     riken-fugaku
#     riken-fx700
#     riken-genoa
#     riken-gh200
#     snl-eldorado

# this needs to be run once for each system only
benchpark system init --dest=dane llnl-cluster cluster=dane
benchpark system init --dest=tuolumne llnl-elcapitan cluster=tuolumne


# init the experiment
benchpark list experiments
# Experiments - BENCHMARK+PROGRAMMING_MODEL+SCALING
#     ad+[mpi]
#     amg2023+[openmp|cuda|rocm|mpi]+[strong|weak|throughput]
#     babelstream+[openmp|cuda|rocm]
#     branson+[openmp|cuda|rocm|mpi]+[strong|weak|throughput]
#     commbench+[cuda|rocm]
#     genesis+[openmp|mpi]
#     gpcnet+[mpi]
#     gromacs+[openmp|cuda|rocm|mpi]
#     hpcg+[openmp|mpi]+[strong|weak]
#     hpl+[openmp|mpi]+[strong|weak]
#     ior+[mpi]+[strong|weak]
#     kripke+[openmp|cuda|rocm|mpi]+[strong|weak|throughput]
#     laghos+[cuda|rocm|mpi]+[strong|weak|throughput]
#     lammps+[openmp|cuda|rocm|mpi]+[strong]
#     md-test+[mpi]+[strong]
#     osu-micro-benchmarks+[cuda|rocm|mpi]+[strong|throughput]
#     phloem+[mpi]
#     py-scaffold+[cuda|rocm]+[strong|weak]
#     quicksilver+[openmp|mpi]+[strong|weak]
#     qws+[openmp|mpi]+[strong|weak|throughput]
#     raja-perf+[openmp|cuda|rocm|mpi]+[strong|weak|throughput]
#     remhos+[cuda|rocm|mpi]+[strong|weak|throughput]
#     salmon-tddft+[openmp|mpi]
#     smb+[mpi]
#     sparta-snl+[openmp|cuda|rocm|mpi]
#     stream+[mpi]
#     test
benchpark experiment init --dest=babelstream dane babelstream+openmp
# example for raja-perf and tuolumne
# benchpark experiment init --dest=raja-perf tuolumne raja-perf+rocm

# create the folder and the tools for benchpark:
benchpark setup dane/babelstream  $HOME/Artifacts-SC26-PMBS/workloads/dane/babelstream

# activate the environment
. $HOME/Artifacts-SC26-PMBS/workloads/dane/babelstream/setup.sh

# setup the workspace
ramble --workspace-dir \
    $HOME/Artifacts-SC26-PMBS/workloads/dane/babelstream/dane/babelstream/workspace \
    workspace setup
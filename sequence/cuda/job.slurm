#!/bin/bash
#SBATCH --job-name=CUDA_MPI
#SBATCH --output=out.%N
#SBATCH --error=err.%N
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --gpus=1
#SBATCH --export=ALL

mpiexec ./align_m_c 10000 0.35 0.2 0.25 0 0 0 10000 9000 9000 50 100 M 4353435

#!/bin/bash
#SBATCH --job-name=test_job
#SBATCH --output=job_output.txt
#SBATCH --error=job_error.txt
#SBATCH --ntasks=16
#SBATCH --cpus-per-task=1
#SBATCH --gres=gpu:1

mpirun ./align_m_c 1000 0.35 0.2 0.25 0 0 0 20000 10 0 500 0 M 4353435

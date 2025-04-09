#!/bin/bash
#SBATCH --job-name=test_job
#SBATCH --output=job_output.txt
#SBATCH --error=job_error.txt
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --gres=gpu:1

mpirun ./align_m_c 100000 0.35 0.2 0.25 0 0 0 100000 9000 9000 50 100 M 4353435

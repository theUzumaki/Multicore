#!/bin/bash
#SBATCH --job-name=test_job
#SBATCH --output=job_output.txt
#SBATCH --error=job_error.txt
#SBATCH --ntasks-per-node=2
#SBATCH --gres=gpu:2
#SBATCH --cpus-per-task=1

mpirun --allow-run-as-root ./align_m_c 10000 0.35 0.2 0.25 0 0 0 1000000 9000 9000 50 100 M 4353435

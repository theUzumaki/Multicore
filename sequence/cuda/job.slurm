#!/bin/bash
#SBATCH --job-name=test_job
#SBATCH --output=job_output.txt
#SBATCH --error=job_error.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1

srun ./align_m_c 300 0.1 0.3 0.35 100 5 5 300 150 50 150 80 M 609823

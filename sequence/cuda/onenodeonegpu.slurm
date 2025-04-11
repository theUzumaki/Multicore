#!/bin/bash
#SBATCH --job-name=test_job
#SBATCH --output=job_output.txt
#SBATCH --error=job_error.txt
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=1

echo "Running on: $SLURM_JOB_NODELIST"
echo "Total tasks: $SLURM_NTASKS"

srun ./align_m_c 1000000 0.35 0.2 0.25 0 0 0 10000 9000 9000 50 100 M 4353435

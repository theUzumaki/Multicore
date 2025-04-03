rm -f align_m_c
nvcc -Xptxas -v -arch=sm_75 align_cuda2.cu -o align_m_c -I/usr/lib/x86_64-linux-gnu/openmpi/include -L/usr/lib/x86_64-linux-gnu/openmpi/lib -lmpi
sbatch job.slurm
squeue -u $USER

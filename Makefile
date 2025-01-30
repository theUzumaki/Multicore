all:
	nvcc -arch=sm_75 sequence/align_mpi_cuda.cu -o align_m_c -I/usr/lib/x86_64-linux-gnu/openmpi/include -L/usr/lib/x86_64-linux-gnu/openmpi/lib -lmpi
	mv align_m_c logs/

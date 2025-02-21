all:
	rm -f ~/Multicore/logs/align_m_c
	nvcc -Xptxas -v -arch=sm_75 ~/Multicore/sequence/align_cuda2.cu -o ~/Multicore/logs/align_m_c -I/usr/lib/x86_64-linux-gnu/openmpi/include -L/usr/lib/x86_64-linux-gnu/openmpi/lib -lmpi
	condor_submit ~/Multicore/logs/job.job
	condor_q

all:
        rm -f align_m_c
        nvcc -Xptxas -v -arch=sm_75 align_cuda2.cu -o align_m_c -I/usr/lib/x86_64-linux-gnu/openmpi/include -L/usr/lib/x86_64-linux-gnu/openmpi/lib -lmpi
	./align_m_c 10000 0.35 0.2 0.25 0 0 0 10000 9000 9000 50 100 M 4353435

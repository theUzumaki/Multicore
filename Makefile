all:
	make all -f sequence/Makefile
	mv sequence/align_mpi logs/

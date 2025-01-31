#include <mpi.h>
#include <cuda_runtime.h>
#include <iostream>

__global__ void kernel() {
    printf("Hello from GPU thread %d\n", threadIdx.x);
}

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int world_size, world_rank;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    if (world_rank == 0) {
        std::cout << "Hello from MPI process " << world_rank << " of " << world_size << std::endl;
    }

    kernel<<<1, 10>>>();
    cudaDeviceSynchronize();

    MPI_Finalize();
    return 0;
}
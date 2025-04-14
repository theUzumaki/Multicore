/*
 * Exact genetic sequence alignment
 * (Using brute force)
 *
 * CUDA version
 *
 * Computacion Paralela, Grado en Informatica (Universidad de Valladolid)
 * 2023/2024
 *
 * v1.3
 *
 * (c) 2024, Arturo Gonzalez-Escribano
 */
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<limits.h>
#include<sys/time.h>
#include<mpi.h>

/* Headers for the CUDA assignment versions */
#include<cuda.h>

/* Example of macros for error checking in CUDA */
#define CUDA_CHECK_FUNCTION( call )	{ cudaError_t check = call; if ( check != cudaSuccess ) fprintf(stderr, "CUDA Error in line: %d, %s\n", __LINE__, cudaGetErrorString(check) ); }
#define CUDA_CHECK_KERNEL( )	{ cudaError_t check = cudaGetLastError(); if ( check != cudaSuccess ) fprintf(stderr, "CUDA Kernel Error in line: %d, %s\n", __LINE__, cudaGetErrorString(check) ); }

/* Arbitrary value to indicate that no matches are found */
#define	NOT_FOUND	-1

/* Arbitrary value to restrict the checksums period */
#define CHECKSUM_MAX	65535


/* 
 * Utils: Function to get wall time
 */
double cp_Wtime(){
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec + 1.0e-6 * tv.tv_usec;
}

/*
 * Utils: Random generator
 */
#include "rng.c"


/*
 *
 * START HERE: DO NOT CHANGE THE CODE ABOVE THIS POINT
 * DO NOT USE OpenMP IN YOUR CODE
 *
 */

/* ADD KERNELS AND OTHER FUNCTIONS HERE */
__global__ void search_patterns(char *d_sequence, char **d_pattern, unsigned long *d_pat_length, int *d_block_pat_matches, unsigned long *d_pat_found, int *d_seq_matches, int pat_number, unsigned long seq_length) {
	int pat = blockIdx.x * blockDim.x + threadIdx.x;
	extern __shared__ int all_matches[];

	if (threadIdx.x < blockDim.x) {
		all_matches[threadIdx.x] = 0;
	}
	__syncthreads();
	if (pat >= pat_number) return;

	unsigned long start, lind;
	bool found = true;
	unsigned long length = d_pat_length[pat];

	for (start = 0; start <= seq_length - length; start++) {
		found = true;

		for (lind = 0; lind < length; lind++) {
			if (d_sequence[start + lind] != d_pattern[pat][lind]) {
				found = false;
				break;
			}
		}

		if (found) {
			all_matches[threadIdx.x] = 1;
			d_pat_found[pat] = start + 1;
			for (lind = 0; lind < length; lind++) {
				atomicAdd(&d_seq_matches[start + lind], 1);
			}
			break;
		}
	}
	__syncthreads();

	int red_length = blockDim.x;
	for (int stride = (blockDim.x + 1) / 2; stride > 0; stride = ( stride + 1 ) / 2) {
		if (threadIdx.x + stride < red_length) {
			all_matches[threadIdx.x] += all_matches[threadIdx.x + stride];
		}
		red_length = stride;
		if (stride == 1) {
			break;
		}
		__syncthreads();
	}

	if (threadIdx.x == 0) {
		d_block_pat_matches[blockIdx.x] = all_matches[0];
	}
}

__global__ void partial_reduce(int *d_block_pat_matches, int *d_total_matches, int length) {
	extern __shared__ int all_matches[];

	int tid = threadIdx.x;
	int global_idx = blockIdx.x * blockDim.x + tid;
	int upper_limit = length - blockDim.x * blockIdx.x;
	if (tid == 0) {
		printf("BLOCK NUMBER %d has upper_limit = %d\n", blockIdx.x, upper_limit);
	}
	if (global_idx < length) {
		if (blockIdx.x == 0) printf("BEFORE THREAD %d\n", tid);
		all_matches[tid] = d_block_pat_matches[global_idx];
		if (blockIdx.x == 0) printf("AFTER THREAD %d\n", tid);
	} else {
		all_matches[tid] = 0; // Initialize unused shared memory to avoid undefined behavior
	}
	__syncthreads();
	if (tid >= upper_limit) return;

	// Perform binary tree reduction
	int red_length = upper_limit;
	if (tid == 0) printf("BLOCK NUMBER %d has red_length = %d\n", blockIdx.x, red_length);
	for (int stride = (red_length + 1) / 2; stride > 0; stride = ( stride + 1 ) / 2) {
		if (tid == 0) {
			printf("Stride = %d, red_length = %d\n", stride, red_length);
		}
		if (tid + stride < red_length) {
			printf("all_matches[%d/%d] = %d + %d\n", tid, global_idx, all_matches[tid], all_matches[tid + stride]);
			all_matches[tid] += all_matches[tid + stride];
		}
		if (tid == 0) {
			printf("----\n");
		}
		red_length = stride;
		if (stride == 1) {
			break;
		}
		__syncthreads();
	}

	if (threadIdx.x == 0) {
		printf("COMPLETING...\n");
		printf("d_block_pat_matches[%d] = %d\n", blockIdx.x, all_matches[0]);
		d_total_matches[blockIdx.x] = all_matches[0];
	}	
}

__global__ void reduced_sum(int *d_block_pat_matches, int *d_total_matches, int length) {
    extern __shared__ int shared_data[];

    int tid = threadIdx.x;
	int global_idx = blockIdx.x * blockDim.x + tid;

	if (global_idx < length) {
		shared_data[tid] = d_block_pat_matches[global_idx];
	} else {
		shared_data[tid] = 0; // Initialize unused shared memory to avoid undefined behavior
	}
    __syncthreads();

    // Perform binary tree reduction
	int red_length = blockDim.x;
    for (int stride = (red_length + 1) / 2; stride > 0; stride = (stride + 1) / 2) {
		
        if (tid + stride < red_length) {
            shared_data[tid] += shared_data[tid + stride];
        }
		
        __syncthreads();
		red_length = stride;
		if (stride == 1) {
			break;
		}
    }

	// Write the result from thread 0 to global memory
	if (tid == 0) {
		printf("d_block_pat_matches[%d] = %d\n", blockIdx.x, shared_data[0]);
		d_total_matches[blockIdx.x] = shared_data[0];
	}
}

/*
 * Function: Increment the number of pattern matches on the sequence positions
 * 	This function can be changed and/or optimized by the students
 */
void increment_matches( int pat, unsigned long *pat_found, unsigned long *pat_length, int *seq_matches ) {
	unsigned long ind;	
	for( ind=0; ind<pat_length[pat]; ind++) {
		if ( seq_matches[ pat_found[pat] + ind ] == NOT_FOUND )
			seq_matches[ pat_found[pat] + ind ] = 0;
		else
			seq_matches[ pat_found[pat] + ind ] ++;
	}
}

/*
struct ReductionData {
	unsigned long *pat_found;
	int *seq_matches;
	int pat_matches;
	int pat_number;
	int seq_length;
};

void build_custom_struct(unsigned long *pat_found, int *seq_matches, int pat_matches, int pat_number, int seq_length, MPI_Datatype *reduction_type) {
	MPI_Aint base_address, displacements[5];
	int block_lengths[5] = {pat_number, seq_length, 1, 1, 1};
	MPI_Datatype types[5] = {MPI_UNSIGNED_LONG, MPI_INT, MPI_INT, MPI_INT, MPI_INT};

	MPI_Get_address(pat_found, &base_address);
	MPI_Get_address(pat_found, &displacements[0]);
	MPI_Get_address(seq_matches, &displacements[1]);
	MPI_Get_address(&pat_matches, &displacements[2]);
	MPI_Get_address(&pat_number, &displacements[3]);
	MPI_Get_address(&seq_length, &displacements[4]);

	displacements[0] -= base_address;
	displacements[1] -= base_address;
	displacements[2] -= base_address;
	displacements[3] -= base_address;
	displacements[4] -= base_address;

	MPI_Type_create_struct(5, block_lengths, displacements, types, reduction_type);
	MPI_Type_commit(reduction_type);
}

void custom_reduce_function(void *in, void *out, int *len, MPI_Datatype *datatype) {

	ReductionData *in_data = (ReductionData *)in;
	ReductionData *out_data = (ReductionData *)out;

	for (int j = 0; j < (*out_data).pat_number; j++) {
		(*out_data).pat_found[j] += (*in_data).pat_found[j];
	}
	
	for (int j = 0; j < (*out_data).seq_length; j++) {
		(*out_data).seq_matches[j] += (*in_data).seq_matches[j];
	}
	
	(*out_data).pat_matches += (*in_data).pat_matches;
}
*/
/*
 *
 * STOP HERE: DO NOT CHANGE THE CODE BELOW THIS POINT
 *
 */

/*
 * Function: Allocate new patttern
 */
char *pattern_allocate( rng_t *random, unsigned long pat_rng_length_mean, unsigned long pat_rng_length_dev, unsigned long seq_length, unsigned long *new_length ) {

	/* Random length */
	unsigned long length = (unsigned long)rng_next_normal( random, (double)pat_rng_length_mean, (double)pat_rng_length_dev );
	if ( length > seq_length ) length = seq_length;
	if ( length <= 0 ) length = 1;

	/* Allocate pattern */
	char *pattern = (char *)malloc( sizeof(char) * length );
	if ( pattern == NULL ) {
		fprintf(stderr,"\n-- Error allocating a pattern of size: %lu\n", length );
		exit( EXIT_FAILURE );
	}

	/* Return results */
	*new_length = length;
	return pattern;
}

/*
 * Function: Fill random sequence or pattern
 */
void generate_rng_sequence( rng_t *random, float prob_G, float prob_C, float prob_A, char *seq, unsigned long length) {
	unsigned long ind; 
	for( ind=0; ind<length; ind++ ) {
		double prob = rng_next( random );
		if( prob < prob_G ) seq[ind] = 'G';
		else if( prob < prob_C ) seq[ind] = 'C';
		else if( prob < prob_A ) seq[ind] = 'A';
		else seq[ind] = 'T';
	}
}

/*
 * Function: Copy a sample of the sequence
 */
void copy_sample_sequence( rng_t *random, char *sequence, unsigned long seq_length, unsigned long pat_samp_loc_mean, unsigned long pat_samp_loc_dev, char *pattern, unsigned long length) {
	/* Choose location */
	unsigned long  location = (unsigned long)rng_next_normal( random, (double)pat_samp_loc_mean, (double)pat_samp_loc_dev );
	if ( location > seq_length - length ) location = seq_length - length;
	if ( location <= 0 ) location = 0;

	/* Copy sample */
	unsigned long ind; 
	for( ind=0; ind<length; ind++ )
		pattern[ind] = sequence[ind+location];
}

/*
 * Function: Regenerate a sample of the sequence
 */
void generate_sample_sequence( rng_t *random, rng_t random_seq, float prob_G, float prob_C, float prob_A, unsigned long seq_length, unsigned long pat_samp_loc_mean, unsigned long pat_samp_loc_dev, char *pattern, unsigned long length ) {
	/* Choose location */
	unsigned long  location = (unsigned long)rng_next_normal( random, (double)pat_samp_loc_mean, (double)pat_samp_loc_dev );
	if ( location > seq_length - length ) location = seq_length - length;
	if ( location <= 0 ) location = 0;

	/* Regenerate sample */
	rng_t local_random = random_seq;
	rng_skip( &local_random, location );
	generate_rng_sequence( &local_random, prob_G, prob_C, prob_A, pattern, length);
}


/*
 * Function: Print usage line in stderr
 */
void show_usage( char *program_name ) {
	fprintf(stderr,"Usage: %s ", program_name );
	fprintf(stderr,"<seq_length> <prob_G> <prob_C> <prob_A> <pat_rng_num> <pat_rng_length_mean> <pat_rng_length_dev> <pat_samples_num> <pat_samp_length_mean> <pat_samp_length_dev> <pat_samp_loc_mean> <pat_samp_loc_dev> <pat_samp_mix:B[efore]|A[fter]|M[ixed]> <long_seed>\n");
	fprintf(stderr,"\n");
}



/*
 * MAIN PROGRAM
 */
int main(int argc, char *argv[]) {
	/* 0. Default output and error without buffering, forces to write immediately */
	setbuf(stdout, NULL);
	setbuf(stderr, NULL);

	/* 1. Read scenary arguments */
	/* 1.0. Init MPI before processing arguments */
	MPI_Init( &argc, &argv );
	int rank;
	MPI_Comm_rank( MPI_COMM_WORLD, &rank );
	int size;
	MPI_Comm_size(MPI_COMM_WORLD, &size);
	CUDA_CHECK_FUNCTION( cudaSetDevice( rank % 2 ) );
	
	/* 1.1. Check minimum number of arguments */
	if (argc < 15) {
		fprintf(stderr, "\n-- Error: Not enough arguments when reading configuration from the command line\n\n");
		show_usage( argv[0] );
		exit( EXIT_FAILURE );
	}

	/* 1.2. Read argument values */
	unsigned long seq_length = atol( argv[1] );
	float prob_G = atof( argv[2] );
	float prob_C = atof( argv[3] );
	float prob_A = atof( argv[4] );
	if ( prob_G + prob_C + prob_A > 1 ) {
		fprintf(stderr, "\n-- Error: The sum of G,C,A,T nucleotid probabilities cannot be higher than 1\n\n");
		show_usage( argv[0] );
		exit( EXIT_FAILURE );
	}
	prob_C += prob_G;
	prob_A += prob_C;

	int pat_rng_num = atoi( argv[5] );
	unsigned long pat_rng_length_mean = atol( argv[6] );
	unsigned long pat_rng_length_dev = atol( argv[7] );
	
	int pat_samp_num = atoi( argv[8] );
	unsigned long pat_samp_length_mean = atol( argv[9] );
	unsigned long pat_samp_length_dev = atol( argv[10] );
	unsigned long pat_samp_loc_mean = atol( argv[11] );
	unsigned long pat_samp_loc_dev = atol( argv[12] );

	char pat_samp_mix = argv[13][0];
	if ( pat_samp_mix != 'B' && pat_samp_mix != 'A' && pat_samp_mix != 'M' ) {
		fprintf(stderr, "\n-- Error: Incorrect first character of pat_samp_mix: %c\n\n", pat_samp_mix);
		show_usage( argv[0] );
		exit( EXIT_FAILURE );
	}

	unsigned long seed = atol( argv[14] );

#ifdef DEBUG
	/* DEBUG: Print arguments */
	printf("\nArguments: seq_length=%lu\n", seq_length );
	printf("Arguments: Accumulated probabilitiy G=%f, C=%f, A=%f, T=1\n", prob_G, prob_C, prob_A );
	printf("Arguments: Random patterns number=%d, length_mean=%lu, length_dev=%lu\n", pat_rng_num, pat_rng_length_mean, pat_rng_length_dev );
	printf("Arguments: Sample patterns number=%d, length_mean=%lu, length_dev=%lu, loc_mean=%lu, loc_dev=%lu\n", pat_samp_num, pat_samp_length_mean, pat_samp_length_dev, pat_samp_loc_mean, pat_samp_loc_dev );
	printf("Arguments: Type of mix: %c, Random seed: %lu\n", pat_samp_mix, seed );
	printf("\n");
#endif // DEBUG

        CUDA_CHECK_FUNCTION( cudaSetDevice(0) );

	/* 2. Initialize data structures */
	/* 2.1. Skip allocate and fill sequence */
	rng_t random = rng_new( seed );
	rng_skip( &random, seq_length );

	/* 2.2. Allocate and fill patterns */
	/* 2.2.1 Allocate main structures */
	int pat_number = pat_rng_num + pat_samp_num;
	unsigned long *pat_length = (unsigned long *)malloc( sizeof(unsigned long) * pat_number );
	char **pattern = (char **)malloc( sizeof(char*) * pat_number );
	if ( pattern == NULL || pat_length == NULL ) {
		fprintf(stderr,"\n-- Error allocating the basic patterns structures for size: %d\n", pat_number );
		exit( EXIT_FAILURE );
	}

	/* 2.2.2 Allocate and initialize ancillary structure for pattern types */
	int ind;
	unsigned long lind;
	#define PAT_TYPE_NONE	0
	#define PAT_TYPE_RNG	1
	#define PAT_TYPE_SAMP	2
	char *pat_type = (char *)malloc( sizeof(char) * pat_number );
	if ( pat_type == NULL ) {
		fprintf(stderr,"\n-- Error allocating ancillary structure for pattern of size: %d\n", pat_number );
		exit( EXIT_FAILURE );
	}
	for( ind=0; ind<pat_number; ind++ ) pat_type[ind] = PAT_TYPE_NONE;

	/* 2.2.3 Fill up pattern types using the chosen mode */
	switch( pat_samp_mix ) {
	case 'A':
		for( ind=0; ind<pat_rng_num; ind++ ) pat_type[ind] = PAT_TYPE_RNG;
		for( ; ind<pat_number; ind++ ) pat_type[ind] = PAT_TYPE_SAMP;
		break;
	case 'B':
		for( ind=0; ind<pat_samp_num; ind++ ) pat_type[ind] = PAT_TYPE_SAMP;
		for( ; ind<pat_number; ind++ ) pat_type[ind] = PAT_TYPE_RNG;
		break;
	default:
		if ( pat_rng_num == 0 ) {
			for( ind=0; ind<pat_number; ind++ ) pat_type[ind] = PAT_TYPE_SAMP;
		}
		else if ( pat_samp_num == 0 ) {
			for( ind=0; ind<pat_number; ind++ ) pat_type[ind] = PAT_TYPE_RNG;
		}
		else if ( pat_rng_num < pat_samp_num ) {
			int interval = pat_number / pat_rng_num;
			for( ind=0; ind<pat_number; ind++ ) 
				if ( (ind+1) % interval == 0 ) pat_type[ind] = PAT_TYPE_RNG;
				else pat_type[ind] = PAT_TYPE_SAMP;
		}
		else {
			int interval = pat_number / pat_samp_num;
			for( ind=0; ind<pat_number; ind++ ) 
				if ( (ind+1) % interval == 0 ) pat_type[ind] = PAT_TYPE_SAMP;
				else pat_type[ind] = PAT_TYPE_RNG;
		}
	}

	/* 2.2.4 Generate the patterns */
	for( ind=0; ind<pat_number; ind++ ) {
		if ( pat_type[ind] == PAT_TYPE_RNG ) {
			pattern[ind] = pattern_allocate( &random, pat_rng_length_mean, pat_rng_length_dev, seq_length, &pat_length[ind] );
			generate_rng_sequence( &random, prob_G, prob_C, prob_A, pattern[ind], pat_length[ind] );
		}
		else if ( pat_type[ind] == PAT_TYPE_SAMP ) {
			pattern[ind] = pattern_allocate( &random, pat_samp_length_mean, pat_samp_length_dev, seq_length, &pat_length[ind] );
#define REGENERATE_SAMPLE_PATTERNS
#ifdef REGENERATE_SAMPLE_PATTERNS
			rng_t random_seq_orig = rng_new( seed );
			generate_sample_sequence( &random, random_seq_orig, prob_G, prob_C, prob_A, seq_length, pat_samp_loc_mean, pat_samp_loc_dev, pattern[ind], pat_length[ind] );
#else
			copy_sample_sequence( &random, sequence, seq_length, pat_samp_loc_mean, pat_samp_loc_dev, pattern[ind], pat_length[ind] );
#endif
		}
		else {
			fprintf(stderr,"\n-- Error internal: Paranoic check! A pattern without type at position %d\n", ind );
			exit( EXIT_FAILURE );
		}
	}
	free( pat_type );

	/* Allocate and move the patterns to the GPU */
	int chunk_size = (pat_number + size - 1) / size;
	int start_pat = rank * chunk_size;
	int end_pat = (rank + 1) * chunk_size;
	if (end_pat > pat_number) end_pat = pat_number;
	int pat_per_proc = end_pat - start_pat;

	unsigned long *d_pat_length;
	char **d_pattern;
	CUDA_CHECK_FUNCTION( cudaMalloc( &d_pat_length, sizeof(unsigned long) * pat_per_proc ) );
	CUDA_CHECK_FUNCTION( cudaMalloc( &d_pattern, sizeof(char *) * pat_per_proc ) );

	char **d_pattern_in_host = (char **)malloc( sizeof(char*) * pat_per_proc );
	if ( d_pattern_in_host == NULL ) {
		fprintf(stderr,"\n-- Error allocating the patterns structures replicated in the host for size: %d\n", pat_per_proc );
		exit( EXIT_FAILURE );
	}
	for( ind = start_pat; ind < end_pat; ind++ ) {
		int local_ind = ind - start_pat;
		CUDA_CHECK_FUNCTION( cudaMalloc( &(d_pattern_in_host[local_ind]), sizeof(char) * pat_length[ind] ) );
		CUDA_CHECK_FUNCTION( cudaMemcpy( d_pattern_in_host[local_ind], pattern[ind], pat_length[ind] * sizeof(char), cudaMemcpyHostToDevice ) );
	}
	CUDA_CHECK_FUNCTION( cudaMemcpy( d_pattern, d_pattern_in_host, pat_per_proc * sizeof(char *), cudaMemcpyHostToDevice ) );

	/* Avoid the usage of arguments to take strategic decisions
	 * In a real case the user only has the patterns and sequence data to analize
	 */
	argc = 0;
	argv = NULL;
	pat_rng_num = 0;
	pat_rng_length_mean = 0;
	pat_rng_length_dev = 0;
	pat_samp_num = 0;
	pat_samp_length_mean = 0;
	pat_samp_length_dev = 0;
	pat_samp_loc_mean = 0;
	pat_samp_loc_dev = 0;
	pat_samp_mix = '0';

	/* 2.3. Other result data and structures */
	int pat_matches = 0;

	/* 2.3.1. Other results related to patterns */
	unsigned long *pat_found;
	pat_found = (unsigned long *)malloc( sizeof(unsigned long) * pat_number );
	if ( pat_found == NULL ) {
		fprintf(stderr,"\n-- Error allocating aux pattern structure for size: %d\n", pat_number );
		exit( EXIT_FAILURE );
	}

	/* 3. Start global timer */
        CUDA_CHECK_FUNCTION( cudaDeviceSynchronize() );
	double ttotal = cp_Wtime();

/*
 *
 * START HERE: DO NOT CHANGE THE CODE ABOVE THIS POINT
 * DO NOT USE OpenMP IN YOUR CODE
 *
 */
	/* 2.1. Allocate and fill sequence */
	char *sequence = (char *)malloc( sizeof(char) * seq_length );
	if ( sequence == NULL ) {
		fprintf(stderr,"\n-- Error allocating the sequence for size: %lu\n", seq_length );
		exit( EXIT_FAILURE );
	}

	random = rng_new( seed );
	generate_rng_sequence( &random, prob_G, prob_C, prob_A, sequence, seq_length);

#ifdef DEBUG
	/* DEBUG: Print sequence and patterns */
	printf("-----------------\n");
	printf("Sequence: ");
	for( lind=0; lind<seq_length; lind++ ) 
		printf( "%c", sequence[lind] );
	printf("\n-----------------\n");
	printf("Patterns: %d ( rng: %d, samples: %d )\n", pat_number, pat_rng_num, pat_samp_num );
	int debug_pat;
	for( debug_pat=0; debug_pat<pat_number; debug_pat++ ) {
		printf( "Pat[%d]: ", debug_pat );
		for( lind=0; lind<pat_length[debug_pat]; lind++ ) 
			printf( "%c", pattern[debug_pat][lind] );
		printf("\n");
	}
	printf("-----------------\n\n");
#endif // DEBUG

	/* 2.3.2. Other results related to the main sequence */
	int *seq_matches;
	seq_matches = (int *)malloc( sizeof(int) * seq_length );
	if ( seq_matches == NULL ) {
		fprintf(stderr,"\n-- Error allocating aux sequence structures for size: %lu\n", seq_length );
		exit( EXIT_FAILURE );
	}

	/* 4. Initialize ancillary structures */
	for( ind=0; ind<pat_number; ind++) {
		pat_found[ind] = 0;
	}
	for( lind=0; lind<seq_length; lind++) {
		seq_matches[lind] = 0;
	}

	/* 5. Subdivide work among MPI processes */

	/* 6. Allocate local arrays */
	unsigned long *local_pat_found= (unsigned long*)malloc(sizeof(unsigned long) * pat_number);
	int *local_seq_matches= (int*)malloc(sizeof(int) * seq_length);
	int local_pat_matches= 0;

	/* 6. Allocate device memory for sequence and patterns */
	char *d_sequence;

	CUDA_CHECK_FUNCTION( cudaHostRegister(sequence, sizeof(char) * seq_length, cudaHostRegisterDefault) );
	CUDA_CHECK_FUNCTION( cudaMalloc( &d_sequence, sizeof(char) * seq_length ) );
	CUDA_CHECK_FUNCTION( cudaMemcpy( d_sequence, sequence, sizeof(char) * seq_length, cudaMemcpyHostToDevice ) );
	CUDA_CHECK_FUNCTION( cudaHostUnregister(sequence) );

	unsigned long *d_pat_found;
	CUDA_CHECK_FUNCTION( cudaMalloc( &d_pat_found, sizeof(unsigned long) * pat_per_proc ) );

	int *d_seq_matches;
	CUDA_CHECK_FUNCTION( cudaMalloc( &d_seq_matches, sizeof(int) * seq_length ) );
	
	CUDA_CHECK_FUNCTION( cudaHostRegister(pat_length + start_pat, sizeof(unsigned long) * pat_per_proc, cudaHostRegisterDefault) );
	CUDA_CHECK_FUNCTION( cudaMemcpy( d_pat_length, pat_length + start_pat, sizeof(unsigned long) * pat_per_proc, cudaMemcpyHostToDevice ) );
	CUDA_CHECK_FUNCTION( cudaHostUnregister(pat_length + start_pat) );
	
	/* 8. Launch CUDA kernel */
	int threads_per_block = 256;
	int blocks_per_grid = (end_pat - start_pat + threads_per_block - 1) / threads_per_block;
	int shared_mem_size = threads_per_block * sizeof(int);

	int *d_pat_matches;
	CUDA_CHECK_FUNCTION( cudaMalloc( &d_pat_matches, sizeof(int) * blocks_per_grid ) );
	int *d_total_matches;
	CUDA_CHECK_FUNCTION( cudaMalloc( &d_total_matches, sizeof(int) ) );

	// Launch the search_patterns kernel
	search_patterns<<<blocks_per_grid, threads_per_block, shared_mem_size>>>(d_sequence, d_pattern, d_pat_length, d_pat_matches, d_pat_found, d_seq_matches, pat_per_proc, seq_length);
	CUDA_CHECK_KERNEL();

	// Print all elements inside d_pat_matches
	int *h_pat_matches = (int *)malloc(sizeof(int) * blocks_per_grid);
	if (h_pat_matches == NULL) {
		fprintf(stderr, "\n-- Error allocating host memory for d_pat_matches\n");
		exit(EXIT_FAILURE);
	}
	CUDA_CHECK_FUNCTION(cudaMemcpy(h_pat_matches, d_pat_matches, sizeof(int) * blocks_per_grid, cudaMemcpyDeviceToHost));

	/*
	printf("\nElements in d_pat_matches:\n");
	for (int i = 0; i < blocks_per_grid; i++) {
		printf("d_pat_matches[%d] = %d\n", i, h_pat_matches[i]);
	}
	printf("\n");
	*/

	int threads_per_block_reduction = min(1024, blocks_per_grid);
	int blocks_per_grid_reduction = (blocks_per_grid + threads_per_block_reduction - 1) / threads_per_block_reduction;

	int *d_pat_reduction;
	int length_pat_matches = blocks_per_grid;
	while (true) {
		printf("blocks_per_grid_reduction = %d length_pat_matches = %d\n", blocks_per_grid_reduction, length_pat_matches);
		printf("INSIDE LOOP\n");
		CUDA_CHECK_FUNCTION( cudaMalloc( &d_pat_reduction, sizeof(int) * blocks_per_grid_reduction ) );
		partial_reduce<<<blocks_per_grid_reduction, threads_per_block_reduction, threads_per_block_reduction * sizeof(int)>>>(d_pat_matches, d_pat_reduction, length_pat_matches);
		CUDA_CHECK_KERNEL();
		
		// Exchanging old block reduction with new one
		CUDA_CHECK_FUNCTION( cudaFree(d_pat_matches) );
		d_pat_matches = d_pat_reduction;
		
		CUDA_CHECK_FUNCTION(cudaMemcpy(h_pat_matches, d_pat_matches, sizeof(int) * blocks_per_grid_reduction, cudaMemcpyDeviceToHost));
		
		printf("\nElements in d_pat_matches:\n");
		for (int i = 0; i < blocks_per_grid_reduction; i++) {
			printf("d_pat_matches[%d] = %d\n", i, h_pat_matches[i]);
		}
		printf("\n");

		length_pat_matches = blocks_per_grid_reduction;
		if (blocks_per_grid_reduction == 1) {
			break;
		}

		blocks_per_grid_reduction = (blocks_per_grid_reduction + threads_per_block_reduction - 1) / threads_per_block_reduction;
	}
	free(h_pat_matches);

	reduced_sum<<<blocks_per_grid_reduction, threads_per_block_reduction, threads_per_block_reduction * sizeof(int)>>>(d_pat_matches, d_total_matches, length_pat_matches);
	CUDA_CHECK_KERNEL();

	/* 9. Copy results back to host */
	CUDA_CHECK_FUNCTION( cudaMemcpy( local_pat_found + pat_per_proc * rank, d_pat_found, sizeof(unsigned long) * pat_per_proc, cudaMemcpyDeviceToHost ) );
	CUDA_CHECK_FUNCTION( cudaMemcpy( local_seq_matches, d_seq_matches, sizeof(int) * seq_length, cudaMemcpyDeviceToHost ) );
	CUDA_CHECK_FUNCTION( cudaMemcpy( &local_pat_matches, d_total_matches, sizeof(int), cudaMemcpyDeviceToHost ) );

	/* 10. Gather results from all MPI processes */
	MPI_Gather(local_pat_found, pat_per_proc, MPI_UNSIGNED_LONG, pat_found, pat_per_proc, MPI_UNSIGNED_LONG, 0, MPI_COMM_WORLD);
	MPI_Reduce(local_seq_matches, seq_matches, seq_length, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);
	MPI_Reduce(&local_pat_matches, &pat_matches, 1, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);

	/* 11. Free device memory */
	CUDA_CHECK_FUNCTION( cudaFree(d_sequence) );
	CUDA_CHECK_FUNCTION( cudaFree(d_pat_found) );
	CUDA_CHECK_FUNCTION( cudaFree(d_seq_matches) );
	CUDA_CHECK_FUNCTION( cudaFree(d_pat_matches) );

	/* 7. Check sums */
	unsigned long checksum_matches = 0;
	unsigned long checksum_found = 0;
	for( ind=0; ind < pat_number; ind++) {
		if ( pat_found[ind] != 0 )
			checksum_found = ( checksum_found + pat_found[ind] - 1) % CHECKSUM_MAX;
	}
	for( lind=0; lind < seq_length; lind++) {
		if ( seq_matches[lind] != 0 )
			checksum_matches = ( checksum_matches + seq_matches[lind] - 1) % CHECKSUM_MAX;
	}

#ifdef DEBUG
	/* DEBUG: Write results */
	printf("-----------------\n");
	printf("Found start:");
	for( debug_pat=0; debug_pat<pat_number; debug_pat++ ) {
		printf( " %lu", pat_found[debug_pat] );
	}
	printf("\n");
	printf("-----------------\n");
	printf("Matches:");
	for( lind=0; lind<seq_length; lind++ ) 
		printf( " %d", seq_matches[lind] );
	printf("\n");
	printf("-----------------\n");
#endif // DEBUG

	/* Free local resources */	
	free( sequence );
	free( seq_matches );

/*
 *
 * STOP HERE: DO NOT CHANGE THE CODE BELOW THIS POINT
 *
 */

	/* 8. Stop global timer */
    CUDA_CHECK_FUNCTION( cudaDeviceSynchronize() );
	MPI_Barrier( MPI_COMM_WORLD );
	ttotal = cp_Wtime() - ttotal;
	MPI_Finalize();

	if (rank == 0) {
		/* 9. Output for leaderboard */
		printf("\n");
		/* 9.1. Total computation time */
		printf("Time: %lf\n", ttotal );

		/* 9.2. Results: Statistics */
		printf("Result: %d, %lu, %lu\n\n", 
				pat_matches,
				checksum_found,
				checksum_matches );	
	}

	/* 10. Free resources */	
	int i;
	for( i=0; i<pat_number; i++ ) free( pattern[i] );
	free( pattern );
	free( pat_length );
	free( pat_found );

	/* 11. End */
	return 0;
}

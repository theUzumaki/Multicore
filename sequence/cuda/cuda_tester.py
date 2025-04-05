
import subprocess
import time
import concurrent.futures

def run_seq_executable(executable: str, input_data: str):
    command = [executable] + input_data.split()
    process = subprocess.run(
        command,
        text=True,
        capture_output=True
    )

    output_lines = process.stdout.strip().split("\n")
    print("OUTPUT: ", output_lines)
    if len(output_lines) >= 1:
#        print(output_lines[1].split())
        if output_lines[1].split()[1] == "0,":
            return None
        first_line_words = output_lines[0].split()
        if len(first_line_words) >= 2:
            return float(first_line_words[1])
    return None

def run_executable(executable: str, input_data: str, num_processes: str):
    # Create the job.slurm file dynamically based on the input
    with open("job.slurm", "w") as slurm_file:
        slurm_file.write("#!/bin/bash\n")
        slurm_file.write("#SBATCH --job-name=test_job\n")
        slurm_file.write("#SBATCH --output=job_output.txt\n")
        slurm_file.write("#SBATCH --error=job_error.txt\n")
        slurm_file.write("#SBATCH --ntasks=" + num_processes + "\n")
        slurm_file.write("#SBATCH --cpus-per-task=1\n")
        slurm_file.write("#SBATCH --gres=gpu:1\n")
        slurm_file.write("\n")
        slurm_file.write(f"mpirun {executable} {' '.join(input_data.split())}\n")

    # Submit the job using sbatch
    process = subprocess.run(
        ["sbatch", "job.slurm"],
        text=True,
        capture_output=True
    )

    # Wait for the job to complete and read the output
    job_id = process.stdout.strip().split()[-1]
    print(f"Submitted job with ID: {job_id}")

    # Poll for job completion and read the output file
    counter= 0
    while True:
        time.sleep(1)  # Wait for 5 seconds before checking again
        counter+= 1
        check_process = subprocess.run(
            ["squeue", "--job", job_id],
            text=True,
            capture_output=True
        )
        if job_id not in check_process.stdout:
            break  # Job is no longer in the queue
        if counter == 30:
            counter= 0
            print("...waiting...")

    # Read the output from the job_output.txt file
    with open("job_output.txt", "r") as output_file:
        output_lines = output_file.read().strip().split("\n")
        print("OUTPUT: ", output_lines)
        if len(output_lines) >= 1:
#            print(output_lines[1].split())
            if output_lines[1].split()[1] == "0,":
                return None
            first_line_words = output_lines[0].split()
            if len(first_line_words) >= 2:
                return float(first_line_words[1])
        return None

def measure_execution_time(executable: str, input_data: list, n: int):

    print()
    print(f"EXECUTING {executable} {n} times")
    print(f"WITH INPUT: {input_data}")
    print()

    input_data = " ".join(input_data)
    open("cuda_execution_times.txt", "a").write(f"\n\n{input_data}\n\n")
    with concurrent.futures.ThreadPoolExecutor(4) as executor:
        futures = [executor.submit(run_seq_executable, "./align_seq", input_data) for _ in range(n)]
        for i, future in enumerate(concurrent.futures.as_completed(futures)):
            try:
                execution_time = future.result()
            except Exception as e:
                print(f"An error occurred while processing a future: {e}")
                execution_time = None
            if execution_time is not None:
                print(f"Run {i+1}: {execution_time:.6f} seconds")
                average_time = sum(execution_times) / n
        print(f"Average Execution Time: {average_time:.6f} seconds\n")
        all_times.append(input_data + str(execution_times))
        line= f"{average_time:.6f} seconds\n"
    seq_time= average_time
    open("cuda_execution_times.txt", "a").write("SEQUENTIAL TIME: " + str(seq_time) + f"\n{executable}\n")
    print("SEQUENTIAL TIME: " + str(seq_time) + "\n\n")
    with concurrent.futures.ThreadPoolExecutor(4) as executor:
        futures = [executor.submit(run_executable, executable, input_data, "1") for _ in range(n)]
        for i, future in enumerate(concurrent.futures.as_completed(futures)):
            try:
                execution_time = future.result()
            except Exception as e:
                print(f"An error occurred while processing a future: {e}")
                execution_time = None
            if execution_time is not None:
                print(f"Run {i+1}: {execution_time:.6f} seconds")
                average_time = sum(execution_times) / n
        print(f"Average Execution Time: {average_time:.6f} seconds\n")
        all_times.append(input_data + str(execution_times))
        line= f"{average_time:.6f} seconds\n"
    seq_time= average_time
    open("cuda_execution_times.txt", "a").write("PARALLEL ONE PROCESS TIME: " + str(seq_time) + f"\n{executable}\n")
    print("PARALLEL ONE PROCESS TIME: " + str(seq_time) + "\n\n")
    threads= [2, 4, 8]
    all_times= []
    for cores in threads:
        execution_times = []
        print(f"Running with {cores} cores {n} times\n\n")
        with concurrent.futures.ThreadPoolExecutor(4) as executor:
            futures = [executor.submit(run_executable, executable, input_data, str(cores)) for _ in range(n)]
            for i, future in enumerate(concurrent.futures.as_completed(futures)):
                try:
                    execution_time = future.result()
                except Exception as e:
                    print(f"An error occurred while processing a future: {e}")
                    execution_time = Noneexecution_time = future.result()
                if execution_time is not None:
                    execution_times.append(execution_time)
                    print(f"Run {i+1}: {execution_time:.6f} seconds")
                else:
                    print("Error in solution, skipping cores")
                    break
        average_time = sum(execution_times) / n
        print(f"Average Execution Time: {average_time:.6f} seconds\n")
        speedup= seq_time / average_time
        efficiency= (speedup / cores) * 100
        all_times.append(input_data + str(execution_times))
        line= f"{average_time:.6f} seconds\t{speedup:.6f}\t{efficiency:.6f}%\n"
        with open("cuda_execution_times.txt", "a") as f:
            f.write(line)
    open("all_times.txt", "a").write("\n")
    open("all_times.txt", "a").write(str(all_times))

if __name__ == "__main__":
    executable_path = "./align_m_c"  # Change this to your executable's path
    runs = 25  # Number of times to run
    header= "\n\n6 --------\nBasic run with cluster"
    open("cuda_execution_times.txt", "a").write(header)
    open("all_times.txt", "a").write(header)
    with open("inputs.txt", 'r') as file:
        for line in file:
            # Strip any leading/trailing whitespace and split the line into arguments
            args_string = line.strip()
            # Call the function with the split arguments
            measure_execution_time(executable_path, args_string.split(), runs)


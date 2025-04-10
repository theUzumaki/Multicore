import os
import subprocess
import time
import statistics

# Paths to the files
output_file = "job_output.txt"
error_file = "job_error.txt"
slurm_job = "job.slurm"
result_file = "manual_result.txt"

# Number of runs
n = 5  # Change this to the desired number of runs

# Function to run the job and measure execution time
def run_job():
    # Remove existing output and error files if they exist
    if os.path.exists(output_file):
        os.remove(output_file)
    if os.path.exists(error_file):
        os.remove(error_file)

    # Run the slurm job
    process = subprocess.Popen(["sbatch", slurm_job], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()

    # Extract job ID from sbatch output
    job_id = None
    if process.returncode == 0:
        output_lines = stdout.decode("utf-8").strip().split("\n")
        for line in output_lines:
            if "Submitted batch job" in line:
                job_id = line.split()[-1]
                break

    if not job_id:
        raise RuntimeError("Failed to submit job or extract job ID.")

    # Wait for the job to complete by checking its status
    print(f"Submitted job {job_id}, waiting for completion...")
    counter = 0
    while True:
        status_process = subprocess.Popen(["squeue", "-j", job_id], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        status_stdout, _ = status_process.communicate()
        if job_id not in status_stdout.decode("utf-8"):
            break
        time.sleep(1)
        counter += 1
        if counter % 10 == 0:
            print(f"Waiting for job to complete... {counter} seconds passed...")

    # Ensure output and error files exist
    while not (os.path.exists(output_file) and os.path.exists(error_file)):
        time.sleep(1)
        print("Waiting for output and error files to be generated...")

    # Read the output and error files
    with open(output_file, "r") as f:
        job_output = ''.join(f.readlines()[:15])

    with open(error_file, "r") as f:
        job_error = ''.join(f.readlines()[:15])

    # Print the first 15 lines of the files
    print("Job Output (first 15 lines):")
    print(job_output)
    print("Job Error (first 15 lines):")
    print(job_error)

    execution_time = job_output.split("Time: ")[-1].split()[0]

    return execution_time

# Run the job n times and collect execution times
execution_times = []
for i in range(n):
    print(f"Starting run {i + 1} of {n}...")
    execution_time = run_job()
    execution_times.append(execution_time)
    print(f"Run {i + 1} completed in {execution_time:.2f} seconds.")

# Calculate average and median times
average_time = sum(execution_times) / len(execution_times)
median_time = statistics.median(execution_times)

# Save results to manual_result.txt
with open(result_file, "a") as f:
    f.write(f"Number of runs: {n}\n")
    f.write(f"Execution times: {execution_times}\n")
    f.write(f"Average time: {average_time:.2f} seconds\n")
    f.write(f"Median time: {median_time:.2f} seconds\n")

print(f"Results saved to {result_file}")

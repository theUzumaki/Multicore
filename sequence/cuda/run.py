import os
import subprocess
import time
import statistics

# Paths to the files
output_file = "job_output.txt"
error_file = "job_error.txt"
slurm_job = "onenodeonegpu.slurm"
result_file = "output_log.txt"

# Number of runs
n = 8  # Change this to the desired number of runs

# Function to submit a job and return its job ID
def submit_job():
    # Remove existing output and error files if they exist
    if os.path.exists(output_file):
        os.remove(output_file)
    if os.path.exists(error_file):
        os.remove(error_file)

    # Submit the slurm job
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

    print(f"Submitted job {job_id}")
    return job_id

# Function to wait for a job to complete
def wait_for_job(job_id):

    output = f"job_output_{job_id}.txt"
    error = f"job_error_{job_id}.txt"

    print(f"Waiting for job {job_id} to complete...")
    counter = 0
    while True:
        status_process = subprocess.Popen(["squeue", "-j", job_id], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        status_stdout, _ = status_process.communicate()
        if job_id not in status_stdout.decode("utf-8"):
            break
        time.sleep(1)
        counter += 1
        if counter % 10 == 0:
            print(f"Waiting for job {job_id} to complete... {counter} seconds passed...")

    # Ensure output and error files exist
    while not (os.path.exists(output) and os.path.exists(error)):
        time.sleep(1)
        counter+= 1
        if counter % 10 == 0:
             print(f"Waiting for output and error files for job {job_id} to be generated...")

    # Read the output and error files
    with open(output, "r") as f:
        job_output = ''.join(f.readlines()[:15])

    with open(error, "r") as f:
        job_error = ''.join(f.readlines()[:15])

    # Print the first 15 lines of the files
    print()
    print(f"Job {job_id} Output (first 15 lines):")
    print(job_output)
    print()
    print(f"Job {job_id} Error (first 15 lines):")
    print(job_error)

    # Extract execution time from the output file
    execution_time = None
    for line in job_output.splitlines():
        if line.startswith("Time:"):
            parts = line.split(",")
            if len(parts) > 0:
                try:
                    execution_time = float(parts[0].split(":")[1].strip())
                except ValueError:
                    execution_time = 0
                    raise RuntimeError("Failed to parse execution time from output.")
            break

    return execution_time

# Submit all jobs and collect their job IDs
import concurrent.futures

def process_job(_):
    job_id = submit_job()
    execution_time = wait_for_job(job_id)
    return job_id, execution_time

# Remove all files starting with "job_output" or "job_error"
for file in os.listdir("."):
    if file.startswith("job_output") or file.startswith("job_error"):
        os.remove(file)
        print(f"Removed file: {file}")

job_ids = []
execution_times = []

print(f"Submitting and waiting for {n} jobs in parallel...")
with concurrent.futures.ThreadPoolExecutor() as executor:
    results = list(executor.map(process_job, range(n)))

for job_id, execution_time in results:
    job_ids.append(job_id)
    execution_times.append(execution_time)
    print(f"Job {job_id} completed in {execution_time:.2f} seconds.")

# Calculate average and median times
average_time = sum(execution_times) / len(execution_times)
median_time = statistics.median(execution_times)

# Read the input from slurm_job as it is the last line
with open(slurm_job, "r") as slurm_file:
    inputtxt = slurm_file.readlines()[-1].strip()

# Save results to result_file
with open(result_file, "a") as f:
    f.write(f"\nInput: {inputtxt}\n")
    f.write(f"Number of runs: {n}\n")
    f.write(f"Execution times: {execution_times}\n")
    f.write(f"Average time: {average_time} seconds\n")
    f.write(f"Median time: {median_time} seconds\n")

print(f"Results saved to {result_file}")

import os
import subprocess
import time

# Paths to the files
output_file = "job_output.txt"
error_file = "job_error.txt"
slurm_job = "job.slurm"

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
counter= 0
while True:
    status_process = subprocess.Popen(["squeue", "-j", job_id], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    status_stdout, _ = status_process.communicate()
    if job_id not in status_stdout.decode("utf-8"):
        break
    time.sleep(1)
    counter+= 1
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

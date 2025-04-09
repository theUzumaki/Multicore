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

# Wait for the job to complete
print("Submitted job, waiting for completion...")
while not (os.path.exists(output_file) and os.path.exists(error_file)):
    time.sleep(1)
    print("Waiting for job to complete...")

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
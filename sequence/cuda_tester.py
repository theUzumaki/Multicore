
import subprocess
import time
import concurrent.futures

def run_executable(executable, input_data):
    process = subprocess.run(
        [executable] + input_data,
        text=True,
        capture_output=True
    )
    output_lines = process.stdout.strip().split("\n")
    print("DEBUG-> "+output_lines)
    if len(output_lines) >= 1:
        first_line_words = output_lines[0].split()
        if len(first_line_words) >= 2:
            return float(first_line_words[1])
    return None

def measure_execution_time(executable: str, input_data: list, n: int):

    print()
    print(f"EXECUTING {executable} {n} times")
    print(f"WITH INPUT: {input_data}")
    print()


    open("cuda_execution_times.txt", "a").write(f"\n\n{input_data}\n\n")
    seq_time= run_executable("./align_m_c", input_data + ["1"])
    open("cuda_execution_times.txt", "a").write("PARALLEL ONE PROCESS TIME: " + str(seq_time) + f"\n{executable}\n")
    threads= [2, 4, 8, 16]
    all_times= []
    for cores in threads:
        execution_times = []
        with concurrent.futures.ThreadPoolExecutor(4) as executor:
            futures = [executor.submit(run_executable, executable, input_data + [str(cores)]) for _ in range(n)]
            for i, future in enumerate(concurrent.futures.as_completed(futures)):
                execution_time = future.result()
                if execution_time is not None:
                    execution_times.append(execution_time)
                    print(f"Run {i+1}: {execution_time:.6f} seconds")

        average_time = sum(execution_times) / n
        print(f"Average Execution Time: {average_time:.6f} seconds\n")
        speedup= seq_time / average_time
        efficiency= (speedup / cores) * 100
        all_times.append(input_data + execution_times)
        line= f"{average_time:.6f} seconds\t{speedup:.6f}\t{efficiency:.6f}%\n"
        with open("cuda_execution_times.txt", "a") as f:
            f.write(line)
    open("all_times.txt", "a").write("\n")
    open("all_times.txt", "a").write(str(all_times))

if __name__ == "__main__":
    executable_path = "./align_m_c"  # Change this to your executable's path
    runs = 20  # Number of times to run
    header= "\n\n----SECOND TEST----\nChanged sequence time with parallel on one process"
    open("cuda_execution_times.txt", "a").write(header)
    open("all_times.txt", "a").write(header)
    with open("inputs.txt", 'r') as file:
        for line in file:
            # Strip any leading/trailing whitespace and split the line into arguments
            args_string = line.strip()
            # Call the function with the split arguments
            measure_execution_time(executable_path, args_string.split(), runs)


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
    if len(output_lines) >= 1:
        first_line_words = output_lines[0].split()
        if len(first_line_words) >= 2:
            return float(first_line_words[1])
    return None

def measure_execution_time(executable: str, input_data: list, n: int):
    execution_times = []
    print(f"EXECUTING {executable} {n} times")
    print(f"WITH INPUT: {input_data}")
    print()

    for i in range(4):
        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = [executor.submit(run_executable, executable, input_data + [pow(2,i+1)]) for _ in range(n)]
            for i, future in enumerate(concurrent.futures.as_completed(futures)):
                execution_time = future.result()
                if execution_time is not None:
                    execution_times.append(execution_time)
                    print(f"Run {i+1}: {execution_time:.6f} seconds")

        average_time = sum(execution_times) / n
        print(f"Average Execution Time: {average_time:.6f} seconds")
        line= f"{executable} {input_data} {average_time:.6f} seconds\n"
        with open("execution_times.txt", "a") as f:
            f.write(line) 


if __name__ == "__main__":
    executable_path = "./align_omp"  # Change this to your executable's path
    args_string= "10000 0.35 0.2 0.25 0 0 0 10000 9000 9000 50 100 M 4353435"  # Change this to the required input
    runs = 1000  # Number of times to run

    measure_execution_time(executable_path, args_string.split(), runs)


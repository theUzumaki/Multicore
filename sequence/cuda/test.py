# File: /Users/Mattia/Desktop/studio/uni/Multicore/sequence/cuda/test.py

def check_indices_in_limbo(file_path):
    try:
        with open(file_path, 'r') as file:
            lines = file.readlines()
            indices = set(int(line.strip().split('=')[0].split('[')[1].split(']')[0]) for line in lines if 'd_block_pat_matches[' in line and '=' in line)
        
        missing_indices = [i for i in range(1024) if i not in indices]
        
        if not missing_indices:
            print("All indices from 0 to 1023 are present.")
        else:
            print(f"Missing indices: {missing_indices}")
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    except ValueError:
        print("File contains invalid data.")

# Replace 'limbo.txt' with the actual path to your file
check_indices_in_limbo('limbo.txt')
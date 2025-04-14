# File: /Users/Mattia/Desktop/studio/uni/Multicore/sequence/cuda/test.py

def check_indices_in_limbo(file_path):
    try:
        with open(file_path, 'r') as file:
            lines = file.readlines()
            indices = set(int(line.strip()) for line in lines if line.strip().isdigit())
        
        print(f"Found {len(indices)} indices in the file.")
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
check_indices_in_limbo('sequence/cuda/limbo.txt')
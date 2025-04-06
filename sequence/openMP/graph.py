import os

import matplotlib.pyplot as plt

# Read data from execution_times.txt
execution_times = []
efficiency = []
speedup = []
line_to_read = 0

with open('execution_times.txt', 'r') as file:
    for line in file:
        if "./align_omp" in line:
            line_to_read = 4
            continue
        if line_to_read > 0:
            data = line.split()
            execution_times.append(float(data[0]))  # Execution time is at index 0
            speedup.append(float(data[2]))  # Number of cores is at index 1
            efficiency.append(float(data[3][:-1]))
            line_to_read-= 1

    # Create the base directory for graphs
    base_dir = 'graphs'
    if not os.path.exists(base_dir):
        os.makedirs(base_dir)

    counter= 0
    # Plot and save a graph for each block of 4 indexes
    for i in range(0, len(speedup), 4):  # Process each block of 4 indexes
        x_values = []
        y_values = []

        for j in range(i, min(i + 4, len(speedup))):  # Ensure we don't go out of bounds
            x_values.append(pow(2, (j % 4) + 1))  # Adjust x-values for each block
            y_values.append(speedup[j])

        # Create a new figure for every 5 blocks
        if counter == 0:
            plt.figure()

            # Print the values being plotted
            print(f"Block {i // 4 + 1}:")
            for idx, (x, y) in enumerate(zip(x_values, y_values)):
                print(f"  Index {idx + 1}: x = {x}, y = {y}")
        
        plt.plot(x_values, y_values, marker='o', label=f'input {i / 4 % 5 + 1}')
        plt.title("SPEEDUP")
        plt.xlabel('THREADS')
        plt.xticks(x_values)
        plt.xlim(2, 16)
        plt.ylabel('Speedup')
        plt.ylim(0, 16)
        plt.legend()

        # Create a subdirectory for this set of 5 blocks
        block_dir = os.path.join(base_dir, f'Blocks_{i // 20 * 5 + 1}_to_{i // 20 * 5 + 5}')
        if not os.path.exists(block_dir):
            os.makedirs(block_dir)

        # Save the graph after every 5 blocks
        counter += 1
        if counter == 5:
            counter = 0
            plt.savefig(os.path.join(block_dir, 'graph.png'))
            plt.close()

    counter = 0
    # Plot and save a graph for each block of 4 indexes using efficiency
    for i in range(0, len(efficiency), 4):  # Process each block of 4 indexes
        x_values = []
        y_values = []

        for j in range(i, min(i + 4, len(efficiency))):  # Ensure we don't go out of bounds
            x_values.append(pow(2, (j % 4) + 1))  # Adjust x-values for each block
            y_values.append(min(efficiency[j], 100))

        # Create a new figure for every 5 blocks
        if counter == 0:
            plt.figure()

            # Print the values being plotted
            print(f"Efficiency Block {i // 4 + 1}:")
            for idx, (x, y) in enumerate(zip(x_values, y_values)):
                print(f"  Index {idx + 1}: x = {x}, y = {y}")
        plt.plot(x_values, y_values, marker='o', label=f'input {i / 4 % 5 + 1}')
        plt.title('EFFICIENCY')
        plt.xlabel('THREADS')
        plt.xticks(x_values)
        plt.xlim(2, 16)
        plt.ylabel('Efficiency (%)')
        plt.ylim(0, 100)
        plt.legend()

        # Create a subdirectory for this set of 5 blocks
        block_dir = os.path.join(base_dir, f'Efficiency_Blocks_{i // 20 * 5 + 1}_to_{i // 20 * 5 + 5}')
        if not os.path.exists(block_dir):
            os.makedirs(block_dir)

        # Save the graph after every 5 blocks
        counter += 1
        print(counter)
        if counter == 5:
            counter = 0
            plt.savefig(os.path.join(block_dir, 'efficiency_graph.png'))
            plt.close()
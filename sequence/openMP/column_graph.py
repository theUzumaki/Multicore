import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import norm

# Read times from a file named 'all_times'
test = []
with open('all_times.txt', 'r') as file:
    for line in file:
        times= []
        counter= 0
        for word in line.split():
            if counter % ( len(line.split()) / 4 ) < 14:
                counter += 1
                continue
            elif word[len(word) - 2] == "]":
                word = word[:-2]
            else:
                word = word[:-1]
            counter += 1
            times.append(float(word))
        test.append(times)

for i, times in enumerate(test):

    # Subdivide times into 4 subarrays
    subarrays = np.array_split(times, 4)
    colors = ['red', 'blue', 'green', 'yellow']  # Colors for each subarray

    title= ""
    if i == 0:
        title = "300 sequence length - 400 pattern"
    elif i == 1:
        title = "1.000 sequence length - 20.000 pattern"
    elif i == 2:
        title = "10.000 sequence length - 10.000 pattern"
    elif i == 3:
        title = "100.000 sequence length - 10.000 pattern"
    elif i == 4:
        title = "10.000 sequence length - 100.000 pattern"

    for subarray, color in zip(subarrays, colors):
        # Count occurrences of each time in the subarray
        unique_sub_times, sub_counts = np.unique(subarray, return_counts=True)

        # Create a column graph for the subarray
        plt.bar(unique_sub_times, 1, width=0.000001, color=color, alpha=0.05, edgecolor=color, linewidth=3)

    plt.xlabel('Time')
    plt.xlim([0, 0.7])
    plt.yticks([0,1])  # Remove y-axis values
    plt.title(title)
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.grid(axis='x', linestyle='--', alpha=0.7)

    # Save the plot with higher precision
    plt.savefig(f'test_{i + 1}_distribution.png', dpi=300, bbox_inches='tight')
    plt.close()
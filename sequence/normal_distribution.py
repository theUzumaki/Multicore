import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import norm

# Function to read and process data
def read_data_from_file(filename):
    with open(filename, 'r') as file:
        line = file.readline().strip().split(" ")

        value= 0
        mean = 0
        std_dev = 0
        if line[0][0] == "[":
            times = []
            line = line[:-1]
            for index in range(14, len(line)):
                value = int(line[index][1:-1])
                times.append(value)
            
            mean = np.mean(times)
            std_dev = np.std(times)
        

        return mean, std_dev

# Function to plot the normal distribution
def plot_normal_distribution(mean, std_dev, test):
    x = np.linspace(mean - 4*std_dev, mean + 4*std_dev, 1000)
    y = norm.pdf(x, mean, std_dev)

    plt.figure(figsize=(8, 5))
    plt.plot(x, y, label=f'TEST NUM {test}-> Mean={mean}, Std Dev={std_dev}')
    plt.xlabel('X')
    plt.ylabel('Probability Density')
    plt.title('Normal Distribution')
    plt.legend()
    plt.grid()

    # Save the plot to a file instead of displaying it
    output_filename = f'normal_distribution_test_{test}.png'
    plt.savefig(output_filename)
    plt.close()  # Close the figure to free memory

# Main execution
filename = 'all_times.txt'  # Change this to your actual filename
for i in range(0, 3):
    mean, std_dev = read_data_from_file(filename)
    plot_normal_distribution(mean, std_dev, test)

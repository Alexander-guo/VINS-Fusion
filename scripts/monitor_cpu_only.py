import psutil
import subprocess
import time
import csv
import argparse
import os


def monitor(output_file, interval=0.5):
    """
    Main loop to monitor and log system resources to a CSV file.
    """
    print(f"Monitoring started. Saving data to: {output_file}...")
    
    # CSV Header definition (changed from memory_percent to memory_mb)
    headers = ['timestamp', 'cpu_percent', 'memory_mb']
    
    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        
        # Pre-call once to initialize non-blocking cpu_percent (avoids a dummy 0.0 value)
        psutil.cpu_percent(interval=None)
        
        try:
            while True:
                # CPU usage percent (interval=None for non-blocking)
                cpu = psutil.cpu_percent(interval=None)
                
                # Get detailed system memory metrics
                vm = psutil.virtual_memory()
                # Calculate actual used RAM (total - available) and convert to MB (rounded to 2 decimals)
                mem_used_mb = round((vm.total - vm.available) / (1024 ** 2), 2)
                
                # GPU specific data
                # gpu_util, vram = get_gpu_usage()
                
                # Write a new row with current timestamp
                writer.writerow([time.time(), cpu, mem_used_mb])
                
                # Flush buffer to ensure data is written even if process is killed
                f.flush() 
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\nMonitoring stopped by user (Ctrl+C).")
        except Exception as e:
            print(f"\nMonitoring stopped due to error: {e}")

if __name__ == "__main__":
    # Parsing command line arguments for flexible integration (ideal for VIO benchmarking pipelines)
    parser = argparse.ArgumentParser(description="VIO Benchmarking Resource Monitor")
    parser.add_argument("--output", type=str, required=True, help="Path to save the output CSV")
    parser.add_argument("--interval", type=float, default=0.5, help="Sampling interval in seconds (default: 0.5)")
    args = parser.parse_args()
    
    monitor(args.output, args.interval)

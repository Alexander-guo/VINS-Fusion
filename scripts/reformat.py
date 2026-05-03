#!/usr/bin/env python3
"""
Reformat .txt files by replacing comma separators with spaces.
Usage: python3 reformat.py <directory_path>
"""

import os
import sys
import re


def reformat_file(filepath, ts=None):
    """
    Read a text file, replace ',' and ', ' separators with single space,
    and overwrite the original file.
    """
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
        
        # Process each line: replace ', ' first (to avoid double spaces), then ','
        reformatted_lines = []
        for line in lines:
            # Replace ', ' with ' ' first, then standalone ','
            line = line.replace(', ', ' ')
            line = line.replace(',', ' ')
            if ts is not None:
                # Reformat timestamp if applicable
                parts = line.split()
                if parts:
                    parts[0] = reformat_timestamp(parts[0], ts)
                    line = ' '.join(parts) + '\n'
            reformatted_lines.append(line)
        
        # Write back to the same file
        with open(filepath, 'w') as f:
            f.writelines(reformatted_lines)
        
        print(f"Reformatted: {filepath}")
        return True
    
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False


def inverse_reformat_file(filepath):
    """
    Read a text file, replace space separators with commas,
    and overwrite the original file.
    """
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
        
        # Process each line: replace ' ' with ','
        reformatted_lines = []
        for line in lines:
            # Replace spaces (except leading/trailing) with commas
            # Split by whitespace, then join with commas
            stripped = line.rstrip('\n')
            parts = stripped.split()
            if parts:  # Only reformat if line has content
                if ts is not None:
                    # Reformat timestamp if applicable
                    parts[0] = reformat_timestamp(parts[0], ts)
                reformatted_line = ','.join(parts) + '\n'
            else:
                reformatted_line = line  # Keep empty lines as-is
            reformatted_lines.append(reformatted_line)
        
        # Write back to the same file
        with open(filepath, 'w') as f:
            f.writelines(reformatted_lines)
        
        print(f"Inverse reformatted: {filepath}")
        return True
    
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False


def reformat_timestamp(part, ts):
    """
    Reformat a timestamp string by to second.
    """
    try:
        timestamp = float(part)
        if ts == 'ms':
            timestamp /= 1e3
        elif ts == 'us':
            timestamp /= 1e6
        elif ts == 'ns':
            timestamp /= 1e9
        return str(timestamp)
    except ValueError:
        return part  # Return original if conversion fails


def reformat_directory(directory_path):
    """
    Recursively iterate through all .txt files in the given directory tree and reformat them.
    """
    if not os.path.isdir(directory_path):
        print(f"Error: {directory_path} is not a valid directory")
        return
    
    # Recursively find all .txt files
    txt_files = []
    for root, dirs, files in os.walk(directory_path):
        for filename in files:
            if filename.endswith('.txt'):
                filepath = os.path.join(root, filename)
                txt_files.append(filepath)
    
    if not txt_files:
        print(f"No .txt files found in {directory_path} or its subdirectories")
        return
    
    print(f"Found {len(txt_files)} .txt file(s) in {directory_path} (including subdirectories)")
    
    if ts is not None:
        print(f"Reformatting timestamps from {ts} to seconds")

    success_count = 0
    for filepath in txt_files:
        if reformat_file(filepath, ts):
            success_count += 1
    
    print(f"\nCompleted: {success_count}/{len(txt_files)} files reformatted successfully")


def inverse_reformat_directory(directory_path):
    """
    Recursively iterate through all .txt files in the given directory tree and apply inverse reformat.
    """
    if not os.path.isdir(directory_path):
        print(f"Error: {directory_path} is not a valid directory")
        return
    
    # Recursively find all .txt files
    txt_files = []
    for root, dirs, files in os.walk(directory_path):
        for filename in files:
            if filename.endswith('.txt'):
                filepath = os.path.join(root, filename)
                txt_files.append(filepath)
    
    if not txt_files:
        print(f"No .txt files found in {directory_path} or its subdirectories")
        return
    
    print(f"Found {len(txt_files)} .txt file(s) in {directory_path} (including subdirectories)")
    
    success_count = 0
    for filepath in txt_files:
        if inverse_reformat_file(filepath):
            success_count += 1
    
    print(f"\nCompleted: {success_count}/{len(txt_files)} files inverse reformatted successfully")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Reformat .txt files by replacing comma separators with spaces or vice versa.")
    parser.add_argument("directory_path", help="Path to directory containing .txt files")
    parser.add_argument("--inverse", action="store_true", help="Convert spaces to commas instead of commas to spaces")
    parser.add_argument("--ts", type=str, default=None, help="Reformat timestamps from current unit (ms, us, ns) to the unit of seconds.")
    args = parser.parse_args()
    
    # if len(sys.argv) < 2:
    #     print("Usage: python3 reformat.py <directory_path> [--inverse]")
    #     print("  <directory_path>: Path to directory containing .txt files")
    #     print("  --inverse: Convert spaces to commas (default: convert commas to spaces)")
    #     print("  --ts: Reformat timestamps from current unit (ms, us, ns) to the unit of seconds.")
    #     sys.exit(1)
    
    # directory_path = sys.argv[1]
    # use_inverse = '--inverse' in sys.argv
    directory_path = args.directory_path
    use_inverse = args.inverse
    ts = args.ts
    
    if use_inverse:
        inverse_reformat_directory(directory_path)
    else:
        reformat_directory(directory_path)
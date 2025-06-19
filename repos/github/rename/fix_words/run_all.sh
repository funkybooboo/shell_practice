#!/usr/bin/env bash

# Step 1: Collect the repositories using collect_repos.sh
echo "Step 1: Collecting repositories..."
./collect_repos.sh

# Check if the previous script ran successfully
if [ $? -ne 0 ]; then
    echo "Failed to collect repositories. Aborting."
    exit 1
fi

# Step 2: Split and rename repositories using split_rename_repos.py
echo "Step 2: Splitting and renaming repositories..."
python3 split_rename_repos.py

# Check if the previous script ran successfully
if [ $? -ne 0 ]; then
    echo "Failed to split and rename repositories. Aborting."
    exit 1
fi

# Step 3: Rename repositories on GitHub using rename_repos_from_file.sh
echo "Step 3: Renaming repositories on GitHub..."
./rename_repos_from_file.sh

# Check if the previous script ran successfully
if [ $? -ne 0 ]; then
    echo "Failed to rename repositories on GitHub. Aborting."
    exit 1
fi

echo "All steps completed successfully!"

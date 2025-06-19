#!/usr/bin/env bash

# Navigate to the submissions directory
cd submissions || {
    echo "Submissions directory not found!"
    exit 1
}

# Loop through all files in the current directory
for file in *; do
    # Skip if it's not a regular file
    [ -f "$file" ] || continue

    # Extract the prefix (everything before the first underscore)
    prefix="${file%%_*}"

    # Create a directory with the prefix if it doesn't exist
    mkdir -p "$prefix"

    # Move the file into the corresponding directory
    mv "$file" "$prefix/"

    # If the file is a zip file, unzip it
    if [[ "$file" == *.zip ]]; then
        echo "Unzipping $file in $prefix/"
        unzip "$prefix/$file" -d "$prefix/"
    fi
done

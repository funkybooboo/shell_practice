#!/usr/bin/env bash

# Ensure renamed_repos.txt exists
if [ ! -f "renamed_repos.txt" ]; then
    echo "renamed_repos.txt not found! Please run the Python script first."
    exit 1
fi

# Read each line from renamed_repos.txt and use gh to rename the repository
while IFS=, read -r old_name new_name; do
    # Skip empty lines
    if [ -z "$old_name" ] || [ -z "$new_name" ]; then
        continue
    fi

    echo "Renaming repository '$old_name' to '$new_name'..."
    # Rename the repository using gh CLI
    gh repo rename "$new_name" -R "funkybooboo/$old_name" -y
done <renamed_repos.txt

echo "Renaming process completed."

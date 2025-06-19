#!/usr/bin/env bash

# Hardcoding the owner (replace 'funkybooboo' with your GitHub username)
owner="funkybooboo"

# Get the list of repositories for the authenticated user
repos=$(gh repo list --json name -L 1000 --jq '.[].name')

# Loop through each repository and rename it
for repo in $repos; do
    # Check if the repository name starts with 'cs' followed by 4 digits and an underscore
    # or starts with 'math_' followed by 4 digits
    if [[ "$repo" =~ ^cs[0-9]{4}_ || "$repo" =~ ^math[0-9]{4}_ ]]; then
        # Prepend 'usu_' to the repo name before applying other transformations
        new_name="usu_$repo"
    else
        # Use the repo name as-is (for non-matching repos)
        new_name="$repo"
    fi

    # Apply transformations: replace '-' with '_', convert to lowercase
    transformed_name=$(echo "$new_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')

    # Only rename if the name is different
    if [ "$repo" != "$transformed_name" ]; then
        echo "Renaming repository '$repo' to '$transformed_name'..."
        gh repo rename "$transformed_name" -R "$owner/$repo" -y
    else
        echo "Repository '$repo' is already following the naming convention."
    fi
done

echo "Renaming process completed."

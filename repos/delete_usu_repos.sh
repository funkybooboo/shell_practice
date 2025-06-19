#!/usr/bin/env bash

# Function to convert a string to snake_case:
# convert to lowercase, replace spaces with underscores,
# and remove any characters except lowercase letters, digits, and underscores.
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/ /_/g' -e 's/[^a-z0-9_]//g'
}

# Your GitHub username
GH_USERNAME="funkybooboo"

# Mapping from class code to custom class folder names in snake_case
declare -A class_map=(
    ["cs1400"]="cs1400_intro_to_computer_science"
    ["cs1410"]="cs1410_intro_to_computer_science_2"
    ["cs1440"]="cs1440_software_engineering_fundamentals"
    ["cs2410"]="cs2410_intro_to_event_driven_programming_and_guis"
    ["cs2420"]="cs2420_algorithms_and_data_structures"
    ["cs2610"]="cs2610_developing_dynamic_database_driven_web_applications"
    ["cs3100"]="cs3100_operating_systems_and_concurrency"
    ["cs3460"]="cs3460_modern_c_plus_plus"
    ["cs4700"]="cs4700_programming_languages"
    ["cs5050"]="cs5050_advanced_algorithms_and_data_structures"
    ["cs5060"]="cs5060_decision_making_algorithms_under_uncertainty"
    ["cs5110"]="cs5110_multi_agent_systems"
    ["cs5260"]="cs5260_cloud_development"
    ["cs5700"]="cs5700_design_patterns"
    ["math4410"]="math4410_advanced_discrete_math"
)

# Get list of repos for your account (adjust --limit as needed)
repo_names=$(gh repo list "$GH_USERNAME" --limit 100 --json name -q '.[].name')

# Array to hold repos eligible for deletion
repos_to_delete=()

echo "Checking GitHub repos for corresponding local folders..."

# Loop over each repository name
for repo in $repo_names; do
    # Process only repos starting with "usu_"
    if [[ "$repo" == usu_* ]]; then
        # Remove the "usu_" prefix
        newname="${repo#usu_}"
        # Extract the class code (everything before the first underscore)
        classcode="${newname%%_*}"
        # Extract the assignment part (everything after the first underscore)
        assignment="${newname#*_}"

        # Determine the local class directory using the mapping; fallback to classcode if not mapped.
        local_class_dir="${class_map[$classcode]}"
        if [ -z "$local_class_dir" ]; then
            local_class_dir="$classcode"
        fi

        # Check if the local class directory exists
        if [ -d "$local_class_dir" ]; then
            # Look for an assignment folder inside the class directory that starts with the assignment part.
            found=$(find "$local_class_dir" -maxdepth 1 -type d -name "${assignment}*" | head -n 1)
            if [ -n "$found" ]; then
                repos_to_delete+=("$repo")
            else
                echo "Local assignment folder not found for repo '$repo' (expected folder starting with '$assignment' in '$local_class_dir')."
            fi
        else
            echo "Local class directory '$local_class_dir' does not exist for repo '$repo'."
        fi
    fi
done

# If no repos are eligible, exit the script.
if [ ${#repos_to_delete[@]} -eq 0 ]; then
    echo "No repos eligible for deletion were found."
    exit 0
fi

# List the repos that will be deleted
echo "The following repositories will be deleted from GitHub:"
for r in "${repos_to_delete[@]}"; do
    echo "- $r"
done

# Confirm deletion
read -p "Are you sure you want to delete these repos? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    for r in "${repos_to_delete[@]}"; do
        echo "Deleting $r..."
        gh repo delete "$GH_USERNAME/$r" --yes
    done
    echo "Deletion completed."
else
    echo "Deletion aborted."
fi

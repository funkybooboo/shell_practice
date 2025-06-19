#!/usr/bin/env bash

# Function to convert a string to snake_case:
# Convert to lowercase, replace spaces with underscores,
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

# Loop over all folders starting with "usu_"
for folder in usu_*; do
    # Check if it is a directory
    if [ -d "$folder" ]; then
        # Skip TA folders (folders that start with "usu_ta_")
        if [[ "$folder" == usu_ta_* ]]; then
            echo "Skipping TA folder: $folder"
            continue
        fi

        # Remove the "usu_" prefix
        newname="${folder#usu_}"

        # Extract the class code (everything before the first underscore)
        classname="${newname%%_*}"
        # Extract the assignment part (everything after the first underscore)
        assignment="${newname#*_}"

        # Determine the destination class folder name using our mapping.
        mapped_classname="${class_map[$classname]}"
        if [ -z "$mapped_classname" ]; then
            mapped_classname="$classname"
        fi

        # Initialize new_assignment with the original assignment name (e.g., program7)
        new_assignment="$assignment"

        # Attempt to fetch the GitHub repo description using the folder name as the repo name.
        # For example, for "usu_cs2410_program7", the repo is "funkybooboo/usu_cs2410_program7"
        desc=$(gh repo view "$GH_USERNAME/$folder" --json description -q '.description' 2>/dev/null)
        if [ -n "$desc" ]; then
            # Append the slugified description to the original program name using an underscore.
            new_assignment="${assignment}_$(slugify "$desc")"
            echo "Fetched description for '$folder': '$desc'"
            echo "Renaming assignment to: '$new_assignment'"
        else
            echo "No description found for '$folder'; keeping original assignment name: '$assignment'"
        fi

        # Create the custom class folder if it doesn't exist.
        mkdir -p "$mapped_classname"

        # Move the assignment folder into the class folder with the new assignment name.
        mv "$folder" "$mapped_classname/$new_assignment"
        echo "Moved '$folder' -> '$mapped_classname/$new_assignment'"
    fi
done

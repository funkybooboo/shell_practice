#!/usr/bin/env bash
#
# This script reads a list of repository names (as produced by `gh repo list`)
# from a file, filters them by a given pattern, and then uses the merge_repos.sh
# script to merge each matching repository into a parent repository.
#
# Each matching repository is merged as a subtree into a folder named:
#     <group_folder>/<repo_name>
#
# For example, to merge all repositories whose full names contain "mtech"
# into a group folder "mtech" inside the current directory (parent repo),
# you could run:
#
#   ./merge_many.sh -l names.txt -p mtech -g mtech -P . -b main
#
# Flags:
#   -l  List file containing repo info (generated via `gh repo list`)
#   -p  Pattern to match in the repo full name (e.g. "mtech")
#   -g  Group folder name (e.g. "mtech") which will prefix each repo's subfolder
#   -P  Parent repository path (destination repo); defaults to "." if not given
#   -b  Branch to merge from; defaults to "main"
#
usage() {
    echo "Usage: $0 -l <list_file> -p <pattern> -g <group_folder> [-P <parent_repo_path>] [-b <branch>]"
    exit 1
}

# Default values
parent_repo_path="."
branch="main"
list_file=""
pattern=""
group_folder=""

# Parse command-line options
while getopts "l:p:g:P:b:h" opt; do
    case $opt in
    l)
        list_file="$OPTARG"
        ;;
    p)
        pattern="$OPTARG"
        ;;
    g)
        group_folder="$OPTARG"
        ;;
    P)
        parent_repo_path="$OPTARG"
        ;;
    b)
        branch="$OPTARG"
        ;;
    h)
        usage
        ;;
    *)
        usage
        ;;
    esac
done

# Ensure required arguments are provided
if [ -z "$list_file" ] || [ -z "$pattern" ] || [ -z "$group_folder" ]; then
    echo "Error: list file, pattern, and group folder are required."
    usage
fi

# Verify that the list file exists
if [ ! -f "$list_file" ]; then
    echo "Error: File '$list_file' not found."
    exit 1
fi

# Loop over each line in the list file
while IFS= read -r line; do
    # Assume the first field in the line is the repo full name in the form "owner/repo"
    repo_full=$(echo "$line" | awk '{print $1}')
    # Check if the repo full name contains the provided pattern
    if [[ "$repo_full" == *"$pattern"* ]]; then
        # Extract the repo name (portion after the slash)
        repo_name=$(echo "$repo_full" | cut -d'/' -f2)
        # Construct the child repository URL for SSH cloning:
        child_repo_url="git@github.com:funkybooboo/${repo_name}.git"
        # Use the repo name as the remote name
        remote_name="$repo_name"
        # Set the subfolder to be group_folder/repo_name
        subfolder="${group_folder}/${repo_name}"

        echo "Merging repository '$repo_full' into subfolder '$subfolder'..."

        # Call merge_repos.sh with the constructed parameters.
        # It is assumed that merge_repos.sh is in the same directory or in $PATH.
        ./merge_repos.sh -P "$parent_repo_path" -C "$child_repo_url" -p "$subfolder" -b "$branch" -R "$remote_name"

        # Check if merge_repos.sh succeeded
        if [ $? -ne 0 ]; then
            echo "Error merging $repo_full. Exiting."
            exit 1
        fi
    fi
done <"$list_file"

echo "All matching repositories have been merged."

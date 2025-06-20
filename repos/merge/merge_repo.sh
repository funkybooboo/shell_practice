#!/usr/bin/env bash
#
# Script to add a child repository as a subtree into a specified folder
# within a parent repository without squashing history.
# If you pass -b "*", it will merge every branch from the child into
# matching branches in the parent (creating new ones off of main as needed).
#
# Usage:
#   ./merge_repo.sh -P <parent_repo_path> -C <child_repo_url> -p <subfolder> [-b <branch|*>] [-R <child_remote_name>]
#
#   -P  Path to the parent repository (defaults to ".")
#   -C  URL of the child repository (required)
#   -p  Subfolder in the parent where the child’s files go (required)
#   -b  Branch name to merge (default: main), or "*" to merge all branches
#   -R  Remote name for the child repo (default: child_remote)

set -euo pipefail

# refuse to run if there are unstaged or uncommitted changes:
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Working tree is dirty—please commit or stash before merging." >&2
    exit 1
fi

usage() {
    echo "Usage: $0 -P <parent_repo_path> -C <child_repo_url> -p <subfolder> [-b <branch|*>] [-R <child_remote_name>]"
    exit 1
}

# Defaults
branch="main"
child_remote_name="child_remote"
parent_repo_path="."

# Parse options
while getopts "P:C:p:b:R:h" opt; do
    case $opt in
    P) parent_repo_path="$OPTARG" ;;
    C) child_repo_url="$OPTARG" ;;
    p) subfolder="$OPTARG" ;;
    b) branch="$OPTARG" ;;
    R) child_remote_name="$OPTARG" ;;
    *) usage ;;
    esac
done

# Validate required args
if [ -z "$child_repo_url" ] || [ -z "$subfolder" ]; then
    echo "Error: -C <child_repo_url> and -p <subfolder> are required."
    usage
fi

# Enter parent repo
if [ ! -d "$parent_repo_path" ]; then
    echo "Error: '$parent_repo_path' is not a directory."
    exit 1
fi
cd "$parent_repo_path" || {
    echo "Error: cd failed"
    exit 1
}
if [ ! -d .git ]; then
    echo "Error: '$parent_repo_path' is not a Git repository."
    exit 1
fi

# Add child remote if missing
if git remote | grep -q "^${child_remote_name}$"; then
    echo "Remote '${child_remote_name}' already exists; skipping."
else
    echo "Adding remote '${child_remote_name}' -> ${child_repo_url}"
    git remote add "${child_remote_name}" "${child_repo_url}"
fi

# Fetch child repo
echo "Fetching from '${child_remote_name}'..."
git fetch "${child_remote_name}"

# List all child branches
remote_branches=$(git ls-remote --heads "${child_remote_name}" |
    awk '{print $2}' |
    sed 's|refs/heads/||')

# If merging all branches:
if [ "$branch" = "*" ]; then
    for b in $remote_branches; do
        echo
        echo "=== Processing branch '$b' ==="
        # Check out or create matching branch in parent
        if git show-ref --verify --quiet "refs/heads/${b}"; then
            echo "Checking out existing parent branch '$b'"
            git checkout "$b"
        else
            echo "Creating parent branch '$b' off of 'main'"
            git checkout main
            git checkout -b "$b"
        fi
        # Merge subtree
        echo "Merging subtree from ${child_remote_name}/${b} into '${subfolder}'"
        git subtree add --prefix="${subfolder}" "${child_remote_name}" "${b}"
    done

    echo
    echo "✅ All child branches have been merged."
    exit 0
fi

# Single-branch mode: ensure only one branch on remote if not "*"
branch_count=$(echo "$remote_branches" | grep -v '^$' | wc -l)
if [ "$branch_count" -gt 1 ]; then
    echo "Error: child repo has multiple branches:"
    echo "$remote_branches"
    echo "Use -b '*' to merge them all, or specify a single branch with -b."
    exit 1
fi

# Merge the specified branch into the current parent branch
echo "Merging subtree from ${child_remote_name}/${branch} into '${subfolder}'"
git subtree add --prefix="${subfolder}" "${child_remote_name}" "${branch}"

echo "✅ Subtree merge complete."

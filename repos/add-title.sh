#!/usr/bin/env bash
# This script ensures that the title in the README file is the repository name in Title Case.
# For example, a repository named "monster_game" will have a title "Monster Game" in its README.
#
# Requirements:
#   - GitHub CLI (gh)
#   - git, sed, awk
#
# Usage:
#   Ensure you're authenticated with gh (e.g. gh auth login) and run this script.

set -euo pipefail

# Get authenticated GitHub username
USERNAME=$(gh api user --jq '.login')
echo "Authenticated as: $USERNAME"

# Get list of all repository SSH URLs for the user (adjust --limit if needed)
REPO_URLS=$(gh repo list "$USERNAME" --limit 1000 --json sshUrl --jq '.[].sshUrl')

for repo in $REPO_URLS; do
    echo "----------------------------------------"
    echo "Processing repository: $repo"

    # Clone the repository into a temporary directory
    TMP_DIR=$(mktemp -d)
    if ! git clone "$repo" "$TMP_DIR"; then
        echo "Failed to clone $repo"
        rm -rf "$TMP_DIR"
        continue
    fi

    cd "$TMP_DIR" || continue

    # Get the repository name using gh
    REPO_INFO=$(gh repo view --json name --jq '.')
    REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
    echo "Repo Name: $REPO_NAME"

    # Convert the repo name to Title Case:
    # Replace underscores with spaces and capitalize the first letter of each word.
    TITLE=$(echo "$REPO_NAME" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) { $i=toupper(substr($i,1,1)) substr($i,2) } print}')
    echo "New title: $TITLE"

    # Determine the README file (check common names)
    README_FILE=""
    for file in README.md README readme.md readme; do
        if [ -f "$file" ]; then
            README_FILE="$file"
            break
        fi
    done

    if [ -z "$README_FILE" ]; then
        # No README exists, so create one with the title.
        README_FILE="README.md"
        echo "# $TITLE" >"$README_FILE"
        echo "Created new $README_FILE with title: $TITLE"
    else
        # Get the first line from the README (assumed to be the title line)
        FIRST_LINE=$(head -n 1 "$README_FILE")
        # Remove the leading '#' and any spaces.
        CURRENT_TITLE=$(echo "$FIRST_LINE" | sed 's/^# *//')
        if [ "$CURRENT_TITLE" != "$TITLE" ]; then
            # Replace the first line with the new title.
            {
                echo "# $TITLE"
                tail -n +2 "$README_FILE"
            } >README.new
            mv README.new "$README_FILE"
            echo "Updated README title to: $TITLE"
        else
            echo "README title is already correct."
        fi
    fi

    # If there are any changes, commit and push them.
    if git diff --quiet; then
        echo "No changes to commit for $repo."
    else
        git add "$README_FILE"
        git commit -m "Update README title to \"$TITLE\""
        git push origin HEAD
        echo "Changes pushed for $repo."
    fi

    cd - >/dev/null
    rm -rf "$TMP_DIR"
done

echo "Completed updating README titles for all repositories."

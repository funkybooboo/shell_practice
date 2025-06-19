#!/usr/bin/env bash
# This script processes all your GitHub repositories by:
# 1. Adding a GNU GPLv3 LICENSE file if one doesn't exist.
# 2. Checking for a README file and ensuring it includes a License section.
#
# Requirements: GitHub CLI (gh), git, curl.
# Make sure you are authenticated with gh (run: gh auth login).

# Check if gh is installed
if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install it first."
    exit 1
fi

# Get the authenticated GitHub username
USERNAME=$(gh api user --jq '.login')
echo "Authenticated as: $USERNAME"

# Get list of all repository SSH URLs for the user (adjust --limit if needed)
REPO_URLS=$(gh repo list "$USERNAME" --limit 1000 --json sshUrl --jq '.[].sshUrl')

# Loop through each repository
for repo in $REPO_URLS; do
    echo "----------------------------------------"
    echo "Processing repository: $repo"
    # Create a temporary directory for cloning
    TMP_DIR=$(mktemp -d)
    git clone "$repo" "$TMP_DIR" || {
        echo "Failed to clone $repo"
        rm -rf "$TMP_DIR"
        continue
    }

    cd "$TMP_DIR" || continue

    # 1. Check for LICENSE file; if missing, add GNU GPLv3 license.
    if [ -f LICENSE ] || [ -f LICENSE.txt ]; then
        echo "LICENSE file exists. Skipping LICENSE file addition."
    else
        echo "Adding GNU GPLv3 LICENSE file."
        curl -s https://www.gnu.org/licenses/gpl-3.0.txt -o LICENSE
        git add LICENSE
        git commit -m "Add GNU GPLv3 LICENSE file" && git push origin HEAD
        echo "LICENSE file added and pushed."
    fi

    # 2. Determine the README file (check common names)
    readme_file=""
    if [ -f "README.md" ]; then
        readme_file="README.md"
    elif [ -f "README" ]; then
        readme_file="README"
    elif [ -f "readme.md" ]; then
        readme_file="readme.md"
    elif [ -f "readme" ]; then
        readme_file="readme"
    fi

    # If no README file exists, create a new README.md
    if [ -z "$readme_file" ]; then
        readme_file="README.md"
        echo "# Project Title" >"$readme_file"
        echo "" >>"$readme_file"
        echo "Created new $readme_file"
        git add "$readme_file"
        git commit -m "Add README file" && git push origin HEAD
    fi

    # 3. Check if the README file contains a License section.
    # We search for a markdown header (starting with #) that mentions "License" or "Licence".
    if grep -qiE "^#+\s*(License|Licence)" "$readme_file"; then
        echo "License section found in $readme_file. Skipping README update."
    else
        echo "License section not found in $readme_file. Appending License section."
        cat <<EOF >>"$readme_file"

## License

This project is licensed under the GNU General Public License v3.0. See the LICENSE file for details.
EOF
        git add "$readme_file"
        git commit -m "Add License section to README" && git push origin HEAD
        echo "License section added to $readme_file and changes pushed."
    fi

    # Clean up: return to original directory and remove the temporary clone
    cd - >/dev/null
    rm -rf "$TMP_DIR"
done

echo "Completed processing all repositories."

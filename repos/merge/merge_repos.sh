#!/usr/bin/env bash
#
# merge_repos.sh
#
# Read a list of git URLs from a text file and, for each:
#  1) extract the repo name
#  2) invoke merge_repos.sh with:
#       -P <parent>
#       -C <child_url>
#       -p <repo_name>
#       -b "*"
#       -R <child_remote_name>
#
# Usage:
#   ./merge_repos.sh <repos_list.txt> [parent_repo_path]
#
# <repos_list.txt> should contain one URL per line, e.g.:
#   https://github.com/foo/bar.git
#   git@github.com:baz/qux.git
#
# [parent_repo_path] defaults to "." if omitted.

# ------ ARGUMENTS & VALIDATION ------

set -euo pipefail

# refuse to run if there are unstaged or uncommitted changes:
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Working tree is dirty—please commit or stash before merging." >&2
    exit 1
fi

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <repos_list.txt> [parent_repo_path]"
    exit 1
fi

repos_file="$1"
parent_repo_path="${2:-.}"

if [ ! -f "$repos_file" ]; then
    echo "Error: file '$repos_file' not found."
    exit 1
fi

if [ ! -d "$parent_repo_path" ]; then
    echo "Error: parent repo path '$parent_repo_path' is not a directory."
    exit 1
fi

# Ensure merge_subtree.sh is in same directory or PATH
if ! command -v ./merge_repo.sh >/dev/null 2>&1; then
    echo "Error: ./merge_repo.sh not found in PATH."
    exit 1
fi

# ------ MAIN LOOP ------

while IFS= read -r url; do
    # skip blank lines and comments
    case "$url" in
    '' | \#*) continue ;;
    esac

    # extract repo name (strip .git if present)
    repo_name=$(basename "$url")
    repo_name=${repo_name%.git}

    # choose a unique remote alias
    remote_alias="child_${repo_name}"

    echo
    echo "Processing '$repo_name' from $url"
    echo "  parent path: $parent_repo_path"
    echo "  subfolder:   $repo_name"
    echo "  remote alias:$remote_alias"
    echo

    # invoke your existing merge_repo.sh
    ./merge_repo.sh \
        -P "$parent_repo_path" \
        -C "$url" \
        -p "$repo_name" \
        -b "*" \
        -R "$remote_alias"

    if [ $? -ne 0 ]; then
        echo "Error: ./merge_repo.sh failed for '$repo_name'."
        exit 1
    fi

done <"$repos_file"

echo
echo "All repositories merged."

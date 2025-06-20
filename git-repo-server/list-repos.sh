#!/bin/bash

REPO_DIR="/repos"

# Optional name filter
FILTER="$1"

if [ ! -d "$REPO_DIR" ]; then
    echo "[✗] Repo directory $REPO_DIR does not exist."
    exit 1
fi

echo "[+] Listing repositories in $REPO_DIR..."

REPOS=$(find "$REPO_DIR" -maxdepth 1 -type d -name "*.git" | sort)

if [ -z "$REPOS" ]; then
    echo "No repositories found."
    exit 0
fi

COUNT=0
for repo in $REPOS; do
    if [[ -z "$FILTER" || "$repo" == *"$FILTER"* ]]; then
        echo " • $(basename "$repo")"
        COUNT=$((COUNT + 1))
    fi
done

echo "[✓] Found $COUNT matching repository(ies)."

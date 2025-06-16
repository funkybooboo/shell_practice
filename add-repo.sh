#!/bin/bash

set -e

REPO_NAME="$1"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: $0 <repo-name>"
    exit 1
fi

REPO_PATH="/repos/${REPO_NAME}.git"

# Detect Apache user
if id apache &>/dev/null; then
    APACHE_USER=apache
elif id www-data &>/dev/null; then
    APACHE_USER=www-data
else
    echo "[✗] Cannot determine Apache user"
    exit 1
fi

# Check for existing repo
if [ -d "$REPO_PATH" ]; then
    echo "[!] Repo already exists: $REPO_PATH"
    exit 0
fi

echo "[+] Creating bare Git repo: $REPO_PATH"
sudo -u "$APACHE_USER" git init --bare "$REPO_PATH"

echo "[✓] Repository '$REPO_NAME' created at: $REPO_PATH"

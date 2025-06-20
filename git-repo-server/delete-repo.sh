#!/bin/bash

# ───────────── Repo Deletion Script ─────────────
set -euo pipefail

REPO_DIR="/repos"

# ───────────── Argument Check ─────────────
if [ $# -ne 1 ]; then
    echo "Usage: $0 <repo-name>"
    echo "       (this will delete /repos/<repo-name>.git)"
    exit 1
fi

REPO_NAME="$1"
TARGET_PATH="$REPO_DIR/${REPO_NAME}.git"

# ───────────── Check Existence ─────────────
if [ ! -d "$TARGET_PATH" ]; then
    echo "[✗] Repository not found: $TARGET_PATH"
    exit 1
fi

# ───────────── Confirm and Delete ─────────────
read -rp "⚠️  Are you sure you want to delete '$REPO_NAME'? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo rm -rf "$TARGET_PATH"
    echo "[✓] Deleted: $TARGET_PATH"
else
    echo "[i] Aborted."
    exit 0
fi

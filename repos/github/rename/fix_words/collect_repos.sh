#!/usr/bin/env bash

# Ensure you're authenticated with GitHub via gh CLI
# Collect the list of repositories for the authenticated user and store them in repos.txt
gh repo list --json name -L 1000 --jq '.[].name' >repos.txt

echo "Repositories have been saved to repos.txt."

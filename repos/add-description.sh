#!/usr/bin/env bash
# This script improves GitHub repository descriptions using OpenAI's API.
# It updates the description to be concise and 350 characters or less.
# Requirements:
#   - GitHub CLI (gh)
#   - curl
#   - jq
#   - OPENAI_API_KEY set in your environment
# Note: This script respects rate limits by sleeping 20 seconds between API calls.

set -euo pipefail

# Check for required commands
for cmd in gh curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed. Please install it."
        exit 1
    fi
done

# Ensure the OpenAI API key is set
if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "Error: OPENAI_API_KEY environment variable is not set."
    exit 1
fi

# Get authenticated GitHub username
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
    if ! git clone "$repo" "$TMP_DIR"; then
        echo "Failed to clone $repo"
        rm -rf "$TMP_DIR"
        continue
    fi

    cd "$TMP_DIR" || continue

    # Fetch repository details (name and current description)
    REPO_INFO=$(gh repo view --json name,description --jq '.')
    REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
    CURRENT_DESC=$(echo "$REPO_INFO" | jq -r '.description // "No description provided."')

    echo "Repo Name: $REPO_NAME"
    echo "Current Description: $CURRENT_DESC"

    # Build prompt for description improvement with explicit length constraint.
    read -r -d '' DESC_PROMPT <<EOF || true
You are a helpful assistant that improves GitHub repository descriptions.
Repository details:
- Repository Name: ${REPO_NAME}
- Current Description: ${CURRENT_DESC}

Provide a concise and enhanced repository description that is strictly 350 characters or less.
Output only the final description.
EOF

    echo "Description prompt constructed:"
    echo "$DESC_PROMPT"

    echo "Sending description improvement prompt to OpenAI API..."
    DESC_RESPONSE=$(
        curl -s https://api.openai.com/v1/chat/completions \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${OPENAI_API_KEY}" \
            -d @- <<EOF
{
  "model": "gpt-4",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant that improves repository descriptions."},
    {"role": "user", "content": "$(echo "$DESC_PROMPT" | sed ':a;N;$!ba;s/\n/\\n/g')"}
  ],
  "max_tokens": 100,
  "temperature": 0.7
}
EOF
    )
    echo "Raw description API response:"
    echo "$DESC_RESPONSE"

    # Sleep 20 seconds to help avoid exceeding rate limits
    sleep 20

    NEW_DESC=$(echo "$DESC_RESPONSE" | jq -r '.choices[0].message.content' | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ -n "$NEW_DESC" ] && [ "$NEW_DESC" != "null" ]; then
        echo "New Description: $NEW_DESC"
        gh repo edit "$repo" --description "$NEW_DESC"
        echo "Repository description updated."
    else
        echo "No improved description received."
    fi

    # Clean up: return to original directory and remove the temporary clone
    cd - >/dev/null
    rm -rf "$TMP_DIR"
done

echo "Completed processing all repositories."

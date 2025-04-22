#!/usr/bin/env bash

# Usage: local-sync /target

set -e

SOURCE_DIR="/workspace"
TARGET_DIR="$1"
WORKFLOW_FILE="${SOURCE_DIR}/.github/workflows/repo-sync.yml"

source "${SOURCE_DIR}/repo-sync-action/functions.sh"

# Extract file paths using yq
FILES=$(yq eval '.jobs.repo_sync.steps[] | select(.name=="Sync") | .with.FILES' "$WORKFLOW_FILE")

# Process each file mapping silently
while IFS= read -r file_mapping; do
  if [ -n "$file_mapping" ]; then
    sync_file "$file_mapping" "$SOURCE_DIR" "$TARGET_DIR" > /dev/null
  fi
done <<< "$FILES"

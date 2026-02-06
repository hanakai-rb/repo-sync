#!/usr/bin/env bash

# Usage: local-sync /target

set -e

SOURCE_DIR="/workspace"
TARGET_DIR="$1"
CONFIG_FILE="${SOURCE_DIR}/repo-sync.yml"

source "${SOURCE_DIR}/repo-sync-action/functions.sh"

# Validate repo-sync.yml
set +e
validation_result=$(validate_repo_sync_yml "$TARGET_DIR" "$REPO_SYNC_SCHEMA_PATH" 2>&1)
validation_status=$?
set -e
if [[ $validation_status -ne 0 ]]; then
  echo "ERROR: Invalid repo-sync.yml:"
  echo "$validation_result" | sed 's/^/  /' # Indent for clarity
  exit 1
fi

# Sync files
# Extract files for the group and convert from [source, target] pairs to source=target format
FILES=$(yq eval ".${REPO_SYNC_ORG}.files | map(.[0] + \"=\" + .[1]) | .[]" "$CONFIG_FILE")

while IFS= read -r file_mapping; do
  if [ -n "$file_mapping" ]; then
    sync_file "$file_mapping" "$SOURCE_DIR" "$TARGET_DIR" > /dev/null
  fi
done <<< "$FILES"

#!/usr/bin/env bash

# Usage: local-sync /target

set -e

SOURCE_DIR="/workspace"
TARGET_DIR="$1"
CONFIG_FILE="${SOURCE_DIR}/repo-sync.yml"

source "${SOURCE_DIR}/repo-sync-action/functions.sh"

# If the schema path wasn't passed in explicitly, look it up from the group's
# config in repo-sync.yml.
if [[ -z "$REPO_SYNC_SCHEMA_PATH" ]]; then
  SCHEMA_REL=$(yq eval ".${REPO_SYNC_GROUP}.schema" "$CONFIG_FILE")
  if [[ -z "$SCHEMA_REL" || "$SCHEMA_REL" == "null" ]]; then
    echo "ERROR: Group '${REPO_SYNC_GROUP}' has no schema declared in repo-sync.yml" >&2
    exit 1
  fi
  REPO_SYNC_SCHEMA_PATH="${SOURCE_DIR}/${SCHEMA_REL}"
fi

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
FILES=$(yq eval ".${REPO_SYNC_GROUP}.files | map(.[0] + \"=\" + .[1]) | .[]" "$CONFIG_FILE")

while IFS= read -r file_mapping; do
  if [ -n "$file_mapping" ]; then
    sync_file "$file_mapping" "$SOURCE_DIR" "$TARGET_DIR" > /dev/null
  fi
done <<< "$FILES"

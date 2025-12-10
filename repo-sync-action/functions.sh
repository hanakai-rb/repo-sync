#!/bin/bash

validate_repo_sync_yml() {
  local REPO_PATH="$1"
  local SCHEMA_PATH="$2"

  local REPO_SYNC_YML="${REPO_PATH}/repo-sync.yml"

  if [[ -z "$SCHEMA_PATH" ]]; then
    echo "ERROR: No schema path provided for validation"
    return 1
  fi
  if [[ ! -f "$SCHEMA_PATH" ]]; then
    echo "ERROR: Schema file not found at $SCHEMA_PATH"
    return 1
  fi
  if [[ ! -f "$REPO_SYNC_YML" ]]; then
    echo "ERROR: repo-sync.yml not found at $REPO_SYNC_YML"
    return 1
  fi

  # Validate against schema
  #
  # Jump into the repo dir before running yajsv so we can avoid it printing a
  # full path to repo-sync.yml in any error output.
  pushd "$(dirname "$REPO_SYNC_YML")" > /dev/null
  VALIDATION_OUTPUT=$(yajsv -s "$SCHEMA_PATH" repo-sync.yml 2>&1)
  EXIT_CODE=$?
  popd > /dev/null

  if [[ $EXIT_CODE -ne 0 ]]; then
    # Double quotes here are necessary to preserve newlines from the output
    echo "$VALIDATION_OUTPUT" | sed 's/^repo-sync\.yml: fail: //g'
    return 1
  fi

  return 0
}

# Get fully processed source and destination paths for a file
sync_file() {
  local FILE_MAPPING="$1"
  local WORKSPACE_DIR="$2"
  local TARGET_DIR="$3"

  # Parse the "source=dest" file mapping
  if [[ "$FILE_MAPPING" != *"="* ]]; then
    log "ERROR: Invalid file mapping format: [$FILE_MAPPING]. Use 'source=destination'."
    exit 1
  fi
  local SOURCE_PATH="${FILE_MAPPING%%=*}"
  local DEST_PATH="${FILE_MAPPING#*=}"

  # Set the full source path
  local SOURCE_FULL_PATH="${WORKSPACE_DIR}/${SOURCE_PATH}"

  # Process the destination path through templating if needed
  local GENERATED_DEST_PATH=$(generate_target_filename "$DEST_PATH" "$TARGET_DIR")
  if [[ $? -ne 0 ]]; then
    # Skip if we can't generate a filename (likely due to template errors)
    return 1
  fi

  # Set the full destination path
  local DEST_FULL_PATH="${TARGET_DIR}/${GENERATED_DEST_PATH}"

  # Check that source full path exists
  if [ -e "$SOURCE_FULL_PATH" ]; then
    if generate_target_file "$SOURCE_FULL_PATH" "$DEST_FULL_PATH" "$TARGET_DIR"; then
      # Return the path relative to the target dir
      echo "$GENERATED_DEST_PATH"
      return 0
    else
      return 1
    fi
  else
    log "ERROR: [${SOURCE_FULL_PATH}] not found in source repository"
    return 2
  fi
}

generate_target_filename() {
  local FILENAME="$1"
  local TARGET_REPO_DIR="$2"

  # If it's a plain filename (no templating), return it as is
  if [[ ! "$FILENAME" =~ \{\{.*\}\} ]]; then
    echo "$FILENAME"
    return
  fi

  # Find repo-sync.yml in the target repository
  local REPO_SYNC_YML="${TARGET_REPO_DIR}/repo-sync.yml"
  if [[ ! -f "$REPO_SYNC_YML" ]]; then
    log "ERROR: Template markers found in [$FILENAME] but repo-sync.yml is missing"
    return 1
  fi

  # Create temp file with the filename as content, so we can process it with tpl
  local TEMP_FILE=$(mktemp)
  echo "$FILENAME" > "$TEMP_FILE"

  gomplate --missing-key=zero -f "$TEMP_FILE" -c .="$REPO_SYNC_YML" > "${TEMP_FILE}.out" || {
    # If we can't generate the name, skip handling this file
    log "ERROR: Template processing failed for filename [$FILENAME]"
    rm "$TEMP_FILE" "${TEMP_FILE}.out" 2>/dev/null
    return 1
  }

  # Read the processed name
  local GENERATED_NAME=$(cat "${TEMP_FILE}.out")
  rm "$TEMP_FILE" "${TEMP_FILE}.out"

  if [[ -n "$GENERATED_NAME" ]]; then
    echo "$GENERATED_NAME"
  else
    log "ERROR: Template processing produced empty result for [$FILENAME]"
    return 1
  fi
}

generate_target_file() {
  local SOURCE_FULL_PATH="$1"
  local DEST_FULL_PATH="$2"
  local TARGET_DIR="$3"
  local DEST_FOLDER_PATH="$(dirname "$DEST_FULL_PATH")"

  # Create destination directory if needed
  if [[ ! -d "$DEST_FOLDER_PATH" ]]; then
    mkdir -p "$DEST_FOLDER_PATH"
  fi

  # If the file is not a template, copy it verbatim
  if [[ ! "$SOURCE_FULL_PATH" =~ \.tpl$ ]]; then
    cp -r "${SOURCE_FULL_PATH}" "${DEST_FULL_PATH}"
    return
  fi

  local REPO_SYNC_YML="${TARGET_DIR}/repo-sync.yml"

  # Check if repo-sync.yml exists
  if [[ ! -f "$REPO_SYNC_YML" ]]; then
    log "WARNING: repo-sync.yml not found in target repository, ignoring template file"
    return 1
  fi

  # Process the template
  gomplate --missing-key=zero -f "$SOURCE_FULL_PATH" -c .="$REPO_SYNC_YML" > "$DEST_FULL_PATH" || {
    log "ERROR: Processing template ${SOURCE_FULL_PATH} failed"
    return 1
  }

  # Add a newline to the end of template-generated files (gomplate strips trailing newlines)
  echo >> "$DEST_FULL_PATH"
}

log() {
  echo "$@" >&2
}

#!/bin/bash

# Remember last error code
STATUS=0
trap 'STATUS=$?' ERR

source /functions.sh

# Prepare inputs
REPOSITORIES=($INPUT_REPOSITORIES)
mapfile -t FILES < <(echo "$INPUT_FILES" | grep -v '^$')
REPO_SYNC_SCHEMA_PATH="${GITHUB_WORKSPACE}/${INPUT_REPO_SYNC_SCHEMA_PATH}"
GIT_EMAIL="$INPUT_GIT_EMAIL"
GIT_USERNAME="$INPUT_GIT_USERNAME"
GITHUB_TOKEN="$INPUT_TOKEN"

REPOS_PATH="/repo-sync"
mkdir -p "$REPOS_PATH" && cd "$REPOS_PATH" || {
  echo "ERROR: Failed to prepare repos directory: $REPOS_PATH"
  exit 1
}

git config --system core.longpaths true
git config --global core.longpaths true
git config --global user.email "$GIT_EMAIL" && git config --global user.name "$GIT_USERNAME"

for repository in "${REPOSITORIES[@]}"; do
  echo "::group::📂 $repository"

  IFS="@" read -ra REPO_INFO <<< "$repository"
  REPO_NAME="${REPO_INFO[0]}"

  DEFAULT_BRANCH_NAME=$(curl -X GET -H "Accept: application/vnd.github.v3+json" -u ${USERNAME}:${GITHUB_TOKEN} --silent "${GITHUB_API_URL}/repos/${REPO_NAME}" | jq -r '.default_branch')
  BRANCH_NAME="${REPO_INFO[1]:-$DEFAULT_BRANCH_NAME}"

  REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_NAME}.git"
  REPO_PATH="${REPOS_PATH}/${REPO_NAME}"
  echo "Cloning $REPO_URL ($BRANCH_NAME) to $REPO_PATH"
  git clone --quiet --no-hardlinks --no-tags $REPO_URL $REPO_PATH

  cd $REPO_PATH

  if [[ "$BRANCH_NAME" != "$DEFAULT_BRANCH_NAME" ]]; then
    # Check out remote branch, or create it otherwise
    git fetch && git checkout -b "$BRANCH_NAME" origin/"$BRANCH_NAME" || git checkout -b "$BRANCH_NAME"
  fi

  echo " "

  # Validate repo-sync.yml and handle failures
  validation_result=$(validate_repo_sync_yml "$REPO_PATH" "$REPO_SYNC_SCHEMA_PATH" 2>&1)
  validation_status=$?
  if [[ $validation_status -ne 0 ]]; then
    # Output to log
    echo "ERROR: Invalid repo-sync.yml:"
    echo "$validation_result" | sed 's/^/  /' # Indent for clarity

    # Output to step summary
    echo "⛔ **${repository}** (Invalid repo-sync.yml)" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
    echo "$validation_result" >> $GITHUB_STEP_SUMMARY
    echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY

    cd $REPOS_PATH
    rm -rf $REPO_NAME
    echo "::endgroup::"
    continue
  fi

  # Sync files
  changed_files=()
  for file in "${FILES[@]}"; do
    synced_path=$(sync_file "$file" "$GITHUB_WORKSPACE" "$REPO_PATH")
    sync_result=$?

    if [ $sync_result -eq 0 ] && [ -n "$synced_path" ]; then
      cd "$REPO_PATH"
      git add "$synced_path" -f

      if [[ -n "$(git diff --cached --name-only -- "$synced_path")" ]]; then
        changed_files+=("$synced_path")
      fi
    fi
  done

  cd "$REPO_PATH"
  if [[ -n "$(git status --porcelain)" ]]; then
    # Generate commit message with list of changed files
    commit_msg="File sync from ${GITHUB_REPOSITORY}\n\nUpdated files:\n\n"
    for file in "${changed_files[@]}"; do
      commit_msg+="- $file\n"
    done

    git commit -m "$(echo -e "$commit_msg")" > /dev/null 2>&1
    COMMIT_HASH=$(git rev-parse HEAD)

    echo "🚀 Pushing to ${REPO_URL} (${BRANCH_NAME})"
    git push $REPO_URL > /dev/null 2>&1

    echo "❇️ ${#changed_files[@]} updated files:"
    for file in "${changed_files[@]}"; do
      echo "- $file"
    done

    echo "❇️ **${repository}** (${#changed_files[@]} files in [${COMMIT_HASH:0:7}](https://github.com/${REPO_NAME}/commit/${COMMIT_HASH}))" >> $GITHUB_STEP_SUMMARY
    for file in "${changed_files[@]}"; do
      echo "- \`$file\`" >> $GITHUB_STEP_SUMMARY
    done
    echo >> $GITHUB_STEP_SUMMARY
  else
    echo "⚪ Nothing to update"

    echo "⚪ **${repository}**" >> $GITHUB_STEP_SUMMARY
    echo >> $GITHUB_STEP_SUMMARY
  fi

  cd $REPOS_PATH
  rm -rf $REPO_NAME
  echo "::endgroup::"
done

exit $STATUS

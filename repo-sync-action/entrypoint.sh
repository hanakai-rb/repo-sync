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
PR_NUMBER="$INPUT_PR_NUMBER"
PR_EVENT_TYPE="$INPUT_PR_EVENT_TYPE"
PREVIEW_BRANCH_PREFIX="$INPUT_PREVIEW_BRANCH_PREFIX"

REPOS_PATH="/repo-sync"
mkdir -p "$REPOS_PATH" && cd "$REPOS_PATH" || {
  echo "ERROR: Failed to prepare repos directory: $REPOS_PATH"
  exit 1
}

git config --system core.longpaths true
git config --global core.longpaths true
git config --global user.email "$GIT_EMAIL" && git config --global user.name "$GIT_USERNAME"

sync_repos() {
  local PREVIEW_BRANCH="$1"

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

    # Check out branch for committing sync
    if [[ -n "$PREVIEW_BRANCH" ]]; then
      if create_preview_branch "$REPO_PATH" "$PREVIEW_BRANCH" "$DEFAULT_BRANCH_NAME"; then
        BRANCH_NAME="$PREVIEW_BRANCH"
      else
        echo "ERROR: Failed to create preview branch"
        echo "⛔ **${repository}** - Failed to create preview branch" >> $GITHUB_STEP_SUMMARY
        echo >> $GITHUB_STEP_SUMMARY

        cd $REPOS_PATH
        rm -rf $REPO_NAME
        echo "::endgroup::"
        continue
      fi
    elif [[ "$BRANCH_NAME" != "$DEFAULT_BRANCH_NAME" ]]; then
      git fetch && git checkout -b "$BRANCH_NAME" origin/"$BRANCH_NAME" || git checkout -b "$BRANCH_NAME"
    fi

    # Validate repo-sync.yml and handle failures
    validation_result=$(validate_repo_sync_yml "$REPO_PATH" "$REPO_SYNC_SCHEMA_PATH" 2>&1)
    validation_status=$?
    if [[ $validation_status -ne 0 ]]; then
      echo "ERROR: Invalid repo-sync.yml:"
      echo "$validation_result" | sed 's/^/  /'

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

      echo "Pushing to ${REPO_URL} (${BRANCH_NAME})"
      git push $REPO_URL $BRANCH_NAME > /dev/null 2>&1

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
}

create_preview_branch() {
  local REPO_PATH="$1"
  local PREVIEW_BRANCH="$2"
  local DEFAULT_BRANCH="$3"

  cd "$REPO_PATH" || return 1

  git fetch origin "$DEFAULT_BRANCH" > /dev/null 2>&1

  # Preview branches should always be single-commit only, to mimic the main branch sync. If a
  # branch exists already, delete it and start over.
  if git ls-remote --heads origin "$PREVIEW_BRANCH" | grep -q "$PREVIEW_BRANCH"; then
    git push origin --delete "$PREVIEW_BRANCH" > /dev/null 2>&1
  fi

  git checkout -b "$PREVIEW_BRANCH" "origin/$DEFAULT_BRANCH" > /dev/null 2>&1

  return 0
}

delete_preview_branch() {
  local PREVIEW_BRANCH="$1"

  if git ls-remote --heads origin "$PREVIEW_BRANCH" | grep -q "$PREVIEW_BRANCH"; then
    git push origin --delete "$PREVIEW_BRANCH" > /dev/null 2>&1
    return 0
  else
    return 1
  fi
}

cleanup_preview_branches() {
  local PREVIEW_BRANCH="$1"

  for repository in "${REPOSITORIES[@]}"; do
    echo "::group::📂 $repository"

    IFS="@" read -ra REPO_INFO <<< "$repository"
    REPO_NAME="${REPO_INFO[0]}"
    REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_NAME}.git"
    REPO_PATH="${REPOS_PATH}/${REPO_NAME}"

    echo "Cloning $REPO_URL to $REPO_PATH"
    git clone --quiet --no-hardlinks --no-tags $REPO_URL $REPO_PATH

    cd $REPO_PATH

    echo "🧹 Deleting preview branch: ${PREVIEW_BRANCH}"
    if delete_preview_branch "$PREVIEW_BRANCH"; then
      echo "✅ Preview branch deleted"
      echo "✅ **${repository}** - Preview branch deleted" >> $GITHUB_STEP_SUMMARY
    else
      echo "⚠️  Preview branch not found or already deleted"
      echo "⚠️  **${repository}** - Preview branch not found" >> $GITHUB_STEP_SUMMARY
    fi
    echo >> $GITHUB_STEP_SUMMARY

    cd $REPOS_PATH
    rm -rf $REPO_NAME
    echo "::endgroup::"
  done
}

if [[ -n "$PR_NUMBER" && "$PR_EVENT_TYPE" != "closed" ]]; then
  echo "### 🔄 Sync summary" > $GITHUB_STEP_SUMMARY
  echo >> $GITHUB_STEP_SUMMARY

  PREVIEW_BRANCH="${PREVIEW_BRANCH_PREFIX}-${PR_NUMBER}"
  echo "🔍 Creating preview branches: ${PREVIEW_BRANCH}"
  sync_repos "$PREVIEW_BRANCH"

  # Output the step summary so it can be added as a PR comment
  echo "SYNC_SUMMARY<<EOF" >> $GITHUB_OUTPUT
  cat $GITHUB_STEP_SUMMARY >> $GITHUB_OUTPUT
  echo "EOF" >> $GITHUB_OUTPUT
elif [[ -n "$PR_NUMBER" && "$PR_EVENT_TYPE" == "closed" ]]; then
  PREVIEW_BRANCH="${PREVIEW_BRANCH_PREFIX}-${PR_NUMBER}"
  echo "🧹 Cleaning up preview branches"
  cleanup_preview_branches "$PREVIEW_BRANCH"
else
  sync_repos ""
fi

exit $STATUS

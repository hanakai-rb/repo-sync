#!/bin/bash

STATUS=0

# remember last error code
trap 'STATUS=$?' ERR

# problem matcher must exist in workspace
cp /error-matcher.json $HOME/file-sync-error-matcher.json
echo "::add-matcher::$HOME/file-sync-error-matcher.json"

echo "Repository: [$GITHUB_REPOSITORY]"

# log inputs
echo "Inputs"
echo "---------------------------------------------"
RAW_REPOSITORIES="$INPUT_REPOSITORIES"
RAW_FILES="$INPUT_FILES"
GITHUB_TOKEN="$INPUT_TOKEN"
REPOSITORIES=($RAW_REPOSITORIES)
echo "Repositories    : $REPOSITORIES"
FILES=($RAW_FILES)
echo "Files           : $FILES"
GIT_EMAIL="$INPUT_GIT_EMAIL"
echo "Git email       : $GIT_EMAIL"
GIT_USERNAME="$INPUT_GIT_USERNAME"
echo "Git username    : $GIT_USERNAME"

# set temp path
TEMP_PATH="/ghafs/"
cd /
mkdir "$TEMP_PATH"
cd "$TEMP_PATH"
echo "Temp Path       : $TEMP_PATH"
echo "---------------------------------------------"

echo " "

# initalize git
echo "Initializing git with github-actions[bot]"
git config --system core.longpaths true
git config --global core.longpaths true
git config --global user.email "$GIT_EMAIL" && git config --global user.name "$GIT_USERNAME"
echo "Git initialized"

echo " "

# loop through all the repos
for repository in "${REPOSITORIES[@]}"; do
    echo "::group::$repository"

    # extra arguments to use when pushing changes
    PUSH_ARGS=""

    # determine repo name
    REPO_INFO=($(echo $repository | tr "@" "\n"))
    REPO_NAME=${REPO_INFO[0]}
    echo "Repository name: [$REPO_NAME]"

    REPO_NAME_SPLIT=($(echo $REPO_NAME | tr "/" "\n"))
    ORG_NAME=${REPO_NAME_SPLIT[0]}

    echo "Determining default branch name"
    DEFAULT_BRANCH_NAME=$(curl -X GET -H "Accept: application/vnd.github.v3+json" -u ${USERNAME}:${GITHUB_TOKEN} --silent "${GITHUB_API_URL}/repos/${REPO_NAME}" | jq -r '.default_branch')
    echo "Default branch name: [$DEFAULT_BRANCH_NAME]"

    # determine branch name
    echo "Determining instructed branch name"
    if [ ${REPO_INFO[1]+yes} ]; then
        BRANCH_NAME="${REPO_INFO[1]}"
    else
        BRANCH_NAME="$DEFAULT_BRANCH_NAME"
    fi
    echo "Branch: [$BRANCH_NAME]"

    # clone the repo
    REPO_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_NAME}.git"
    GIT_PATH="${TEMP_PATH}${REPO_NAME}"
    echo "Cloning [$REPO_URL] to [$GIT_PATH]"
    git clone --quiet --no-hardlinks --no-tags $REPO_URL $GIT_PATH

    cd $GIT_PATH

    # checkout the branch, if specified
    if [ "$BRANCH_NAME" != "$DEFAULT_BRANCH_NAME" ]; then
        # try to check out the origin, if fails, then create the local branch
        git fetch && git checkout -b "$BRANCH_NAME" origin/"$BRANCH_NAME" || git checkout -b "$BRANCH_NAME"
    fi

    echo " "
    need_push=false
    # loop through all files
    for file in "${FILES[@]}"; do
        echo "File: [${file}]"
        # split and trim
        FILE_TO_SYNC=($(echo $file | tr "=" "\n"))
        SOURCE_PATH=${FILE_TO_SYNC[0]}
        echo "Source path: [$SOURCE_PATH]"

        # initialize the full path
        SOURCE_FULL_PATH="${GITHUB_WORKSPACE}/${SOURCE_PATH}"
        echo "Source full path: [$SOURCE_FULL_PATH]"

        # set the default of source and destination path the same
        SOURCE_FILE_NAME=$(basename "$SOURCE_PATH")
        echo "Source file name: [$SOURCE_FILE_NAME]"
        DEST_PATH="${SOURCE_FILE_NAME}"
        echo "Destination file path: [$DEST_PATH]"

        # if destination is different, then set it
        if [ ${FILE_TO_SYNC[1]+yes} ]; then
            DEST_PATH="${FILE_TO_SYNC[1]}"
            echo "Destination file path specified: [$DEST_PATH]"
        fi

        # check that source full path isn't null
        if [ "$SOURCE_FULL_PATH" != "" ]; then
            # test path to copy to
            DEST_FULL_PATH="${GIT_PATH}/${DEST_PATH}"
            DEST_FOLDER_PATH=$(dirname "$DEST_FULL_PATH")
            if [ ! -d "$DEST_FOLDER_PATH" ]; then
                echo "Creating [$DEST_FOLDER_PATH]"
                mkdir -p $DEST_FOLDER_PATH
            fi

            if [[ "$SOURCE_FULL_PATH" == *.tpl ]]; then
              # Check if project.toml exists in the target repository
              REPO_SYNC_YML="${GIT_PATH}/repo-sync.yml"
              if [ -f "$REPO_SYNC_YML" ]; then
                echo "Using project.toml from target repository"

                # Process the template and save to destination
                echo "Processing template to: [$DEST_FULL_PATH]"
                tpl --file "$SOURCE_FULL_PATH" --decoder yaml < "$REPO_SYNC_YML" > "$DEST_FULL_PATH"
              else
                echo "WARNING: repo-sync.yml not found in target repository, ignoring file"
              fi
            else
              # copy file verbatim
              echo "Copying: [$SOURCE_FULL_PATH] to [$DEST_FULL_PATH]"
              cp "${SOURCE_FULL_PATH}" "${DEST_FULL_PATH}" -r
            fi

            # add file
            git add "${DEST_FULL_PATH}" -f

            # check if anything is new
            if [ "$(git status --porcelain)" != "" ]; then
                echo "Committing changes"
                git commit -m "File sync from ${GITHUB_REPOSITORY}"
                need_push=true
            else
                echo "Files not changed: [${SOURCE_FILE_NAME}]"
            fi
        else
            echo "[${SOURCE_FULL_PATH}] not found in [${GITHUB_REPOSITORY}]"
        fi
        echo " "
    done

    if [ "$need_push" = true ] ; then
        cd ${GIT_PATH}

        # push changes
        echo "Push changes to [${REPO_URL}]"
        git push $PUSH_ARGS $REPO_URL
    fi

    cd $TEMP_PATH
    rm -rf $REPO_NAME
    echo "Completed [${REPO_NAME}]"
    echo "::endgroup::"
done

exit $STATUS

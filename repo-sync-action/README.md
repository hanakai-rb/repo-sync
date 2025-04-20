# Hanakai repo sync action

Github Action to sync files across Hanakai repos.

# Setup

Create a new file called `/.github/workflows/file-sync.yml` that looks like so:

```yaml
name: File Sync

on:
  push:
    branches:
      - main
  schedule:
    - cron: 0 0 * * *

jobs:
  file_sync:
    runs-on: ubuntu-latest
    steps:
      - name: Fetching Local Repository
        uses: actions/checkout@main
      - name: File Sync
        uses: kbrashears5/github-action-file-sync@v2.0.0
        with:
          REPOSITORIES: |
            username/repo@main
          FILES: |
            sync/dependabot.yml=.github/dependabot.yml
          TOKEN: ${{ secrets.ACTIONS }}
```

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| REPOSITORIES | true | List of repositories to sync the files to. Optionally provide branch name |
| FILES | true | List of files to sync across repositories. See below for details |
| GIT_EMAIL | false | Git email to use |
| GIT_USERNAME | false | Git username to use |
| TOKEN | true | Personal Access Token with repo scope, and workflow scope if managing Actions-related files |

## Examples

### REPOSITORIES parameter

Push to the `main` branch
```yaml
REPOSITORIES: |
    username/repo
```
Push to the `dev` branch
```yaml
REPOSITORIES: |
    username/repo@dev
```
### FILES parameter

<u>File sync</u>

Root file with root destination
```yaml
FILES: |
    dependabot.yml
```
Root file with new destination
```yaml
FILES: |
    dependabot.yml=.github/dependabot.yml
```
Nested file with same nested file structure destination
```yaml
FILES: |
    .github/dependabot.yml
```
Nested file with new destination
```yaml
FILES: |
    sync/dependabot.yml=.github/dependabot.yml
```

<u>Folder Sync</u>

Root folder to root directory
```yaml
FILES: |
    sync
```
Root folder with new directory
```yaml
FILES: |
    sync/=newFolderName/
```

### PULL_REQUEST_BRANCH_NAME parameter

Specify branch name to create pull request against
```yaml
PULL_REQUEST_BRANCH_NAME: main
```

### TOKEN parameter

Use the repository secret named `ACTIONS`
```yaml
TOKEN: ${{ secrets.ACTIONS }}
```

# Troubleshooting

### Spacing

Spacing around the equal sign is important. For example, this will not work:
```yaml
FILES: |
  folder/file-sync.yml = folder/test.txt
```

It passes to the shell file 3 distinct objects
- folder/file-sync.ymll
- =
- folder/test.txt

instead of 1 object

- folder/file-sync.yml = folder/test.txt

and there is nothing I can do in code to make up for that

### Slashes

You do not need (nor want) leading `/` for the file path on either side of the equal sign

The only time you need `/` trailing is for folder copies. While a file copy will technically still work with a leading `/`, a folder copy will not

# ☀️ Hanakai repo sync

[![Sync status](https://github.com/hanakai-rb/repo-sync/actions/workflows/repo-sync.yml/badge.svg)](https://github.com/hanakai-rb/repo-sync/actions/workflows/repo-sync.yml)

A GitHub Action and supporting tooling for synchronizing files across Hanakai repositories in the [hanami](https://github.com/hamami), [dry-rb](https://github.com/dry-rb) and [rom-rb](https://github.com/rom-rb) organizations.

## How does it work?

In [`.github/workflows/repo-sync.yml`](.github/workflows/repo-sync.yml) in this repo, we define a job with a list of repositories and files to be synced across each. For example:

```yaml
repo_sync:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v2
    - name: Sync
      uses: ./repo-sync-action
      with:
        REPOSITORIES: |
          hanami/view
          dry-rb/dry-operation
        FILES: |
          templates/gem/.github/workflows/ci.yml.tpl=.github/workflows/ci.yml
          templates/gem/.rubocop.yml=.rubocop.yml
          templates/gem/README.md.tpl=README.md
          templates/gem/gemspec.rb.tpl={{ .name.gem }}.gemspec
        REPO_SYNC_SCHEMA_PATH: templates/repo-sync-schema.json
        TOKEN: ${{ secrets.REPO_SYNC_TOKEN }}
```

When this action runs, it will:

1. Check out each repository.
2. Validate the repository's `repo-sync.yml` against the configured JSON schema.
3. For each file entry, copy the source file to the destination path within the repository.
    - If the source file has a `.tpl` extension, evaluate the the source file as a [text/template](https://pkg.go.dev/text/template) file using the [`tpl` CLI tool](https://github.com/bluebrown/go-template-cli).
    - The values from `repo-sync.yml` are available within the template.
    - Destination filenames may also use the template syntax.
4. Commit and push the changes directly to each repo's main branch.

## Components

### GitHub Action ([`repo-sync-action/`](repo-sync-action))

A containerized GitHub action that runs the file sync. This is kept simple by design: just bash gluing together a range of focused CLI tools.

[`entrypoint.sh`](repo-sync-action/entrypoint.sh) manages the high-level flow, with most of the logic kept in [`functions.sh`](repo-sync-action/entrypoint.sh), allowing for reuse in local testing.

### Local sync ([`local-sync/`](`local-sync/`) via [`bin/local-sync`](bin/local-sync))

A script to test the file sync against local checkouts of repos. This allows for easy development of templates and sync logic, and avoids the hassle of CI runs and risk of unwanted changes to real repositories.

To provide a faithful as possible reproduction of the GitHub Action, this script runs via Docker (to use the same tools and environment) and invokes the same internal logic from the action's [`functions.sh`](repo-sync-action/entrypoint.sh)

### Templates library ([`templates/`](templates/))

The templates that we sync across our repos. Currently, this is just a single set of templates for our standard Ruby gems. In the future, we may expand this library to cover different repo archetypes.

### RuboCop config ([`rubocop/rubocop.yml`](rubocop/rubocop.yml))

A shared [RuboCop](https://rubocop.org) config used across our repos. This is stored here as a convenience, since it can be referenced directly by the RuboCop configs in each repo, which happen to be synced from [`templates/gem/.rubocop.yml`](templates/gem/.rubocop.yml).

## Usage

### GitHub Action

Manage the workflow file at [`.github/workflows/repo-sync.yml`](.github/workflows/repo-sync.yml). Add to the `REPOSITORIES` and `FILES` lists as needed.

`REPOSITORIES` should be a list of GitHub repository paths:

```yaml
REPOSITORIES: |
  hanami/hanami
  dry-rb/dry-operation
  rom-rb/rom-sql
```

To use a non-default branch, specify the branch name after an `@` delimiter:

```yaml
REPOSITORIES: |
  hanami/hanami@unstable
```

`FILES` should be a list of `<source>=<destination>` pairs, delimited by `=`:

```yaml
FILES: |
  templates/gem/.github/workflows/ci.yml.tpl=.github/workflows/ci.yml
  templates/gem/.rubocop.yml=.rubocop.yml
```

Entire folders may be synced (though for our purposes, it's unlikely we'll need this). Specify folders with a trailing slash:

```yaml
FILES: |
  templates/gem/some-folder/=another-folder/
```

Source files come from this repository, and destination files are created or updated in each target repository listed in `REPOSITORIES`. File paths are all relative to the root of each repository.

You can use template syntax to name destination files using data from each repo's `repo-sync.yml`. See [[template authoring]](#template-authoring) for more details on this syntax.

```yaml
FILES: |
  templates/gem/.github/workflows/ci.yml.tpl=.github/workflows/ci.yml
  templates/gem/.rubocop.yml=.rubocop.yml
  templates/gem/README.md.tpl=README.md
  templates/gem/gemspec.rb.tpl={{ .name.gem }}.gemspec
```

The action runs on:

- Pushes to the main branch
- [Manual triggers](https://github.com/hanakai-rb/repo-sync/actions/workflows/repo-sync.yml)

> [!TIP]
> Later, we should add a daily scheduled run to trigger files changes in response to `repo-sync.yml` changs in each repo. Alternatively, we could sync a dedicated workflow to each repo that triggers a sync in _this_ repo reponse to `repo-sync.yml` being updated.

#### Action parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `REPOSITORIES` | Yes | List of repositories to sync files to (formatted as `owner/repo` or `owner/repo@branch`) |
| `FILES` | Yes | File mappings in `source=destination` format |
| `REPO_SYNC_SCHEMA_PATH` | Yes | Path to JSON schema for validation |
| `TOKEN` | Yes | GitHub access token with "repo" scope, plus "workflow" scope if managing Actions-related files |
| `GIT_EMAIL` | No | Git commit email (default committer is "github-actions[bot]") |
| `GIT_USERNAME` | No | Git commit username (default committer is "github-actions[bot]") |

### Template authoring

Templates with `.tpl` extensions are are evaluated as Go [text/template](https://pkg.go.dev/text/template) files using the [`tpl` CLI tool](https://github.com/bluebrown/go-template-cli).

[`templates/gem/gemspec.rb.tpl`](templates/gem/gemspec.rb.tpl) is our most complex template so far, and a helpful example of what's possible:

```
Gem::Specification.new do |spec|
  spec.name          = "{{ .name.gem }}"
  spec.authors       = ["{{ join "\", \"" .gemspec.authors }}"]
  spec.email         = ["{{ join "\", \"" .gemspec.email }}"]
  spec.license       = "MIT"
  spec.version       = {{ .name.constant }}::VERSION.dup

  spec.summary = "{{ .gemspec.summary }}"
  {{ if .gemspec.description -}}
    spec.description = "{{ .gemspec.description }}"
  {{ else -}}
    spec.description = spec.summary
  {{ end -}}
  spec.homepage      = "https://dry-rb.org/gems/{{ .name.gem }}"
  spec.files         = Dir["{{ join "\", \"" $file_globs }}"]
  spec.bindir        = "bin"
  {{ if eq (len (default (list) .gemspec.executables)) 0 -}}
  spec.executables   = []
  {{ else -}}
  spec.executables   = ["{{ join "\", \"" .gemspec.executables }}"]
  {{ end -}}

  # ...
end
```

Values like `.name.gem` and `.gemspec.summary` come from the values defined in each repo's `repo-sync.yml` file. For example:

```yaml
name:
  gem: hanami-view
gemspec:
  summary: "A super cool view rendering system"
```

Functions like `if`, `eq`, `len`, `default`, `join`, etc. are available from:

- [text/template's built-in functions](https://pkg.go.dev/text/template#hdr-Functions)
- [Sprig functions](https://masterminds.github.io/sprig/)
- [Custom functions](https://github.com/bluebrown/go-template-cli/tree/main/textfunc) built into the `tpl` CLI itself

### Local Testing

To test file sync locally, first make a local clone of a target repository. Then run `bin/local-sync`:

```bash
bin/local-sync /path/to/repository
```

After this, you can verify the changes by running `git diff` in the target repository.

#### Advanced

By default, the `templates/repo-sync-schema.json` JSON schema is used. If you want to use a different schema file, use `--schema`:

```bash
bin/local-sync --schema templates/another-schema.json /path/to/repository
```

The local sync runs in a Docker container defined by [`local-sync/Dockerfile`](local-sync/Dockerfile). If you're developing the tool itself, you can force the container to rebuild with `--rebuild`:

```bash
bin/local-sync --rebuild /path/to/repository
```

To debug the container, enter an interactive shell with `--shell`:

```bash
bin/local-sync --shell /path/to/repository
```

## Development

### Local Development

1. Clone a target repository for testing
2. Make changes to templates or action code
3. Test locally: `bin/local-sync /path/to/repository`
4. Verify changes: `cd /path/to/test/repo && git diff`
5. Commit and push the changes to trigger the GitHub Action and sync files to the real repositories on GitHub.

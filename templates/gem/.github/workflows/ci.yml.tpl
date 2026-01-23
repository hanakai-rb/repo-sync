# This file is synced from hanakai-rb/repo-sync

{{ $ruby_versions := coll.Slice "4.0" "3.4" "3.3" "3.2" -}}
{{ if and .ci .ci.rubies -}}
  {{ range .ci.rubies -}}
    {{ $ruby_versions = $ruby_versions | coll.Append . -}}
  {{ end -}}
{{ end -}}
{{ $default_ruby := index $ruby_versions 0 -}}
{{ $optional_rubies := coll.Slice
  "jruby"
-}}
{{/* Normalize ci.matrix into a dict so we can safely iterate over it later */ -}}
{{ $matrix_dimensions := dict -}}
{{ if and .ci .ci.matrix -}}
  {{ range $key, $values := .ci.matrix -}}
    {{ $matrix_dimensions = merge $matrix_dimensions (dict $key $values) -}}
  {{ end -}}
{{ end -}}
{{ $has_matrix := gt (len $matrix_dimensions) 0 -}}
{{/* Gems using the new release-machine workflow */ -}}
{{ $release_machine_gems := coll.Slice
  "dry-cli"
  "dry-inflector"
  "dry-schema"
  "dry-types"
  "hanami-cli"
-}}
{{ $use_release_machine := has $release_machine_gems .name.gem -}}
name: CI
run-name: {{ print "${{" }} github.ref_type == 'tag' && format('Release {0}', github.ref_name) || 'CI' }}

on:
  push:
    branches: ["main", "release-*", "ci/*"]
    tags: ["v*"]
  pull_request:
    branches: ["main", "release-*"]
  schedule:
    - cron: "30 4 * * *"

jobs:
  tests:
    name: Tests (Ruby {{ print "${{" }} matrix.ruby }}{{ if $has_matrix }}{{ range $key, $values := $matrix_dimensions }}, {{ strings.Title $key }} {{ print "${{" }} matrix.{{ $key }} }}{{ end }}{{ end }})
    runs-on: ubuntu-latest
    continue-on-error: {{ print "${{" }} matrix.optional || false }}
    strategy:
      fail-fast: false
      matrix:
        ruby:
        {{- range $ruby_versions }}
          - "{{ . }}"
        {{- end }}
        {{- if $has_matrix }}
        {{- range $key, $values := $matrix_dimensions }}
        {{ $key }}:
        {{- range $values }}
          - "{{ . }}"
        {{- end }}
        {{- end }}
        {{- end }}
        include:
          {{- if $has_matrix }}
          {{/* Repos WITH matrix dimensions */ -}}
          {{/* Coverage on one job only: default ruby + first value of each dimension */ -}}
          - ruby: "{{ $default_ruby }}"
          {{- range $dim_key, $dim_values := $matrix_dimensions }}
            {{ $dim_key }}: {{ index $dim_values 0 | quote }}
          {{- end }}
            coverage: "true"
          {{- /* Optional rubies: create jobs for each ruby and each dimension combination */ -}}
          {{- range $optional_ruby := $optional_rubies }}
          {{- range $dim_key, $dim_values := $matrix_dimensions }}
          {{- range $dim_values }}
          - ruby: "{{ $optional_ruby }}"
            {{ $dim_key }}: {{ . | quote }}
            optional: true
          {{- end }}
          {{- end }}
          {{- end }}
          {{- else }}
          {{/* Repos WITHOUT matrix dimensions */ -}}
          {{/* Coverage: just the default ruby */ -}}
          - ruby: "{{ $default_ruby }}"
            coverage: "true"
          {{- /* Optional rubies: just a simple list */ -}}
          {{- range $optional_rubies }}
          - ruby: "{{ . }}"
            optional: true
          {{- end }}
          {{- end }}
    env:
      COVERAGE: {{ print "${{" }} matrix.coverage }}
      {{- if $has_matrix }}
      {{- range $key, $values := $matrix_dimensions }}
      {{ strings.ToUpper $key }}_MATRIX_VALUE: {{ print "${{" }} matrix.{{ $key }} || '' }}
      {{- end }}
      {{- end }}
      {{- if file.Exists ".github/workflows/repo-sync-extensions/ci-env.yml" }}
      # Env below included from ./repo-sync-extensions/ci-env.yml
{{ file.Read ".github/workflows/repo-sync-extensions/ci-env.yml" | strings.TrimSpace | strings.Indent 6 }}
      {{- end }}
    {{- if file.Exists ".github/workflows/repo-sync-extensions/ci-services.yml" }}
    # Services included from ./repo-sync-extensions/ci-services.yml
    services:
{{ file.Read ".github/workflows/repo-sync-extensions/ci-services.yml" | strings.TrimSpace | strings.Indent 6 }}
    {{- end }}
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: Install package dependencies
        run: "[ -e $APT_DEPS ] || sudo apt-get install -y --no-install-recommends $APT_DEPS"
      {{ if and .ci .ci.node -}}
      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: 20.x
      - name: Install dependencies
        run: npm install
      {{ end -}}
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: {{ print "${{" }} matrix.ruby }}
          bundler-cache: true
        {{- if $has_matrix }}
        env:
          {{- range $key, $values := $matrix_dimensions }}
          {{ strings.ToUpper $key }}_MATRIX_VALUE: {{ print "${{" }} matrix.{{ $key }} || '' }}
          {{- end }}
        {{- end }}
      - name: Run all tests
        id: test
        run: |
          status=0
          bundle exec rake || status=$?
          if [ ${status} -ne 0 ] && [ "{{ print "${{" }} matrix.optional }}" == "true" ]; then
            echo "::warning::Optional matrix job failed."
            echo "optional_fail=true" >> "${GITHUB_OUTPUT}"
            echo "optional_fail_status=${status}" >> "${GITHUB_OUTPUT}"
            exit 0  # Ignore error here to keep the green checkmark
          fi
          exit ${status}
        {{- if $has_matrix }}
        env:
          {{- range $key, $values := $matrix_dimensions }}
          {{ strings.ToUpper $key }}_MATRIX_VALUE: {{ print "${{" }} matrix.{{ $key }} || '' }}
          {{- end }}
        {{- end }}
      - name: Create optional failure comment
        if: {{ print "${{" }} matrix.optional && github.event.pull_request }}
        uses: hanakai-rb/repo-sync/pr-comment-artifact@main
        with:
          name: ci-ruby-{{ print "${{" }} matrix.ruby }}
          pr-number: {{ print "${{" }} github.event.pull_request.number }}
          comment-tag: ruby-{{ print "${{" }} matrix.ruby }}-optional-failure
          message: "ℹ️ Optional job failed: Ruby {{ print "${{" }} matrix.ruby }}"
          mode: {{ print "${{" }} steps.test.outputs.optional_fail == 'true' && 'upsert' || 'delete' }}

  workflow-keepalive:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    permissions:
      actions: write
    steps:
      - uses: liskin/gh-workflow-keepalive@v1
  {{- if $use_release_machine }}

  release:
    runs-on: ubuntu-latest
    if: github.ref_type == 'tag'
    needs: tests
    steps:
      - name: Trigger release workflow
        uses: actions/github-script@v7
        with:
          github-token: {{ print "${{" }} secrets.RELEASE_MACHINE_DISPATCH_TOKEN }}
          script: |
            const tag = context.ref.replace("refs/tags/", "");
            const repo = context.repo.owner + "/" + context.repo.repo;

            const tagMessage = await github.rest.git.getTag({
              owner: context.repo.owner,
              repo: context.repo.repo,
              tag_sha: context.sha
            }).then(res => res.data.message).catch(() => "");
            const announce = /(skip-announce|no-announce)/i.test(tagMessage) ? "false" : "true";

            await github.rest.actions.createWorkflowDispatch({
              owner: "hanakai-rb",
              repo: "release-machine",
              workflow_id: "release.yml",
              ref: "main",
              inputs: { repo, tag, announce }
            });

            const workflowUrl = "https://github.com/hanakai-rb/release-machine/actions/workflows/release.yml";
            await core.summary
              .addHeading("Release Triggered")
              .addRaw(`Triggered release workflow for <code>${tag}</code>`)
              .addLink("View release workflow", workflowUrl)
              .write();
  {{- else if eq .github_org "dry-rb" }}

  release:
    runs-on: ubuntu-latest
    if: github.ref_type == 'tag'
    needs: tests
    env:
      GITHUB_LOGIN: dry-bot
      GITHUB_TOKEN: {{ print "${{" }}secrets.GH_PAT}}
    steps:
      - uses: actions/checkout@v3
      - name: Install package dependencies
        run: "[ -e $APT_DEPS ] || sudo apt-get install -y --no-install-recommends $APT_DEPS"
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3
      - name: Install dependencies
        run: gem install ossy --no-document
      - name: Trigger release workflow
        run: |
          tag=$(echo $GITHUB_REF | cut -d / -f 3)
          ossy gh w dry-rb/devtools release --payload "{\"tag\":\"$tag\",\"sha\":\"{{ print "${{" }}github.sha}}\",\"tag_creator\":\"$GITHUB_ACTOR\",\"repo\":\"$GITHUB_REPOSITORY\",\"repo_name\":\"{{ print "${{" }}github.event.repository.name}}\"}"
  {{ end }}

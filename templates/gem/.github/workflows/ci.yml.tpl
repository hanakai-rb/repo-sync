# This file is synced from hanakai-rb/repo-sync

{{ $ruby_versions := concat (list "3.4" "3.3" "3.2") (.ci.rubies | default (list)) }}
name: CI

on:
  push:
    branches: ["main"]
    tags: ["v*"]
  pull_request:
    branches: ["main"]
  schedule:
    - cron: "30 4 * * *"

jobs:
  tests:
    name: Tests ({{ print "${{" }} matrix.ruby }})
    permissions:
      pull-requests: write
    runs-on: ubuntu-latest
    continue-on-error: {{ print "${{" }} matrix.optional }}
    strategy:
      fail-fast: false
      matrix:
        ruby:
        {{ range $ruby_versions -}}
        - "{{ . }}"
        {{ end -}}
        optional: [false]
        include:
          - ruby: "3.4"
            coverage: "true"
          - ruby: "jruby"
            optional: true
    env:
      COVERAGE: {{ print "${{" }}matrix.coverage}}
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: Install package dependencies
        run: "[ -e $APT_DEPS ] || sudo apt-get install -y --no-install-recommends $APT_DEPS"
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: {{ print "${{" }}matrix.ruby}}
          bundler-cache: true
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
      - name: Add comment for optional failures
        uses: thollander/actions-comment-pull-request@v3
        if: {{ print "${{" }} matrix.optional && github.event.pull_request }}
        with:
          comment-tag: "{{ print "${{" }} matrix.ruby }}-optional-failure-notice"
          message: |
            ℹ️ Optional job failed: Ruby {{ print "${{" }} matrix.ruby }}
          mode: {{ print "${{" }} steps.test.outputs.optional_fail == 'true' && 'upsert' || 'delete' }}

  workflow-keepalive:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    permissions:
      actions: write
    steps:
      - uses: liskin/gh-workflow-keepalive@v1
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

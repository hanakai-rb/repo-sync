# This file is synced from hanakai-rb/repo-sync

{{ $ruby_versions := concat (list "3.4" "3.3" "3.2") (.ci.rubies | default (list)) }}
name: CI

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]
  schedule:
    - cron: "30 4 * * *"

jobs:
  tests:
    runs-on: ubuntu-latest
    name: Tests
    strategy:
      fail-fast: false
      matrix:
        ruby:
        {{ range $ruby_versions -}}
        - "{{ . }}"
        {{ end -}}
        include:
          - ruby: "3.4"
            coverage: "true"
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
        run: bundle exec rake
  workflow-keepalive:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    permissions:
      actions: write
    steps:
      - uses: liskin/gh-workflow-keepalive@v1
  release:
    runs-on: ubuntu-latest
    if: contains(github.ref, 'tags') && github.event_name == 'create'
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

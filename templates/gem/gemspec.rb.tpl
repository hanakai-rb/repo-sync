{{ $gem_path := .name.gem | replace "-" "/" -}}
{{ $default_files := list "CHANGELOG.md" "LICENSE" "README.md" (printf "%s.gemspec" .name.gem) "lib/**/*" -}}
{{ $file_globs := concat $default_files (.gemspec.files | default (list)) -}}

# frozen_string_literal: true

# This file is synced from hanakai-rb/repo-sync. To update it, edit repo-sync.yml.

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "{{ $gem_path }}/version"

Gem::Specification.new do |spec|
  spec.name          = "{{ .name.gem }}"
  spec.authors       = ["{{ join "\", \"" .gemspec.authors }}"]
  spec.email         = ["{{ join "\", \"" .gemspec.email }}"]
  spec.license       = "MIT"
  spec.version       = {{ .name.constant }}::VERSION.dup

  spec.summary       = "{{ .gemspec.summary }}"
  {{ if .gemspec.description }}{{ if gt (len .gemspec.description) 100 }}spec.description   = <<~TEXT
{{ .gemspec.description | trim | trimSuffix "\n" | indent 4 }}
  TEXT{{ else }}spec.description   = "{{ .gemspec.description }}"{{ end }}{{ else }}spec.description   = spec.summary{{ end }}
  spec.homepage      = "{{ .gemspec.homepage }}"
  spec.files         = Dir["{{ join "\", \"" $file_globs }}"]
  spec.bindir        = "bin"
  {{ if eq (len (default (list) .gemspec.executables)) 0 -}}
  spec.executables   = []
  {{ else -}}
  spec.executables   = ["{{ join "\", \"" .gemspec.executables }}"]
  {{ end -}}
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = ["README.md", "CHANGELOG.md", "LICENSE"]

  {{ $github_path := printf "%s/%s" .github_org .name.gem -}}
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["changelog_uri"]     = "https://github.com/{{ $github_path }}/blob/main/CHANGELOG.md"
  spec.metadata["source_code_uri"]   = "https://github.com/{{ $github_path }}"
  spec.metadata["bug_tracker_uri"]   = "https://github.com/{{ $github_path }}/issues"
  spec.metadata["funding_uri"]       = "https://github.com/sponsors/hanami"

  spec.required_ruby_version = "{{ default ">= 3.2" .gemspec.required_ruby_version }}"
{{ range default (list) .gemspec.runtime_dependencies }}
  spec.add_runtime_dependency "{{ join "\", \"" . }}"{{ end -}}
  {{ range default (list) .gemspec.development_dependencies }}
  {{ $dependency := (kindIs "slice" .) | ternary . (list .) }}spec.add_development_dependency "{{ join "\", \"" $dependency }}"{{ end }}
end

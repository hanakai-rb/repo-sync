<!--- This file is synced from hanakai-rb/repo-sync -->

[rubygem]: https://rubygems.org/gems/{{ .name.gem }}
[actions]: https://github.com/{{ .github_org }}/{{ .name.gem }}/actions

# {{ .name.gem }} is really very super cool [![Gem Version](https://badge.fury.io/rb/{{ .name.gem }}.svg)][rubygem] [![CI Status](https://github.com/{{ .github_org }}/{{ .name.gem }}/workflows/CI/badge.svg)][actions]

## Links

- [User documentation]({{ .gemspec.homepage }})
- [API documentation](http://rubydoc.info/gems/{{ .name.gem }})
{{ if eq .github_org "dry-rb" -}}
- [Forum](https://discourse.dry-rb.org)
{{- end }}

## License

See `LICENSE` file.

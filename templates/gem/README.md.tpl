<!--- This file is synced from hanakai-rb/repo-sync -->

[rubygem]: https://rubygems.org/gems/{{ .name }}
[actions]: https://github.com/{{ .github_org }}/{{ .name }}/actions

# <%= name %> [![Gem Version](https://badge.fury.io/rb/{{ .name }}.svg)][rubygem] [![CI Status](https://github.com/{{ .github_org }}/{{ .name }}/workflows/CI/badge.svg)][actions]

{{ if eq .github_org "dry-rb" -}}
## Links

- [User documentation](https://<%= org %>.org/gems/<%= name %>)
- [API documentation](http://rubydoc.info/gems/<%= name %>)
- [Forum](https://discourse.dry-rb.org)
{{- end }}

## Supported Ruby versions

This library officially supports the following Ruby versions:

- MRI >= 3.1

## License

See `LICENSE` file.

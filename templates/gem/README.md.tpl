<!--- This file is synced from hanakai-rb/repo-sync -->

{{ $repo_name := .github_repo | default .name.gem -}}
[actions]: https://github.com/{{ .github_org }}/{{ $repo_name }}/actions
[chat]: https://discord.gg/naQApPAsZB
[forum]: https://discourse.hanamirb.org
[rubygem]: https://rubygems.org/gems/{{ .name.gem }}

# {{ .name.title | default .name.gem }} [![Gem Version](https://badge.fury.io/rb/{{ .name.gem }}.svg)][rubygem] [![CI Status](https://github.com/{{ .github_org }}/{{ $repo_name }}/workflows/CI/badge.svg)][actions]

[![Forum](https://img.shields.io/badge/Forum-dc360f?logo=discourse&logoColor=white)][forum]
[![Chat](https://img.shields.io/badge/Chat-717cf8?logo=discord&logoColor=white)][chat]

{{ if (file.Exists "README.repo.md") -}}
{{ file.Read "README.repo.md" }}
{{ end -}}
## Links

- [User documentation]({{ .gemspec.homepage }})
- [API documentation](http://rubydoc.info/gems/{{ .name.gem }})
{{ if eq .github_org "dry-rb" -}}
- [Forum](https://discourse.dry-rb.org)
{{- end }}

## License

See `LICENSE` file.

<!--- This file is synced from hanakai-rb/repo-sync -->

{{ $repo_name := .github_repo | default .name.title -}}
[actions]: https://github.com/{{ .github_org }}/{{ $repo_name }}/actions
[chat]: https://discord.gg/naQApPAsZB
[forum]: https://discourse.hanamirb.org
[npm]: https://www.npmjs.com/package/{{ .name.package }}

# {{ .name.title }} [![npm Version](https://img.shields.io/npm/v/{{ .name.package }}.svg)][npm] [![CI Status](https://github.com/{{ .github_org }}/{{ $repo_name }}/workflows/CI/badge.svg)][actions]

[![Forum](https://img.shields.io/badge/Forum-dc360f?logo=discourse&logoColor=white)][forum]
[![Chat](https://img.shields.io/badge/Chat-717cf8?logo=discord&logoColor=white)][chat]

{{ if (file.Exists "README.repo.md") -}}
{{ file.Read "README.repo.md" }}
{{ end -}}
{{ if .homepage -}}
## Links

- [User documentation]({{ .homepage }})

{{ end -}}
## License

See `LICENSE` file.

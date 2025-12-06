# https://pkgs.alpinelinux.org/packages
FROM alpine:latest

# Install bash (for running the script)
RUN apk add --no-cache bash

# Install git (for working with repositories)
RUN apk add git

# Install jq (for creating JSON for the GitHub API)
RUN apk add jq

# Install curl (for the downloads below, plus using the GitHub API)
RUN apk add curl

# Install yajsv (for validating repo-sync.yml files)
RUN curl -fsSL https://github.com/neilpa/yajsv/releases/download/v1.4.1/yajsv.linux.amd64 -o /usr/local/bin/yajsv && \
  chmod 755 /usr/local/bin/yajsv

# Install yq (for converting repo-sync.yml to JSON for validation)
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.27.5/yq_linux_amd64 > /usr/local/bin/yq && \
  chmod 755 /usr/local/bin/yq

# Install gomplate (for rendering templates)
RUN curl -fsSL https://github.com/hairyhenderson/gomplate/releases/download/v4.3.3/gomplate_linux-amd64 > /usr/local/bin/gomplate && \
  chmod 755 /usr/local/bin/gomplate

COPY functions.sh /functions.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod 777 entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

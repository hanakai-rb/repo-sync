FROM alpine:3.18

RUN apk add curl

# Install yajsv (for validating repo-sync.yml files)
RUN curl -fsSL https://github.com/neilpa/yajsv/releases/download/v1.4.1/yajsv.linux.amd64 -o /usr/local/bin/yajsv && \
  chmod 755 /usr/local/bin/yajsv

# Install yq (for converting repo-sync.yml to JSON for validation)
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.27.5/yq_linux_amd64 > /usr/local/bin/yq && \
  chmod 755 /usr/local/bin/yq

# Install go-template-cli (the tpl command, for rendering templates)
RUN curl -fsSL https://github.com/bluebrown/go-template-cli/releases/download/v0.3.2/tpl-linux-amd64-static > /usr/local/bin/tpl && \
  chmod 755 /usr/local/bin/tpl

# Install bash, for our scripts
RUN apk add --no-cache bash

WORKDIR /workspace

ENTRYPOINT ["/workspace/local-sync/entrypoint.sh"]

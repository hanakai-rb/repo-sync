FROM alpine:3.18

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

# Install bash, for our scripts
RUN apk add --no-cache bash

WORKDIR /workspace

ENTRYPOINT ["/workspace/local-sync/entrypoint.sh"]

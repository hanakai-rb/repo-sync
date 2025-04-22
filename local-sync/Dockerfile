FROM alpine:3.18

# Install yq
RUN wget https://github.com/mikefarah/yq/releases/download/v4.35.2/yq_linux_amd64 -O /usr/bin/yq && \
  chmod +x /usr/bin/yq

# Install go-template-cli (tpl)
RUN wget https://github.com/bluebrown/go-template-cli/releases/download/v0.3.2/tpl-linux-amd64-static -O /usr/bin/tpl && \
  chmod +x /usr/bin/tpl

# Install bash, for our scripts
RUN apk add --no-cache bash

WORKDIR /workspace

ENTRYPOINT ["/workspace/local-sync/entrypoint.sh"]

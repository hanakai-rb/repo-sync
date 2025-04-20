# https://pkgs.alpinelinux.org/packages
FROM alpine:latest

RUN apk add --no-cache bash

RUN apk add git

# add jq for creating json
RUN apk add jq

# add curl for pull requests via github api
RUN apk add curl

# install go-template-cli for template processing
RUN curl -fsSL https://github.com/bluebrown/go-template-cli/releases/download/v0.3.2/tpl-linux-amd64-static > /usr/local/bin/tpl && \
  chmod 755 /usr/local/bin/tpl

COPY error-matcher.json /error-matcher.json

COPY entrypoint.sh /entrypoint.sh

RUN chmod 777 entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

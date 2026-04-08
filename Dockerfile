FROM alpine:3

ARG SUPERCRONIC_VERSION="0.2.44"
ARG SUPERCRONIC_ARCH="linux-amd64"

# Install bash, ssh client, and 7zip
RUN apk update && apk add --no-cache bash openssh-client 7zip tzdata curl

ENV \
  SUPERCRONIC_URL="https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-${SUPERCRONIC_ARCH}" \
  SUPERCRONIC="supercronic-${SUPERCRONIC_ARCH}"

# Download and install Supercronic
RUN \
  curl -fsSLO "$SUPERCRONIC_URL" \
  && chmod +x "$SUPERCRONIC" \
  && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
  && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

COPY backup.sh /app/backup.sh
COPY extract.sh /app/extract.sh
COPY entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/*.sh

ENTRYPOINT ["/app/entrypoint.sh"]

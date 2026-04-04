FROM alpine:latest

# Install bash, ssh client, and 7zip
RUN apk update && apk add --no-cache bash openssh-client 7zip tzdata

WORKDIR /app
COPY backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

CMD ["/app/backup.sh"]
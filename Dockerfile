FROM alpine:3.10

RUN apk add --no-cache git ssh

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

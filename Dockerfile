FROM alpine:3.10

RUN apk add --no-cache git
RUN apk add --update --no-cache openssh

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

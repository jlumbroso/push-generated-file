FROM alpine:3.10

RUN apk add --no-cache git
RUN apk add --update --no-cache openssh
RUN apk add --no-cache bind-tools \
  && ssh-keyscan github.com > /etc/ssh/ssh_known_hosts \
  && dig -t a +short github.com | grep ^[0-9] | xargs -r -n1 ssh-keyscan >> /etc/ssh/ssh_known_hosts \
  && apk del bind-tools

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

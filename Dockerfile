FROM alpine:3.10

# Install recent versions of `git' and `ssh'
# (with --no-cache the package index is not stored locally, keeping the container small)
# https://stackoverflow.com/a/49119046/408734 

RUN apk add --update --no-cache git openssh

# Adding VCS websites to SSH's known_hosts (thx @mike-es)
# https://github.com/nodejs/docker-node/issues/1215#issuecomment-589971887

RUN apk add --no-cache bind-tools \
  # GitHub known hosts
  && ssh-keyscan github.com > /etc/ssh/ssh_known_hosts \
  && dig -t a +short github.com | grep ^[0-9] | xargs -r -n1 ssh-keyscan >> /etc/ssh/ssh_known_hosts \
  # GitLab known hosts
  && ssh-keyscan gitlab.com >> /etc/ssh/ssh_known_hosts \
  && dig -t a +short gitlab.com | grep ^[0-9] | xargs -r -n1 ssh-keyscan >> /etc/ssh/ssh_known_hosts \
  # BitBucket known hosts (FIXME: seems to be causing issues, so commenting out for now)
  ##&& ssh-keyscan bitbucket.com >> /etc/ssh/ssh_known_hosts \
  ##&& dig -t a +short bitbucket.com | grep ^[0-9] | xargs -r -n1 ssh-keyscan >> /etc/ssh/ssh_known_hosts \
  && apk del bind-tools

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

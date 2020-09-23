FROM linkyard/alpine-helm:2.16.7
LABEL maintainer "mario.siegenthaler@linkyard.ch"

RUN apk add --update --upgrade --no-cache jq bash curl git gettext libintl

ENV KUBERNETES_VERSION 1.16.9
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl; \
  chmod +x /usr/local/bin/kubectl

# this part is required to add support for AWS EKS authentication
# we use the AWS CLI v1 because the v2 installer doesn't support alpine based
# docker images: https://github.com/aws/aws-cli/issues/4685#issuecomment-556436861
RUN apk add --update --upgrade --no-cache python3
RUN python3 -m pip install --no-cache-dir --upgrade --progress-bar off awscli

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

RUN mkdir -p "$(helm home)/plugins"
RUN helm plugin install https://github.com/databus23/helm-diff && \
  helm plugin install https://github.com/rimusz/helm-tiller

ENTRYPOINT [ "/bin/bash" ]

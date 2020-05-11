FROM alpine/helm:2.14.3
LABEL maintainer "mario.siegenthaler@linkyard.ch"

RUN apk add --update --upgrade --no-cache jq bash curl git gettext libintl

ENV KUBERNETES_VERSION 1.16.9
ENV HELMFILE_LATEST_VERSION=0.114.0
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl; \
  chmod +x /usr/local/bin/kubectl && \
  curl -L -o /usr/local/bin/helmfile https://github.com/roboll/helmfile/releases/download/v${HELMFILE_LATEST_VERSION}/helmfile_linux_amd64 && \
  chmod +x /usr/local/bin/helmfile

RUN mkdir -p "$(helm home)/plugins"
RUN helm plugin install https://github.com/databus23/helm-diff && \
  helm plugin install https://github.com/rimusz/helm-tiller && \
  helm plugin install https://github.com/aslafy-z/helm-git

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

ENTRYPOINT [ "/bin/bash" ]

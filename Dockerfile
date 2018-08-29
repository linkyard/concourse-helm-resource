FROM linkyard/docker-helm:2.10.0
LABEL maintainer "mario.siegenthaler@linkyard.ch"

RUN apk add --update --upgrade --no-cache jq bash nodejs curl yarn

ARG KUBERNETES_VERSION=1.10.4
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/local/bin/kubectl

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

RUN mkdir -p "$(helm home)/plugins"
RUN helm plugin install https://github.com/databus23/helm-diff

ENTRYPOINT [ "/bin/bash" ]

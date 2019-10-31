FROM linkyard/docker-helm:2.14.1
LABEL maintainer "Liquid Devops"

RUN apk add --update --upgrade --no-cache jq bash curl

ENV KUBERNETES_VERSION=1.14.6
ENV HELMFILE_LATEST_VERSION=0.90.0
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    curl -L -o /usr/local/bin/helmfile https://github.com/roboll/helmfile/releases/download/v${HELMFILE_LATEST_VERSION}/helmfile_linux_amd64 && \
    chmod +x /usr/local/bin/helmfile

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

RUN mkdir -p "$(helm home)/plugins"
RUN helm plugin install https://github.com/databus23/helm-diff && \
    helm plugin install https://github.com/rimusz/helm-tiller

ENTRYPOINT [ "/bin/bash" ]

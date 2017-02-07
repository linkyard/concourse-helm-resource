FROM linkyard/docker-helm:latest
MAINTAINER Mario Siegenthaler <mario.siegenthaler@linkyard.ch>

RUN apk add --update --no-cache jq bash

ENV KUBERNETES_VERSION 1.5.2
RUN apk --no-cache add ${runDependencies}; \
    curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/local/bin/kubectl

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

ENTRYPOINT [ "/bin/bash" ]

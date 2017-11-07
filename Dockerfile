FROM linkyard/docker-helm:2.7.0
MAINTAINER Mario Siegenthaler <mario.siegenthaler@linkyard.ch>

RUN apk add --update --upgrade --no-cache jq bash nodejs curl yarn

ENV KUBERNETES_VERSION 1.8.2
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/local/bin/kubectl

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

ENTRYPOINT [ "/bin/bash" ]

FROM alpine as builder

USER root

RUN mkdir -p /usr/src/app \
    && apk update \
    && apk add python3 py3-pip \
    && pip3 install mkdocs mkdocs-material

WORKDIR /usr/src/app

ADD . /usr/src/app

RUN mkdocs build

FROM registry.access.redhat.com/rhscl/httpd-24-rhel7

LABEL org.opencontainers.image.source https://github.com/kameshsampath/gloo-edge-eks-a-demo

COPY --from=builder /usr/src/app/site/ /var/www/html/

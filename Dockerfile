FROM ghcr.io/kameshsampath/mkdocs-builder as builder

RUN pip3 install -U mkdocs mkdocs-material

ADD . /usr/src/app

RUN mkdocs build

FROM registry.access.redhat.com/rhscl/httpd-24-rhel7

LABEL org.opencontainers.image.source https://github.com/kameshsampath/gloo-edge-eks-a-demo

COPY --from=builder /usr/src/app/site/ /var/www/html/

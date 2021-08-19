FROM ghcr.io/kameshsampath/mkdocs-builder as builder

RUN pip3 install -U mkdocs mkdocs-material \
    && mkdir -p /build

ADD . /build

WORKDIR /build

RUN mkdocs build

FROM registry.access.redhat.com/rhscl/httpd-24-rhel7

LABEL org.opencontainers.image.source https://github.com/kameshsampath/gloo-edge-eks-a-demo

COPY --from=builder /build/site/ /var/www/html/

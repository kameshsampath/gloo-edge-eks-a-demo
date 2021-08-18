FROM registry.access.redhat.com/rhscl/httpd-24-rhel7

LABEL org.opencontainers.image.source https://github.com/kameshsampath/gloo-edge-eks-a-demo

COPY site/ /var/www/html/

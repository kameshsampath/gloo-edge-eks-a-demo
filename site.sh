#!/bin/bash

mkdocs build

docker build -t ghcr.io/kameshsampath/gloo-edge-demo-site .

TAG=$(date '+%d-%b-%Y')

docker tag ghcr.io/kameshsampath/gloo-edge-demo-site "ghcr.io/kameshsampath/gloo-edge-demo-site:$TAG"

docker push ghcr.io/kameshsampath/gloo-edge-demo-site
docker push "ghcr.io/kameshsampath/gloo-edge-demo-site:$TAG"

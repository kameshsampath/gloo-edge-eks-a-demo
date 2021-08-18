#!/bin/bash

mkdocs build

docker build -t ghcr.io/kameshsampath/gloo-edge-demo-site .

docker push ghcr.io/kameshsampath/gloo-edge-demo-site

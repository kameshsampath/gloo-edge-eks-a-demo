# EKS-A Demo with Gloo Edge

This is a simple demonstration of how to get started with `EKS-A` and `Gloo Edge`. T
This instructions accompany the [Get Started with Gloo Edge on eks-A](https://www.solo.io/blog/gloo-edge-on-eks-a).

## Run Doc site

```shell
docker run --rm --name=gloo-edge-eks-demo-site -p 7070:8080 ghcr.io/kameshsampath/gloo-edge-demo-site
```

The documentation site is now accessible via [localhost:7070](http://localhost:7070)

## Build and Run Local site

Install dependencies,

```shell
pip install mkdocs && pip install mkdocs-material
```

Start local site

```shell
mkdocs serve
```

You can now access site via http://localhost:8000/gloo-edge-eks-a-demo

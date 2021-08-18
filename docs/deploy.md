# Deploy App

## Clone Demo Sources

```shell
git clone git@github.com:kameshsampath/gloo-edge-eks-a-demo.git
export DEMO_HOME="$(pwd)/gloo-edge-eks-a-demo"
```

## Deploy Database

```shell
kubectl apply -k $DEMO_HOME/apps/manifests/fruits-api/db
```

Wait for the DB to be up

```shell
kubectl rollout status -n db deploy/postgresql --timeout=60s
```

## Deploy REST API

```shell
kubectl apply -k $DEMO_HOME/apps/manifests/fruits-api/app
```

Wait for the REST API to be up

```shell
kubectl rollout status -n fruits-app deploy/fruits-api --timeout=60s
```

## Gloo Edge

### Upstreams

Check if the upsteram is available

```shell
glooctl get upstream fruits-app-fruits-api-8080
```

```text
-----------------------------------------------------------------------------+
|          UPSTREAM          |    TYPE    |  STATUS  |          DETAILS          |
-----------------------------------------------------------------------------+
| fruits-app-fruits-api-8080 | Kubernetes | Accepted | svc name:      fruits-api |
|                            |            |          | svc namespace: fruits-app |
|                            |            |          | port:          8080       |
|                            |            |          |                           |
-----------------------------------------------------------------------------+
```

### Gateways

Deploy the gateway,

```shell
kubectl apply -n gloo-system -f $DEMO_HOME/apps/manifests/fruits-api/gloo/gateway
```

Check the status of the virtual service

```shell
glooctl get vs fruits-api
```

```text
----------------------------------------------------------------------------------------------
| VIRTUAL SERVICE | DISPLAY NAME | DOMAINS | SSL  |  STATUS  | LISTENERPLUGINS |       ROUTES        |
----------------------------------------------------------------------------------------------
| fruits-api      |              | *       | none | Accepted |                 | / -> 1 destinations |
----------------------------------------------------------------------------------------------
```

Set the Gloo proxy url to environment variable,

```shell
export GLOO_PROXY_URL=$($(glooctl proxy url)
```

Check if the API is accessible,

```shell
http $(glooctl proxy url)/api/fruits
```

The command should return a list of fruits as shown,

```json

```

## Build and Deploy UI

```shell
docker build --build-arg="GLOO_PROXY_URL=$GLOO_PROXY_URL" -t example/fruits-ui -f Dockerfile-UI .
```

Run the UI application,

```shell
docker run -it -p8085:8080 --rm example/fruits-ui
```

## Authentication

## Rate Limit

## Console

# Gloo Edge on EKS-A in 5 minutes

## Overview

In my personal opinion there is always a myth that API Gateways are for cloud or can only with be used with public cloud providers. But that is not the truth, API Gateways are suited for any architecture public, private or hybrid cloud. The only basic requirement for it is to have API ;).

[Gloo Edge](https://www.solo.io/products/gloo-edge/) is an open-source, flexible and extensible API Gateway built on Envoy Proxy for microservices environments. Gloo Edge configures the behavior of the Envoy Proxy data plane to ensure secure application connectivity and policy based traffic management.

![Gloo Edge](images/blog_feature.png){align=center}

In this blog post, let us burst the myth and explore how we can setup API Gateway with Gloo Edge in *hybrid cloud* infrastructure with EKS-A and connect a AWS Lambda function using Gloo Edge.

## What we need ?

### Cloud Infrastructure

- [VMWare Cloud](https://vmc.vmware.com){target=_blank} - Infrastructure to deploy `eks-a`Kubernetes cluster.

[AWS Account](https://aws.amazon.com){target=_blank} - An AWS account with permissions to create and execute AWS Lambda Function.

### Tools

- [eks-a](https://example.com/eks-a){target=_blank}
- [glooctl](https://docs.solo.io/gloo-edge/latest/getting_started/){target=_blank}
- [jq](https://stedolan.github.io/jq/){target=_blank}
- [kubectl](https://kubectl.docs.kubernetes.io/installation/kubectl/){target=_blank}
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/){target=_blank}

Lastly you might need *Gloo Edge Enterprise License Key* to deploy Gloo Edge on to the eks-a infrastructure.

## Demo Sources

Clone the demo sources from the GitHub respository,

```shell
git clone https://github.com/kameshsampath/gloo-edge-eks-a-demo
cd gloo-edge-eks-a-demo
```

For convinience, we will refer the clone demo sources folder as `$DEMO_HOME`,

```shell
export DEMO_HOME="$(pwd)"
```

## Ensure Environment

We will set the following environment variables for convinience and we will be referring to these variables in upcoming sections.

```shell
export AWS_ACCESS_KEY_ID=<your aws access key>
export AWS_SECRET_ACCESS_KEY=<your aws secret key>
export AWS_DEFAULT_REGION=<the aws region to use for the resources>
```

## EKS-A Cluster

To create the EKS cluster run the follwing command,

```shell
eks-a create cluster -f gloo-edge.yaml # (1)
```

1. `gloo-edge.yaml`- will be generated using the `eks-a generate` command. For more information on the command please refer to {== **TODO** Link to eks-a docs ==}.

### Configure Storage Class

The demo clusters does not have any default storage provisoners or storage class defined. For this demo we will use rancher's [local-path-provisoner](https://github.com/rancher/local-path-provisioner).

```shell
kubectl apply \
  -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

Wait for the storage provisioner to be ready,

```shell
kubectl rollout status -n local-path-storage deploy/local-path-provisioner --timeout=60s
```

Set it as default storage class so that any new PVC requests will be created using this Storage class' underlying storage.

```shell
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Install Gloo Edge Enterprise

Download and install latest **glooctl** by running,

```shell
curl -sL https://run.solo.io/gloo/install | sh
```

Add glooctl to the system path,

```shell
export PATH=$HOME/.gloo/bin:$PATH
```

Gloo Edge proxy is a Kubernetes service of type `LoadBalancer`, for the purpose of this blog we will configure it to be of type `NodePort` using the `install-ee-values.yaml` as shown below,


```yaml hl_lines="11-12"
gloo:
  settings:
    writeNamespace: gloo-system
    watchNamespace:
      - gloo-system
      - fruits-app
  gatewayProxies:
    gatewayProxy:
      service:
        type: NodePort
        httpNodePort: 30080 # (1)
        httpsNodePort: 30443 # (2)
```

1. Use `30080` as NodePort to access the Gloo Proxy
2. Use `30443` as NodePort to access the Gloo Proxy

```shell
glooctl install gateway enterprise \
  --license-key "$GLOO_LICENSE_KEY" \
  --values "$DEMO_HOME/cluster/install-ee-values.yaml"
```

!!! note
    - You can safely ignore the helm warnings
    - It will take few minutes for the gloo to be ready, try the command `glooctl check` to verify the status.

Once the gloo edge is deployed check if Gloo Edge is functional,

```shell
glooctl check
```

A successful gloo edge installation should show an output like,

```text
Checking deployments... OK
Checking pods... OK
Checking upstreams... OK
Checking upstream groups... OK
Checking auth configs... OK
Checking rate limit configs... OK
Checking VirtualHostOptions... OK
Checking RouteOptions... OK
Checking secrets... OK
Checking virtual services... OK
Checking gateways... OK
Checking proxies... OK
Checking rate limit server... OK
No problems detected.
I0818 09:29:26.773174    6734 request.go:645] Throttling request took 1.041899775s, request: GET:https://127.0.0.1:57778/apis/storage.k8s.io/v1?timeout=32s

Detected Gloo Federation!
```

## Deploy AWS Lambda Function

With us having created an eks-a cluster and deployed Gloo Edge on to it successfully, let us now create [AWS Lambda](https://aws.amazon.com/lambda/) function and use Gloo Edge to invoke it.

### Create AWS IAM Role

```shell
aws iam create-role --role-name gloo-edge-eks-a-lambdaex \
   --assume-role-policy-document "file://$DEMO_HOME/apps/lambda/trust-policy.json"
```

Save the Role ARN environment variable,

```shell
export ROLE_ARN=$(aws iam get-role --role-name gloo-edge-eks-a-lambdaex | jq -r .Role.Arn)
```

Attach the *AWSLambdaBasicExecutionRole* to our role,

```shell
aws iam attach-role-policy --role-name gloo-edge-eks-a-lambdaex \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### Create Lambda Function

The demo already has ready to deploy simple nodejs hello world application,

```javascript
exports.handler = async (event) => {
  const response = {
      statusCode: 200,
      body: {"message": `Hello ${event.user?event.user:"there"}, welcome to Gloo Edge with Lambda.,`},
  };
  return response;
};
```

Let us deploy that function using AWS Lambda,

```shell
aws lambda create-function --function-name gloo-edge-hello-lambda \
--zip-file "fileb://$DEMO_HOME/apps/lambda/function.zip" \
--handler index.handler \
--runtime nodejs14.x \
--role "$ROLE_ARN"
```

Let us make sure our function works,

```shell
aws lambda invoke \
  --cli-binary-format raw-in-base64-out \
  --function-name gloo-edge-hello-lambda \
  --payload '{"user": "tom"}' \
  response.json
```

If the function has executed sucessfully, the `$DEMO_HOME/response.json` should have the following content,

```json
{
  "statusCode": 200,
  "body": { "message": "Hello tom, welcome to Gloo Edge with Lambda.," }
}
```

## Gloo Edge

We have now deployed the AWS Lambda function, let us now create the necessary Gloo Edge resources that will allow configure and access the Lambda via Gloo Edge Gateway. To have more understanding on core concepts check the Gloo Edge [documentation](https://docs.solo.io/gloo-edge/latest/introduction/architecture/concepts/){target=_blank}.

As part of this short demo we will,

- Create AWS Secret
- [Create Gloo Upstream](https://docs.solo.io/gloo-edge/latest/guides/traffic_management/destination_types/aws_lambda/#create-aws-upstream){target=_blank}
- [Create Gloo Virtual Services](https://docs.solo.io/gloo-edge/latest/introduction/architecture/concepts/#virtual-services){target=_blank}

### Create AWS Secret

We need to create Kubernetes secret that holds the AWS Keys. This secret will be used by Gloo Edge invoke the AWS Lambda function,

```shell
glooctl create secret aws \
  --name=gloo-eks-a-demo \
  --access-key="$AWS_ACCESS_KEY_ID" \
  --secret-key="$AWS_SECRET_ACCESS_KEY"
```

You can check the created credentials by,

```shell
kubectl get secrets -n gloo-system gloo-eks-a-demo -o yaml
```

### Create Upstream

As part of this section we will create an Gloo *Upstream* that will allow the Virutal Service to talk to AWS Lambda via Gloo Edge Gateway,

``` shell
glooctl create upstream aws \
  --name="gloo-edge-hello-lambda" \
  --aws-region="$AWS_DEFAULT_REGION" \
  --aws-secret-name=gloo-eks-a-demo
```

Check the status of the upstream,

```shell
glooctl get upstream gloo-edge-hello-lambda
```

```text
+------------------------+------------+----------+--------------------------------+
|        UPSTREAM        |    TYPE    |  STATUS  |            DETAILS             |
+------------------------+------------+----------+--------------------------------+
| gloo-edge-hello-lambda | AWS Lambda | Accepted | region: ap-south-1             |
|                        |            |          | secret:                        |
|                        |            |          | gloo-system.gloo-eks-a-demo    |
|                        |            |          | functions:                     |
|                        |            |          | - gloo-edge-hello-lambda       |
|                        |            |          | - my-function                  |
|                        |            |          |                                |
+------------------------+------------+----------+--------------------------------+
```

### Create Route

A Route is a Gloo Virutal Service resource that allows us to access the API i.e. the services that are deployed on to Kubernetes.

```yaml
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: greeter
  namespace: gloo-system
spec:
  displayName: AWS Lambda Greeter
  virtualHost:
    domains: # (1)
      - "example.com"
    routes:
      # Application Routes
      # ------------
      - matchers:
          - prefix: /greet # (2)
        routeAction:
          single:
            destinationSpec:
              aws: # (3)
                logicalName: gloo-edge-hello-lambda # (4)
            upstream: # (5)
              name: gloo-edge-hello-lambda
              namespace: gloo-system

```

1. Domains that will be allowed by the Gateway
2. The prefix to access the API
3. The destination spec type
4. in this case AWS Lambda function named `gloo-edge-hello-lambda`
5. The upstream that wil be used to route the request

Let us create the virutal service,

```shell
kubectl apply -n gloo-system -f $DEMO_HOME/apps/lambda/gloo/virtual-service.yaml
```

Check the status of the virtual service

```shell
glooctl get vs greeter
```

```text
+-----------------+--------------------+-------------+------+----------+-----------------+------------------------------------+
| VIRTUAL SERVICE |    DISPLAY NAME    |   DOMAINS   | SSL  |  STATUS  | LISTENERPLUGINS |               ROUTES               |
+-----------------+--------------------+-------------+------+----------+-----------------+------------------------------------+
| greeter         | AWS Lambda Greeter | example.com | none | Accepted |                 | /greet ->                          |
|                 |                    |             |      |          |                 | gloo-system.gloo-edge-hello-lambda |
|                 |                    |             |      |          |                 | (upstream)                         |
+-----------------+--------------------+-------------+------+----------+-----------------+------------------------------------+
```

## Invoke Function

We need to use the Gloo proxy to access the API, we can use glooctl to get the proxy URL,

```shell
export GLOO_PROXY_URL=$(glooctl proxy url)
```

Check if the API is accessible,

```shell
http --body POST $GLOO_PROXY_URL/greet 'Host: example.com' user=tom
```

!!! note
    We have to use the host header 'Host: example.com' as we have restricted the gateway domains of the Virtual Service to `example.com` only. In the [next chapter](./microservice.md#route) we will use the wildcard domain that will allow all the domains.

The command should return a list of fruits as shown,

```json
{
    "body": {
        "message": "Hello tom, welcome to Gloo Edge with Lambda.,"
    },
    "statusCode": 200
}
```

!!! tip
    Try the same request as show below to see the other repsonse headers
    ```shell
      http POST $GLOO_PROXY_URL/greet 'Host: example.com' user=tom
    ```

## Summary

As part of this short blog we,

- [x] Created EKS-A cluster
- [x] Deployed Gloo Edges
- [x] And finally invoked an AWS Lambda function via Gloo Edge gateway

Gloo Edge is not restricted to AWS Lambda, it can also be used to connect traditional microservices. Head over to the [tutorial](./index.md) to learn more on what other thigns you can do with Gloo Edge.

{== Any other CTA ==}

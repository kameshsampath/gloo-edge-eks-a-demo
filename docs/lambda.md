# AWS Lambda

Gloo Edge can act as gateway to [AWS Lambda](https://aws.amazon.com/lambda/) functions.

At the end of this chapter you would have known how to:

- [x] Create Gloo AWS Lambda Upstream
- [x] Create Gloo Edge Gateway
- [x] Configure Rate Limiting
- [x] Configure WAF

## Pre-requsites

- AWS Account
- AWS Access Key
- AWS Secret Key

## Ensure Environment

!!! note
    - If you already have the environment variables set with same name, you can ignore this section
    - If not set, Gloo Edge tends to compute these values from `$HOME/.aws/credentials`
    - Its recommended to set these values for better clarity

As we need to interact with AWS services, we will set the following environment variables,

```shell
   export AWS_ACCESS_KEY_ID=<your aws access key>
   export AWS_SECRET_ACCESS_KEY=<your aws secret key>
   export AWS_DEFAULT_REGION=<the aws region to use for the resources>
```

## Deploy AWS Lambda Function

### Create Role

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

### Create Function

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

Deploy the lambda,

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

We have now deployed the AWS Lambda function, in the upcoming sections we will create the necessary Gloo Edge resources that will allow configure and access the Lambda via Gloo Edge Gateway. To have more understanding on the core concepts check the [Traffic Management](https://docs.solo.io/gloo-edge/latest/introduction/traffic_management/){target=_blank} documentation.

In the upcoming sections we will,

- Create AWS Secret
- [Create Upstream](https://docs.solo.io/gloo-edge/latest/guides/traffic_management/destination_types/aws_lambda/#create-aws-upstream){target=_blank}
- [Create Virtual Services](https://docs.solo.io/gloo-edge/latest/introduction/architecture/concepts/#virtual-services){target=_blank}

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

### Create Upstreams

As part of this section we will create .

Let us check to see if thats available,

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

### Route

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

## Invoke the API

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

## Rate Limit

As part of this sectiobn we will configure [Rate limiting](https://en.wikipedia.org/wiki/Rate_limiting){targe=_blank}.

```yaml
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: lambda-global-limit
  namespace: gloo-system
spec:
  raw:
    descriptors:
    - key: generic_key
      value: count
      rateLimit:
        requestsPerUnit: 10 #(1)
        unit: MINUTE #(1)
    rateLimits:
    - actions:
      - genericKey:
          descriptorValue: count

```

1. Number of requests
2. The duration for the request threshold, is this case 1 minute

Let us apply the rate limiting configuration,

```shell
kubectl apply -n gloo-system -f $DEMO_HOME/apps/lambda/gloo/ratelimit-config.yaml
```

Update the service with ratelimit,

```shell
kubectl apply -n gloo-system -f $DEMO_HOME/apps/lambda/gloo/virtual-service-ratelimit.yaml
```

Let us now send requests to the API, with our current configuration we should start to get `HTTP 429` once we exceed 10 requests,

```shell
$DEMO_HOME/bin/greeter-poll.sh
```

Wait for a minute or more, then try polling again to see the requests getting executed successfully until it reaches another set of *10* requests.

## Web Application Firewall

A WAF protects web applications by monitoring, filtering and blocking potentially harmful traffic and attacks that can overtake or exploit them.

Gloo Edge Enterprise includes the ability to enable the ModSecurity [Web Application Firewall](https://docs.solo.io/gloo-edge/latest/guides/security/waf/){target=_blank}for any incoming and outgoing HTTP connections.

For this demo, let us assume that our application will not support payload size of more than `1 byte`,

```yaml
apiVersion: gateway.solo.io/v1
kind: VirtualService
metadata:
  name: greeter
  namespace: gloo-system
spec:
  displayName: AWS Lambda Greeter
  virtualHost:
    domains:
      - "example.com"
    options:
      # -------- Web Application Firewall - Check User-Agent  -----------
      waf: # (1)
        ruleSets: # (2)
          - ruleStr: | # (3)
              SecRuleEngine On
              SecRequestBodyLimit 50
              SecRequestBodyLimitAction Reject
        customInterventionMessage: "Payload sizes above 50 bytes not allowed" # (4)
    routes:
      # Application Routes
      # ------------
      - matchers:
          - exact: /greet
        routeAction:
          single:
            destinationSpec:
              aws:
                logicalName: gloo-edge-hello-lambda
            upstream:
              name: gloo-edge-hello-lambda
              namespace: gloo-system
        options:
          # ---------------- Rate limit config ----------------------
          rateLimitConfigs:
            refs:
              - name: lambda-global-limit
                namespace: gloo-system
```

1. Define WAF rules
2. The WAF block can have one or more `ruleSets`
3. The rule inspects the payload size and if anything greater than 1 byte is rejected
4. The message to display for rule voilations

Let us update the Virtual Service with WAF enabled,

```shell
kubectl apply -n gloo-system -f $DEMO_HOME/apps/lambda/gloo/virtual-service-waf.yaml
```

Try request with payload more than `50 bytes`:

```shell
http POST $GLOO_PROXY_URL/greet 'Host: example.com' < $DEMO_HOME/apps/lambda/doc.json
```

The request should with a response,

```text
{== HTTP/1.1 403 Forbidden ==}
content-length: 40
content-type: text/plain
date: Wed, 18 Aug 2021 16:32:02 GMT
server: envoy


{== Payload sizes above 50 bytes not allowed ==}
```

Now try the same request with smaller payload size, which should succeeed.

```shell
http POST $GLOO_PROXY_URL/greet 'Host: example.com' $GLOO_PROXY_URL/greet user=tom 
```

---8<--- "includes/abbrevations.md"

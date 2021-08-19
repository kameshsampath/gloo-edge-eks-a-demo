# Cluster Setup

At the end of this chapter you will have working `eks-a` cluster with Gloo Edge Enterprise installed and configured.

## Pre-requisites

- [eks-a](https://example.com/eks-a){target=_blank}
- [glooctl](https://docs.solo.io/gloo-edge/latest/getting_started/){target=_blank}
- [jq](https://stedolan.github.io/jq/){target=_blank}
- [kubectl](https://kubectl.docs.kubernetes.io/installation/kubectl/){target=_blank}
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/){target=_blank}
- Gloo Edge Enterprise License Key
- [VMWare Cloud](https://vmc.vmware.com){target=_blank}

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

## EKS-A Cluster

To create the EKS-A cluster run the following command,

```shell
eks-a create cluster -f cluster/gloo-edge.yaml # (1)
```

1. `gloo-edge.yaml`- will be generated using the `eks-a generate` command. For more information on the command please refer to {== **TODO** Link to eks-a docs ==}.

## Configure Storage Class

The demo clusters does not have default storage provisoners or storage class defined. For this demo we will use rancher's [local-path-provisoner](https://github.com/rancher/local-path-provisioner).

```shell
kubectl apply \
  -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

Wait for the storage provisioner to be ready,

```shell
kubectl rollout status -n local-path-storage deploy/local-path-provisioner --timeout=60s
```

Set it as default storage class

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

Gloo Edge proxy is a Kubernetes service of type `LoadBalancer`, for the purpose of this blog we will configure it to be of type `NodePort` as shown below,

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
    - The Gloo Edge is also configured to use NodePort for proxy,that will help to access the Gloo Gateway proxy using node port. This configuration is set via `install-ee-values.yaml`.
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

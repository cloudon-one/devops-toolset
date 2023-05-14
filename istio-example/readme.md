# Istio deployment guideline

Install the istioctl binary with curl:

1. Download the latest release with the command:

```
curl -sL https://istio.io/downloadIstioctl | sh -
```

Add the istioctl client to your path, on a macOS or Linux system:

```
export PATH=$PATH:$HOME/.istioctl/bin
```

You can optionally enable the auto-completion option when working with a bash or ZSH console.

2. Deploy IstioOperator and Istio Control Plane via istioctl CLI

Run these commands:

```
gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --project "$GCP_PROJECT_ID" --region "$GCP_REGION"
cd Istio/
istioctl manifest apply -f istio-control-plane.yml
```

3. How to use Istio for a specific kubernetes namespace:

```
kubectl get ns "$NAMESPACE" || kubectl create ns "$NAMESPACE"
kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite
```

4. Then you need to create 2 k8s resources: Istio Gateway and Istio VirtualService

Examples for cloudon-demo app

`Gateway` manifest

```
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  annotations:
    meta.helm.sh/release-name: cloudon-demo
    meta.helm.sh/release-namespace: cl-1
  labels:
    app.kubernetes.io/helm-release: cloudon-demo
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/service: ccloudon-demo
    helm.sh/chart: microservice-1.0.0
  name: cloudon-demo-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - demo.cloudon.one
    port:
      name: http
      number: 80
      protocol: HTTP
```

`VirtualService` manifest:

```
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  annotations:
    meta.helm.sh/release-name: cloudon-demo
    meta.helm.sh/release-namespace: cloudon-demo
  labels:
    app.kubernetes.io/helm-release: cloudon-demo
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/service: cloudon-demo
    helm.sh/chart: microservice-1.0.0
  name: communication-center
spec:
  gateways:
  - cloudon-demo
  hosts:
  - '*'
  http:
  - match:
    - uri:
        prefix: /
    name: root
    route:
    - destination:
        host: cloudon-demo
        port:
          number: 80
```

# avidcovider gcloud environment

Avidcovider uses a dedicated cluster on Google Cloud

## Setup ingress and SSL

Set your user as cluster admin

```
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)
```

Install nginx ingress

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/cloud-generic.yaml
```

Verify ingress-nginx is Running

```
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx
```

Get the external IP

```
kubectl get -n ingress-nginx service
```

Make sure to add the following annotation to all ingresses:

```
kubernetes.io/ingress.class: "nginx"
```

Install cert-manager for SSL

```
kubectl create ns cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.13.0/cert-manager.yaml
kubectl get pods --namespace cert-manager
```

Create lets-encrypt cluster issuer

Create a Let's Encrypt cluster issuer (replace the email with your email):

```
echo "apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: cert-manager
spec:
  acme:
    email: user@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource used to store the account's private key.
      name: cluster-issuer-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
" | kubectl apply -f -
```

To use, add an ingress, for example (replace NAME, NAMESPACE, HOSTNAME, SERVICENAME):

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: letsencrypt
  name: NAME
  namespace: NAMESPACE
spec:
  rules:
  - host: HOSTNAME
    http:
      paths:
      - backend:
          serviceName: SERVICENAME
          servicePort: 80
  tls:
  - hosts:
    - HOSTNAME
    secretName: NAME-cert
```

## Copy secrets from other environment

Switch to source environment and export the secrets

```
mkdir -p environments/avidcovider-gcloud/.secrets &&\
kubectl -n avidcovider get secret pipelines-secrets --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-secrets.yaml &&\
kubectl -n avidcovider get secret  pipelines-cdc-secrets-certs --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-cdc-secrets-certs.yaml &&\
kubectl -n avidcovider get secret  pipelines-collector --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-collector.yaml &&\
kubectl -n avidcovider get secret  pipelines-auth --export -o yaml >environments/avidcovider-gcloud/.secrets/pipelines-auth.yaml
```

Switch to target environment and import the secrets

```
kubectl -n avidcovider apply -f environments/avidcovider-gcloud/.secrets/pipelines-secrets.yaml &&\
kubectl -n avidcovider apply -f environments/avidcovider-gcloud/.secrets/pipelines-cdc-secrets-certs.yaml &&\
kubectl -n avidcovider apply -f environments/avidcovider-gcloud/.secrets/pipelines-collector.yaml &&\
kubectl -n avidcovider apply -f environments/avidcovider-gcloud/.secrets/pipelines-auth.yaml
```

Cleanup

```
rm -rf environments/avidcovider-gcloud/.secrets
```

# Argo CD - continuous deployment

[Download ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli)

## Usage

All the infrastructure is managed via apps defined under `apps/`, each directory under `apps/` is a single app
which can be deployed to the cluster. Apps are usually helm charts, but can also contain manifests or kustomize 
files. See argocd documentation for details.

All the apps which need to be synced should be defined in the app `hasadna-argocd`. App definitions
should be added to `hasadna-argocd/values-hasadna.yaml`.

You can track progress of deployments using the Web UI. Login at https://argocd.hasadna.org.il 
using GitHub, to have access you need to belong to one of these teams:
* [argocd-users](https://github.com/orgs/hasadna/teams/argocd-users) - have read-only access, can view deployment progress but can't perform any actions 
* [argocd-admins](https://github.com/orgs/hasadna/teams/argocd-admins) - have full admin access

To login from the CLI: `argocd login --sso argocd-grpc.hasadna.org.il`

You can also login using the local admin user, the password is available in Vault `Projects/k8s/argocd`.
You can login from CLI using `argocd login --username "" --password "" argocd-grpc.hasadna.org.il`

## Migrating to argocd from helm

Old helm releases can be migrated to argocd with minimal disruption using the following procedure:

* Move relevant chart + valuse to `apps/`
* Add the app to `hasadna-argocd/values-hasadna.yaml`
* Delete all Helm secrets in the app namespace - this removes the helm releases without deleting the resources
* Commit the changes and sync the argocd app

## Install

```
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Edit the argocd-server deployment and add `--insecure` flag as we will handle TLS on the ingress

Deploy ingresses

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argocd-server-https
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: argocd.hasadna.org.il
    http:
      paths:
      - backend:
          serviceName: argocd-server
          servicePort: http
  tls:
  - hosts:
    - argocd.hasadna.org.il
    secretName: argocd-server-https-cert
```

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argocd-server-grpc
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  rules:
  - host: argocd-grpc.hasadna.org.il
    http:
      paths:
      - backend:
          serviceName: argocd-server
          servicePort: https
  tls:
  - hosts:
    - argocd-grpc.hasadna.org.il
    secretName: argocd-server-grpc-cert
```

## Backup / persistency

All argocd data is stored in Kubernetes CRDs under `argocd` namespace.

Backup using `argocd admin export --namespace argocd`

# Argo CD - continuous deployment

All the infrastructure is managed via apps defined under [/apps](/apps).
Each directory under [/apps](/apps) is a single app which can be deployed to the cluster.
Apps are usually helm charts, but can also contain manifests or kustomize files.
See argocd documentation for all available options.

All the apps which need to be synced should be defined in [/apps/hasadna-argocd/values-hasadna.yaml](/apps/hasadna-argocd/values-hasadna.yaml).
The `hasadna-argocd` app is synced in ArgoCD and any apps defined there will be added and synced as well.

You can disable the auto-sync of apps, allowing to view diff before applying or 
to make manual changes for debugging, by adding `disableAutoSync: true` to the 
relevant app definition in `hasadna-argocd/values-hasadna.yaml`

You can track progress of deployments using the Web UI.
Login at https://argocd.hasadna.org.il using GitHub.
To have access you need to belong to one of these teams:
* [argocd-users](https://github.com/orgs/hasadna/teams/argocd-users) - have read-only access, can view deployment progress but can't perform any actions 
* [argocd-admins](https://github.com/orgs/hasadna/teams/argocd-admins) - have full admin access

You can also login using the local admin user, the password is available in Vault `Projects/k8s/argocd`.

## Using ArgoCD CLI

[Download ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli)

* Login using SSO: `argocd login --sso argocd-grpc.hasadna.org.il`
* Login using username/password: `argocd login --username "" --password "" argocd-grpc.hasadna.org.il`

## Migrating to argocd from helm

Old helm releases can be migrated to argocd with minimal disruption using the following procedure:

* Move relevant chart + valuse to `apps/`
* Add the app to `hasadna-argocd/values-hasadna.yaml`
* Delete all Helm secrets in the app namespace - this removes the helm releases without deleting the resources
* Commit the changes and sync the argocd app

## Install

Create namespace

```
kubectl create ns argocd
```

Login to Vault as admin and add the following:

read-only policy:

```
path "kv/data/*" {
  capabilities = [ "read" ]
}
```

approle:

```
vault write auth/approle/role/ROLE_NAME token_policies="POLICY_NAME" token_ttl=1h token_max_ttl=4h
```

Get role and secret id

```
vault read auth/approle/role/ROLE_NAME/role-id
vault write -force auth/approle/role/ROLE_NAME/secret-id
``` 

Create vault credentials secret

```
kubectl -n argocd create secret generic argocd-vault-plugin-credentials \
    --from-literal=VAULT_ADDR= \
    --from-literal=AVP_TYPE=vault \
    --from-literal=AVP_AUTH_TYPE=approle \
    --from-literal=AVP_ROLE_ID= \
    --from-literal=AVP_SECRET_ID=
```

Deploy

```
kubectl apply -n argocd -k apps/hasadna-argocd/manifests
```

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

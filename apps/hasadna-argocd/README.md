# Hasadna argocd

Contains ArgoCD definitions

For general usage instructions see [/docs/argocd.md](/docs/argocd.md)

## Install ArgoCD

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

Set Vault connection details for Hasadna's Vault

```
export VAULT_ADDR=
export VAULT_TOKEN=
```

Make sure you have `vault` and `jq` binaries installed locally

Render the templates with secret values from Vault

```
apps/hasadna-argocd/manifests/render_templates.sh
```

Make sure you are connected to Hasadna's cluster (`kubectl get nodes`)

Render manifests to review

```
kustomize build apps/hasadna-argocd/manifests
```

Dry Run on the server

```
kustomize build apps/hasadna-argocd/manifests | kubectl apply --dry-run=server -n argocd -f -
```

Deploy

```
kustomize build apps/hasadna-argocd/manifests | kubectl apply -n argocd -f -
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

## Permissions Management

ArgoCD user/group permissions are defined in `apps/hasadna-argocd/manifests/patch-argocd-rbac-cm.yaml`, 
see [ArgoCD RBAC](https://argoproj.github.io/argo-cd/operator-manual/rbac/) for more details.

Authorization is handled via GitHub, and the permission groups have to be defined in the Hasadna GitHub organization
as teams. All the team names which are used in the RBAC configuration have to also be defined in 
`apps/hasadna-argocd/manifests/patch-argocd-cm.yaml.template` under the `teams` key.

Once you made the relevant changes, deployment needs to be done manually as described above in the 
`Install ArgoCD` section.

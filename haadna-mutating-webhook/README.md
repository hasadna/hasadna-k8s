# Haadna Mutating Webhook

Kubernetes admission webhook that replaces the `~iac:` and `~vault:`
place-holders used in the Hasadna charts.

It is implemented with controller-runtime (kubebuilder-style layout) and
exposes a single mutating endpoint `/mutate-placeholders`.

Runtime behaviour
* `~iac:<terraform-output-key>~` → value from ConfigMap `argocd/tf-outputs`.
* `~vault:<path>:<field>~`      → base-64 of the field from Vault KV v2.

TLS certificates are issued automatically by cert-manager (`Certificate`
CR) and injected into the `MutatingWebhookConfiguration` via the
`cert-manager.io/inject-ca-from` annotation.

Kustomize manifests under `config/` install:

* Namespace, SA and RBAC (read ConfigMap).
* Deployment + Service.
* Certificate and MutatingWebhookConfiguration.

Build & deploy (outline):

```bash
# build container (requires ko or a standard docker build pipeline)
KO_DOCKER_REPO=ghcr.io/hasadna/hasadna-mutating-webhook kubebuilder build .

# apply manifests
kustomize build config | kubectl apply -f -
```

# Hasadna Mutating Webhook

Kubernetes admission webhook that replaces the `~iac:` and `~vault:`
place-holders used in the Hasadna charts.

It is implemented with controller-runtime (kubebuilder-style layout) and
exposes a single mutating endpoint `/mutate-placeholders`.

Runtime behaviour
* `~iac:<terraform-output-key>~` → value read from Terraform backend as configured in the env vars described below.
* `~vault:<path>:<field>~`      → base-64 of the field from Vault KV v2 as configured in the env vars described below.

Configuration via env vars:

* `TF_BACKEND_TYPE` - Terraform backend type, e.g. `local`, `gcs`, `s3` etc..
* `TF_BACKEND_CONFIG__*` - Set values for the backend configuration, for example `TF_BACKEND_CONFIG__bucket=my-bucket`.
* `VAULT_ADDR` - Vault address, e.g. `https://vault.example.com`.
* `VAULT_TOKEN` - Vault token with read access to the secrets.
* `VAULT_ROLE_ID` - Vault AppRole Role ID, used for authentication.
* `VAULT_SECRET_ID` - Vault AppRole Secret ID, used for authentication.

TLS certificates are issued automatically by cert-manager (`Certificate`
CR) and injected into the `MutatingWebhookConfiguration` via the
`cert-manager.io/inject-ca-from` annotation.

Kustomize manifests under `config/` install:

* Namespace, SA and RBAC (read ConfigMap).
* Deployment + Service.
* Certificate and MutatingWebhookConfiguration.

## Local Development

```
cd hasadna-mutating-webhook
go mod tidy
go fmt
go vet ./...
go test ./...
go build
./hasadna-mutating-webhook --help
```

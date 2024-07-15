# Argo CD - continuous deployment

All the infrastructure is managed via apps defined under [/apps](/apps).
Each directory under [/apps](/apps) is a single app which can be deployed to the cluster.
Apps are usually helm charts, but can also contain manifests or kustomize files.
See argocd documentation for all available options.

All the apps which need to be synced should be defined in [/apps/hasadna-argocd/templates/](/apps/hasadna-argocd/templates/).
The `hasadna-argocd` app is synced in ArgoCD and any apps defined there will be added and synced as well.

You can track progress of deployments using the Web UI.
Login at https://argocd.hasadna.org.il using GitHub.
To have access you need to belong to one of these teams:
* [argocd-users](https://github.com/orgs/hasadna/teams/argocd-users) - have read-only access, can view deployment progress but can't perform any actions 
* [argocd-admins](https://github.com/orgs/hasadna/teams/argocd-admins) - have full admin access

You can also login using the local admin user, the password is available in Vault `Projects/k8s/argocd`.

## Using values from Secrets and IAC

Hasadna ArgoCD plugin handles replacing values in rendered templates from [hasadna-iac tf_outputs](https://github.com/hasadna/hasadna-iac/blob/main/kubernetes_tf_outputs.tf)
and from Hasadna Vault. Any value in the following format will be replaced:

* `iac:key` - the `key` will be taken from [hasadna-iac tf_outputs](https://github.com/hasadna/hasadna-iac/blob/main/kubernetes_tf_outputs.tf)
* `vault:path:key` - the `key` will be taken from the Vault `path`, value will be base64 encoded and should be used in k8s secrets only

## Local App Development

This is an advanced operation, you should only do this if you know what you are doing.

```
python -m venv venv
venv/bin/pip install -r https://raw.githubusercontent.com/OriHoch/uumpa-argocd-plugin/main/requirements.txt
venv/bin/pip install -e git+https://github.com/OriHoch/uumpa-argocd-plugin.git#egg=uumpa-argocd-plugin
venv/bin/pip install -e apps/hasadna-argocd/plugin
```

Render the app templates to stdout:

```bash
. venv/bin/activate
hasadna-argocd-plugin init <CHART_PATH>
hasadna-argocd-plugin generate <NAMESPACE_NAME> <CHART_PATH> [HELM_ARGS..]

# for example:
hasadna-argocd-plugin init apps/openbus
hasadna-argocd-plugin generate openbus apps/openbus -f values-hasadna.yaml  -f values-hasadna-auto-updated.yaml
```

If you want the rendered templates to replace variables, you need relevant access and credentials:

* For IAC variables, you need to have `kubectl` connect to the relevant cluster
* For Vault variables, you need to have `VAULT_ADDR` and `VAULT_TOKEN` environment variables set

You can also apply the rendered templates to the cluster -

* Make sure to disable auto sync for the app so that ArgoCD won't revert your changes
* Make sure to set all relevant env vars in your shell so that the rendered templates will match the argocd rendered templates

You can apply the rendered templates:

```bash
hasadna-argocd-plugin generate openbus apps/openbus -f values-hasadna.yaml  -f values-hasadna-auto-updated.yaml | kubectl apply -f -
```

## Using ArgoCD CLI

[Download ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli)

* Login using SSO: `argocd login --sso argocd-grpc.hasadna.org.il`
* Login using username/password: `argocd login --username "" --password "" argocd-grpc.hasadna.org.il`

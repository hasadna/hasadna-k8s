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

## Using values from Secrets and IAC

Hasadna ArgoCD plugin handles replacing values in rendered templates from [hasadna-iac tf_outputs](https://github.com/hasadna/hasadna-iac/blob/main/kubernetes_tf_outputs.tf)
and from Hasadna Vault. Any value in the following format will be replaced:

* `iac:key` - the `key` will be taken from [hasadna-iac tf_outputs](https://github.com/hasadna/hasadna-iac/blob/main/kubernetes_tf_outputs.tf)
* `vault:path:key` - the `key` will be taken from the Vault `path`, value will be base64 encoded and should be used in k8s secrets only

To render templates locally:

* `pip install kubernetes`
* Connect to the cluster, so that when you run `kubectl get nodes` you will get the hasadna cluster nodes
* Render the chart, for example:
  * `apps/hasadna-argocd/argocd-hasadna-plugin.py init apps/openbus`
  * `apps/hasadna-argocd/argocd-hasadna-plugin.py generate apps/openbus openbus  -f values-hasadna.yaml -f values-hasadna-auto-updated.yaml`

## Making Changes Locally

To make changes locally without depending on argocd, use the following procedure:

* Prerequisites:
  * Python3
  * `pip install kubernetes`
* Connect to the cluster
  * Verify by running `kubectl get nodes` and make sure you see the relevant cluster nodes
* Disable auto-sync for relevant app so your changes won't be rollbacked:
  * set `disableAutoSync: true` for the relevant app at `hasadna-argocd/values-hasadna.yaml`
  * Commit & Push this change
* Set the chart path, name and value files in env vars, for example:
  * `CHART_NAME=openbus`
  * `CHART_PATH=apps/openbus/`
  * `HELM_ARGS="-f values-hasadna.yaml -f values-hasadna-auto-updated.yaml"`
* Render the chart yamls:
  * `bin/render_chart.sh $CHART_PATH $CHART_NAME "${HELM_ARGS}"`
* Dry run the kubectl apply on the server, to see which objects would be modified:
  * Note that argocd adds some labels, so it may detect these changes in all objects 
  * `bin/render_chart.sh $CHART_PATH $CHART_NAME "${HELM_ARGS}" --dry-run` 
* Apply the chart to the cluster:
  * `bin/render_chart.sh $CHART_PATH $CHART_NAME "${HELM_ARGS}" --apply`

## Using ArgoCD CLI

[Download ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli)

* Login using SSO: `argocd login --sso argocd-grpc.hasadna.org.il`
* Login using username/password: `argocd login --username "" --password "" argocd-grpc.hasadna.org.il`

## Moving datacity from gcloud to Kamatera

Added `environments/datacity-kubeconfig`

Connect to the Gcloud environment and export the secrets:

```
export KUBECONFIG=
source switch_environment.sh datacity
mkdir -p environments/${K8S_ENVIRONMENT_NAME}-kubeconfig/.secrets
for SECRET_NAME in datacity; do
    kubectl get secret $SECRET_NAME --export -o yaml > environments/${K8S_ENVIRONMENT_NAME}-kubeconfig/.secrets/$SECRET_NAME.yaml
done
```

Connect to the Kamatera environment, create the namespace and import the secrets

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh datacity-kubeconfig
kubectl create ns datacity
for SECRET_NAME in datacity; do
    kubectl -n datacity apply -f environments/${K8S_ENVIRONMENT_NAME}/.secrets/$SECRET_NAME.yaml
done
rm -rf environments/${K8S_ENVIRONMENT_NAME}/.secrets
```

Rename `environments/datacity` to `environments/datacity-gcloud`

Rename `environments/datacity-kubeconfig` to `environments/datacity`

Upgrade datacity chart to helm3:

Add to `charts-external/datacity/Chart.yaml`:

```
version: "v0.0.0"
apiVersion: v2
```

Edit all deployment objects under `charts-external/datacity/templates`:

set `apiVersion: apps/v1`

Add:

```
spec:
  selector:
    matchLabels:
      app: APP_NAME
```

Deploy:

```
export KUBECONFIG=/path/to/kamatera/.kubeconfig
source switch_environment.sh datacity
./helm_upgrade_external_chart.sh datacity --install
```
# Cluster Nodes Management

## Install Rancher CLI

```
bash apps_travis_script.sh install_rancher
```

Get a Rancher API key (from the Rancher web UI)

login:

```
rancher login --token RANCHER_API_TOKEN RANCHER_API_ENDPOINT
```

## SSH to nodes

List nodes: `rancher nodes`

SSH to node: `rancher ssh NODE_NAME -o IdentitiesOnly=yes`

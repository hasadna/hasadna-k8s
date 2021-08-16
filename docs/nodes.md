# Cluster Nodes Management

## Install Rancher CLI

```
bash apps_travis_script.sh install_rancher
```

Get the admin token from Vault Projects/k8s/rancher-admin-token

login:

```
rancher login --token RANCHER_API_TOKEN RANCHER_API_ENDPOINT
```

## SSH to nodes

SSH to hasadna-ssh-access-point (see private/doc001.md)

List nodes: `rancher nodes`

SSH to node: `rancher ssh NODE_NAME`

## Cluster node pools

In Rancher, we have the following cluster node pools:

* controlplane pool
    * 1 node
    * all roles (controlplane, etcd, worker)
    * taint: controlplane=true:NoSchedule
* worker pools
    * worker role only

By default pods will not be scheduled on the controlplane pool, but specific workloads can be scheduled by adding a pod toleration

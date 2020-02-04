# Kamatera cluster notes

## nfs-client provisioner

Adds an nfs storage class which adds volumes to the existing NFS server

SSH to NFS server, create the directory: `/srv/default/nfs-client-provisioner` 

Install nfs-client-provisioner, change IP to the NFS server internal IP:

```
kubectl create ns nfs-client-provisioner
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm install --namespace nfs-client-provisioner	\
    --set nfs.server=172.16.0.2 \
    --set nfs.path=/srv/default/nfs-client-provisioner \
    nfs-client-provisioner stable/nfs-client-provisioner
```

Using Rancher, you can now see the nfs-client storage class, you can set it as the default storage class using Rancher UI

## Logging using ElasticSearch

Deploy the operator

```
kubectl apply -f https://download.elastic.co/downloads/eck/1.0.0/all-in-one.yaml
```

Deploy an ElasticSearch node

```
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: cluster-logs
  namespace: default
spec:
  version: 7.5.2
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  nodeSets:
  - name: default
    count: 1
    config:
      node.master: true
      node.data: true
      node.ingest: true
      node.store.allow_mmap: false
EOF
```

Check status

```
kubectl get elasticsearch
```

Create an ingress with https to access the Elasticsearch server

The Elasticsearch username/password is stored in secret `cluster-logs-es-elastic-user`

Enable logging in Rancher

Deploy Kibana:

```
cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: cluster-logs-kibana
  namespace: default
spec:
  version: 7.5.2
  count: 1
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  elasticsearchRef:
    name: cluster-logs
EOF
```

Add an https ingress to access Kibana

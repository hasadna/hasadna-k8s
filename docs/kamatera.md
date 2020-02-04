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

## Backup

Backups are handled using Restic and run periodically from the Jenkins server

All backups require the  following env vars and installation of Restic:

```
export RESTIC_PASSWORD=
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
apt-get update && apt-get install -y restic
```

Initialize Rancher and Jenkins backups (run from the rancher/management server):

```
restic -r s3:s3.amazonaws.com/your-bucket-name/rancher init
```

Periodic backup job:

```
restic -r s3:s3.amazonaws.com/your-bucket-name/rancher /var/lib/rancher /srv/default
```

NFS Storage backups (run from the NFS node):

```
restic -r s3:s3.amazonaws.com/your-bucket-name/storage init
```

Periodic backup job:

```
restic -r s3:s3.amazonaws.com/your-bucket-name/storage backup /srv/default
```

etcd snapshot backups (run from one of the etcd nodes):

```
restic -r s3:s3.amazonaws.com/your-bucket-name/etcd init
```

Periodic backup job:

```
docker exec etcd etcdctl snapshot save /etcd-snapshot &&\
docker cp etcd:/etcd-snapshot ./etcd-snapshot &&\
restic -r s3:s3.amazonaws.com/your-bucket-name/etcd backup ./etcd-snapshot
```

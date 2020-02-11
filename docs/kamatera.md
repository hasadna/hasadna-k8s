# Kamatera cluster notes

## Creating the cluster

Cluster is created using Rancher

## SSH to cluster nodes

Using Rancher you can get the keys for each node in a zip file

## Setting up NFS

SSH to the NFS node and run the following:

```
apt-get update && apt-get install -y nfs-kernel-server &&\
mkdir -p /srv/default &&\
chown -R nobody:nogroup /srv/default/ &&\
echo '/srv/default 172.16.0.0/23(rw,sync,no_subtree_check,no_root_squash)' > /etc/exports &&\
exportfs -a &&\
systemctl restart nfs-kernel-server
```

Create a test directory and file:

```
mkdir /srv/default/test
echo hello world > /srv/default/test/foo
```

Using Rancher, deploy the following workload:

* Name: `nfs-test`
* Image: `ubuntu:xenial`
* Volume: ephemereal NFS Share
  * Path: `/srv/default/test`
  * Server: internal IP of the NFS node
  * Mount point: `/test`

Execute shell on the created pod and run the following:

```
cat /test/foo
echo hi > /test/foobar
```

On the NFS node, you should see the created foobar file:

```
cat /srv/default/test/foobar
```

Delete the `nfs-test` workload

From an external server, try to mount using the external IP (replace 1.2.3.4):

```
sudo mkdir -p /mnt/nfs-test
sudo mount -t nfs 1.2.3.4:/srv/default/test /mnt/nfs-test
```

It should fail with `access denied by server`

To verify, duplicate the line in /etc/exports with your IP, reload `systemctl reload nfs-server` and retry to mount

## Setting up Rancher ingress with cert-manager

Install cert-manager:

* Create namespace `cert-manager` in the Rancher system project
* `kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.13.0/cert-manager.yaml`
* Verify: `kubectl get pods --namespace cert-manager`

Create a Let's Encrypt cluster issuer (replace the email with your email):

```
echo "apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: user@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource used to store the account's private key.
      name: cluster-issuer-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
" | kubectl apply -f -
```

To use, add an ingress, for example (replace NAME, NAMESPACE, HOSTNAME, SERVICENAME):

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  name: NAME
  namespace: NAMESPACE
spec:
  rules:
  - host: HOSTNAME
    http:
      paths:
      - backend:
          serviceName: SERVICENAME
          servicePort: 80
  tls:
  - hosts:
    - HOSTNAME
    secretName: NAME-cert
```

## copying data from gcloud nodes

* Get the node name and uid of the pod you want to copy data from
* ssh to the node
* enter the toolbox: `toolbox`
* list the node volume directories: `ls -lah /media/root/var/lib/kubelet/pods/POD_UID/volumes`
* it should have subdirectories according to volume type, within each there should be the volumes
* Install: `apt-get update; apt-get install -y nfs-common rsync`
* mount the kamatera NFS
  * you should modify the /etc/exports file on the kamatera nfs node to allow the google node public IP
  * `mkdir -p /media/root/var/kamatera-nfs/MY_VOLUME`
  * `mount -t nfs 1.2.3.4:/srv/default/TARGET_VOLUME /var/kamatera-nfs/MY_VOLUME`
* rsync:
  * `rsync -az /media/root/var/lib/kubelet/pods/POD_UID/volumes/... /media/root/var/kamatera-nfs/TARGET/`
  * if rsync fails or connection is dropped, you can run `toolbox` and then run the rsync command again

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

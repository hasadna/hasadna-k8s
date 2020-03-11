# Cluster storage

## NFS v3 vs. v4

Both NFS versions can be used, but NFS v4 is required for some workloads (e.g. elasticsearch)

Kubernetes will attempt NFS v4 first and if fails, it will attempt NFS v3

NFS v3 requires to run the following on all cluster nodes: `apt-get install -qy nfs-common`

We have a Jenkins job which runs it (but have to run it manually after creating new nodes)

The following is required to use NFS v4:

* in /etc/exorts, a single export should have option fsid=0
* when setting the path to mount, it should be without the directory prefix
* e.g.:
  * in /etc/exports: `/srv/default2 172.16.0.0/23(rw,sync,no_subtree_check,no_root_squash,fsid=0)`
  * create a path to use: `mkdir /srv/default2/my-path`
  * the path to mount will be: `/my-path`
  * when all these conditions are met, NFS v4 will be used 

## Setting up NFS

SSH to the NFS node and run the following:

```
apt-get update && apt-get install -y nfs-kernel-server &&\
mkdir -p /srv/default &&\
chown -R nobody:nogroup /srv/default2/ &&\
echo '/srv/default2 172.16.0.0/23(rw,sync,no_subtree_check,no_root_squash,fsid=0)' > /etc/exports &&\
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

## nfs-client provisioner

Adds an nfs storage class which adds volumes to the existing NFS server

SSH to NFS server, create the directory: `/srv/default2/nfs-client-provisioner` 

Install nfs-client-provisioner, change IP to the NFS server internal IP:

```
kubectl create ns nfs-client-provisioner
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm upgrade --install --namespace nfs-client-provisioner	\
    --set nfs.server=172.16.0.9 \
    --set nfs.path=/nfs-client-provisioner \
    nfs-client-provisioner stable/nfs-client-provisioner
```

Using Rancher, you can now see the nfs-client storage class, you can set it as the default storage class using Rancher UI

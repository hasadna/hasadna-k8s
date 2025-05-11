# Cluster storage

The NFS server is setup in https://github.com/hasadna/hasadna-iac/blob/main/modules/hasadna/hasadna_nfs2.tf

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

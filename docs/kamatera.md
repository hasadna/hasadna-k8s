# Kamatera cluster notes

## Creating the cluster

Cluster is created using Rancher

## SSH to cluster nodes

Using Rancher you can get the keys for each node in a zip file

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

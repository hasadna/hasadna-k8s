## Moving reportit from gcloud to Kamatera

Renamed `environments/reportit` to `environments/reportit-gcloud`

Created new `environments/reportit` with values copied from reportit-gcloud

SSH to Kamatera NFS server, create paths:

```
mkdir -p /srv/default2/reportit/postgres /srv/default2/reportit/strapi /srv/default2/reportit/botkit
```

Connect to the Gcloud environment and export the secrets:

```
export KUBECONFIG=
source switch_environment.sh reportit-gcloud
mkdir -p environments/reportit/.secrets
kubectl get secret hubspot --export -o yaml > environments/reportit/.secrets/hubspot.yaml
```

Connect to the Kamatera environment, create the namespace and import the secrets

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh reportit
kubectl create ns reportit
kubectl -n reportit apply -f environments/reportit/.secrets/hubspot.yaml
rm -rf environments/reportit/.secrets
```

Connect to the Gcloud environment and rsync the data -

```
export KUBECONFIG=
source switch_environment.sh reportit-gcloud
source functions.sh
TARGET_NFS_IP=212.80.204.62
mount_nfs_and_rsync `get_pod_node_name reportit botkit-` $TARGET_NFS_IP \
                    /media/root/var/lib/kubelet/pods/`get_pod_uid reportit botkit-`/volumes/kubernetes.io~gce-pd/reportit-botkit-data/ \
                    /media/root/var/kamatera-nfs/reportit/botkit/ \
                    /srv/default2/reportit/botkit/
mount_nfs_and_rsync `get_pod_node_name reportit strapi-` $TARGET_NFS_IP \
                    /media/root/var/lib/kubelet/pods/`get_pod_uid reportit strapi-`/volumes/kubernetes.io~gce-pd/reportit-strapi-data/ \
                    /media/root/var/kamatera-nfs/reportit/strapi/ \
                    /srv/default2/reportit/strapi/
mount_nfs_and_rsync `get_pod_node_name reportit postgres-` $TARGET_NFS_IP \
                    /media/root/var/lib/kubelet/pods/`get_pod_uid reportit postgres-`/volumes/kubernetes.io~gce-pd/reportit-strapi-db/ \
                    /media/root/var/kamatera-nfs/reportit/postgres/ \
                    /srv/default2/reportit/postgres/
```

Deploy:

```
export KUBECONFIG=/path/to/kamatera/.kubeconfig
source switch_environment.sh reportit
./helm_upgrade_external_chart.sh reportit --install
```

Test

Add ingresses (copied from datacity)

Stop gcloud deployments, Rerun the rsyncs, update DNS

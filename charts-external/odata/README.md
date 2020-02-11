# Odata (ckan) chart

## Installation

### Install Minikube environment for local development

* [Install Minikube v0.3.5](https://github.com/kubernetes/minikube/releases/tag/v0.35.0)
* (Optional) To ensure clean setup, delete any existing Minikube clusters and configuration
  * `minikube delete; rm -rf ~/.minikube`
* Switch to the Minikube environment
  * `source switch_environment.sh odata-minikube`
* Initialize the Minikube environment
  * `charts-external/odata/deploy.sh --install-minikube`

### Install Production environment on Kamatera Rancher cluster

* Install Helm3 client - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Verify helm installation
  * `helm version`
  * tested with version `3.0.2`
* Switch to the odata kamatera environment
  * `export KUBECONFIG=/path/to/kamatera/kubeconfig`
  * `source switch_environment.sh odata-kamatera`
* Run the installation script
  * `charts-external/odata/deploy.sh --install-kamatera`
* Create rbac role
  * Copy rbac manifest from `charts-external/odata/manifests/ckan-kubectl-rbac.yaml` to environment directory
  * Modify names and namespaces
  * Apply: `kubectl apply -f environments/$K8S_ENVIRONMENT_NAME/ckan-kubectl-rbac.yaml`
* Update the relevant values in `environments/ENVIRONMENT_NAME/values.yaml`:
  * Set the NFS service cluster IP and path in `ckanDataNfsServer` and `ckanDataNfsServerPath`
* Create secret:
  * `kubectl -n odata create secret generic nginx-htpasswd --from-literal=secret-nginx-htpasswd="$(htpasswd -nb USERNAME PASSWORD)"`
* For imported environments, copy these secrets from existing environment:
```
kubectl -n odata create secret generic pipelines-sysadmin \
    --from-literal=apikey= \
    --from-literal=email= \
    --from-literal=password= \
    --from-literal=user=
```
```
kubectl -n odata create secret generic pipelines-monitor \
    --from-literal=SLACK_NOTIFICATIONS_URL=
```


## Deploy a new environment (for all environment types)

* Connect to the relevant environment (change environment name)
  * `source switch_environment.sh odata-minikube`
* Deploy
  * You can either initialize a new, empty environment or restore from backup
    * Initialize a new, empty environment:
      * `./deploy.sh --install`
    * Restore from backup:
      * Create a Google Cloud service account file with permissions to read the backup files
      * You should have the Google Cloud Storage urls to the db and datastore-db backup files.
      * For Minikube environment - restore only the DB
        * `charts-external/odata/deploy.sh --restore /path/to/google/cloud/service_account.json gs://odata-k8s-backups/production/blue/ckan-db-dump-$(date +%Y-%m-%d).ckan.dump`
      * For production environment - restore the datastore DB as well
        * `charts-external/odata/deploy.sh --restore /path/to/google/cloud/service_account.json gs://odata-k8s-backups/production/blue/ckan-db-dump-$(date +%Y-%m-%d).ckan.dump gs://odata-k8s-backups/production/blue/datastore-db-dump-$(date +%Y-%m-%d).datastore.dump`
        * In case DB restore fails, try the following:
          * Make sure the restore operation succeeded by checking the db-backup container logs 
          * Edit the `db` deployment and remove the db restore command - allowing DB to run
          * Execute shell on the db container and run the following:
            * `psql -c "create role ckan with login password 'PASSWORD';"` (get the password from the CKAN secret)
            * `psql -c 'GRANT ALL PRIVILEGES ON DATABASE "ckan" to ckan;'`
            * `psql -d ckan -c 'grant all privileges on database ckan to ckan;'`
            * `psql -d ckan -c 'grant all privileges on all tables in schema public to ckan;'`
          * Now, restart ckan pod and check that it connects to DB successfully
        * In case of permissions problems in CKAN pod, try the following from the NFS node:
          * `chown -R 900:900 /srv/default/odata/pipelines/ /srv/default/odata/ckan/`
* Wait for all pods to be in Running state
  * `./kubectl.sh loop get pods`
  * If a pod has problems try to force recreate
    * `./force_recreate.sh DEPLOYMENT_NAME`
* Verify by making a call to ckan api
  * `echo $(./kubectl.sh exec ckan -- wget -qO - http://127.0.0.1:5000/api/3)`
  * Should return `{"version": 3}`
* (Optional) for GKE environment - enable backup
  * `charts-external/odata/dtkubectl.sh initialize-backups /path/to/google/cloud/service_account.json gs://backups-bucket/path/to/db-backups/db-backup-prefix- gs://backups-bucket/path/to/datastore-db-backups/datastore-db-prefix-`
  * Add the output values to the releavnt environment values file
* When infrastructure is Running, deploy without initialization
    * `charts-external/odata/deploy.sh`
* Wait for all pods to be in Running state
  * `./kubectl.sh loop get pods`
* Port forward to the ckan pod
  * `./kubectl.sh port-forward ckan 5000`
  * For full support using port forward, modify the environment's `values.yaml`:
    * set `siteUrl` to `http://localhost:5000`
    * set `datastore.datapusherPortForward` to `true`
    * redeploy: `charts-external/odata/deploy.sh`
  * When connecting to ckan using port-forward, you should restart the datapusher after every restart of the ckan pod:
    * `./force_update.sh datapusher`
* Site should be accessible at http://localhost:5000
* (Optional) Create a sysadmin user
  * `charts-external/odata/utils/ckan-sysadmin.sh add USERNAME`
* (optional) Setup upload via email
  * Create a Gmail account to be used only for receiving uploads for this CKAN instance
  * go to: https://developers.google.com/gmail/api/quickstart/python
    * make sure your are logged-in to this Gmail account
    * Follow step 1 to get the credentials.json file
  * Update the upload via email secret
    * `charts-external/odata/dtkubectl.sh initialize-upload-via-email /path/to/credentials.json ALLOWED_SENDERS_RESOUREC_ID`
  * Configure upload via email in the environment's `values.yaml` under `uploadViaEmail`
  * Change the name of the ckan secrets secret (add an increment suffix) in `values.yaml` under `ckanSecretName`
    * This causes the secret to be recreated with the updated email configuration
  * Deploy: `charts-external/odata/deploy.sh`
  * Restart the pipelines: `./force_update.sh pipelines`

## Common Tasks

### Access the ckan web app directly

```
charts-external/odata/utils/ckan-port-forward.sh
```

Ckan will be available at http://localhost:5000/

### Create an admin user

```
charts-external/odata/utils/ckan-sysadmin.sh add minikube-admin email=minikube-admin@odata.org.il
```

### Rebuild the search index

```
charts-external/odata/utils/ckan-search-index.sh rebuild
```

## Updating ckan configuration

Ckan configuration is created from the ckan configmap: charts-external/odata/templates/ckan-configmap.yaml

## Backups

Backups are generated daily and uploaded to google storage

You can also run a backup manually:

```
./kubectl.sh exec db -c db -- bash /db-scripts/backup.sh &&\
./kubectl.sh logs db -c db-ops -f
```

## Restoring from live environment

* Switch to previous environment
  * `source switch_environment.sh odata`
* Stop the ckan pod - to prevent writes to DB
  * `kubectl delete deployment ckan`
* Create the backups
  * `./kubectl.sh exec db -c db -- bash /db-scripts/backup.sh`
  * `./kubectl.sh exec datastore-db -c db -- bash /db-scripts/backup.sh`
* Wait ~1 minute for files to be available on google storage (for today's date)

## Moving Odata from Gcloud to Kamatera

Modify /etc/exports in the Kamatera NFS server to allow access from the Gcloud nodes

Connect to the Gcloud environment and rsync all data:

```
export KUBECONFIG=
source switch_environment.sh odata &&\
source functions.sh &&\
TARGET_NFS_IP=212.80.204.62 &&\
mount_nfs_and_rsync `get_pod_node_name odata-blue nfs-` $TARGET_NFS_IP \
                    /media/root/var/lib/kubelet/pods/`get_pod_uid odata-blue nfs-`/volumes/kubernetes.io~gce-pd/odata-blue-nfs-gcepd \
                    /media/root/var/kamatera-nfs/odata \
                    /srv/default/odata &&\
mount_nfs_and_rsync `get_pod_node_name odata-blue db-` $TARGET_NFS_IP \
                    /media/root/var/lib/kubelet/pods/`get_pod_uid odata-blue db-`/volumes/kubernetes.io~gce-pd/db/postgresql-data \
                    /media/root/var/kamatera-nfs/odata/postgresql-data \
                    /srv/default/odata/postgresql-data &&\
mount_nfs_and_rsync `get_pod_node_name odata-blue datastore-db-` $TARGET_NFS_IP \
                    /media/root/var/lib/kubelet/pods/`get_pod_uid odata-blue datastore-db-`/volumes/kubernetes.io~gce-pd/db/datastore-db-postgresql-data \
                    /media/root/var/kamatera-nfs/odata/datastore-db-postgresql-data \
                    /srv/default/odata/datastore-db-postgresql-data
```

Connect to the Gcloud environment and export the secrets:

```
export KUBECONFIG=
source switch_environment.sh odata
mkdir -p environments/odata-kamatera/.secrets
for SECRET_NAME in ckan-db-backups ckan-db-restore ckan-secrets ckan-secrets-2 ckan-upload-via-email-env-vars \
                   datastore-db-public-readonly-user env-vars nginx-htpasswd pipelines-monitor pipelines-sysadmin \
                   odata-datastore-db-kube-ip-dns-updater; do
    kubectl get -n odata-blue secret $SECRET_NAME --export -o yaml > environments/odata-kamatera/.secrets/$SECRET_NAME.yaml
done
```

Connect to the odata environment, import the secrets and delete the local copies:

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh odata-kamatera
for SECRET_NAME in ckan-db-backups ckan-db-restore ckan-secrets ckan-secrets-2 ckan-upload-via-email-env-vars \
                   datastore-db-public-readonly-user env-vars nginx-htpasswd pipelines-monitor pipelines-sysadmin \
                   odata-datastore-db-kube-ip-dns-updater; do
    kubectl delete -n odata secret $SECRET_NAME
    kubectl apply -n odata -f environments/odata-kamatera/.secrets/$SECRET_NAME.yaml
done
rm -rf environments/odata-kamatera/.secrets
```

Connect to the kamatera environment and deploy:

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh odata-kamatera
kubectl -n odata apply -f environments/odata-kamatera/ckan-kubectl-rbac.yaml
./helm_upgrade_external_chart.sh odata --install
```

Once all pods are running, you can test by port-forward to the nginx pod:

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh odata-kamatera
kubectl port-forward nginx-pod-name 8080:80
```

Test at http://localhost:8080 (pay attention that some links refer to the odata.org.il host, so you have to change manually to localhost)

When you verified it works

scale down the new pods to 0:

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh odata-kamatera
kubectl scale --replicas=0 deployment ckan &&\
kubectl scale --replicas=0 deployment ckan-jobs &&\
kubectl scale --replicas=0 deployment pipelines
```

scale down the old CKAN pods to 0:

```
export KUBECONFIG=
source switch_environment.sh odata
kubectl scale --replicas=0 deployment ckan &&\
kubectl scale --replicas=0 deployment ckan-jobs &&\
kubectl scale --replicas=0 deployment pipelines
```

Rerun the rsync commands (from previous step)

update DNS in cloudflare to point to the new cluster worker1 node

When rsync is done, scale back up the new pods and delete the old namespace


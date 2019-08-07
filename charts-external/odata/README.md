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

### Install Production environment on hasadna cluster

* Install Helm client
  * To make sure you get corret version you should use the script in this repo
  * `bash apps_travis_script.sh install_helm`
  * if you have problems, refer to helm docs - [helm client](https://docs.helm.sh/using_helm/#installing-the-helm-client)
* Verify helm installation
  * `helm version`
* Switch to the odata environment with label for the new deployment
  * `source switch_environment.sh odata test1`
* Give cluster role binding to the default service account
  * `kubectl create rolebinding odata-test1-default-binding --clusterrole=admin --user=system:serviceaccount:odata-test1:default --namespace=odata-test1`
* (Optional) migrate from existing environment
  * Make the data storage read-only
    * `./kubectl.sh exec nfs -- chmod -R a-w /exports`
  * Take a snapshot of current nfs disk
    * `gcloud --project=hasadna-general compute disks snapshot odata-green-nfs --snapshot-names=odata-green-20180930 --zone=europe-west1-b`
* Add the installation configuration in `environments/odata/values.test1.yaml`:
```
odataInstallGke:
  nfsSourceSnapshot: odata-data-20180930
  nfsSize: 100
  dbSize: 20
  datastoreSize: 50
```
* Run the installation script which creates persistent disks and sets up the data storage server
  * `charts-external/odata/deploy.sh --install-gke`
* Create rbac role
  * Copy rbac manifest from `charts-external/odata/manifests/ckan-kubectl-rbac.yaml` to environment directory
  * Modify names and namespaces
  * Apply: `kubectl apply -f environments/odata/odata-blue-ckan-kubectl-rbac.yaml`
* Wait for NFS pod to be in running state
  * `./kubectl.sh loop get pods`
* Get the NFS service cluster IP
  * `kubectl get service nfs`
* Update the relevant values:
  * Set the NFS service cluster IP in `ckanDataNfsServer`
  * If installed using production setup on GKE, set persistent disk names:
    * ckanDbPersistentDiskName: `odata-test1-db`
    * datastore.persistentDiskName: `odata-test1-datastore`

## Deploy a new environment

* Connect to the relevant environment
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
